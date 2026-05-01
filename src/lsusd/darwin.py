"""macOS USB serial device discovery and event watching."""

import ctypes
import re
import subprocess
import threading


def discover():
    """Discover USB serial devices via ioreg on macOS."""
    raw = subprocess.run(["ioreg", "-l"], capture_output=True).stdout.decode(
        "utf-8", errors="replace"
    )

    current_usb = {}
    serial_devices = []

    for line in raw.split("\n"):
        for key in ("kUSBProductString", "kUSBVendorString", "USB Serial Number"):
            m = re.search(rf'"{key}"\s*=\s*"([^"]*)"', line)
            if m:
                current_usb[key] = m.group(1).strip()
        for key in ("idVendor", "idProduct"):
            m = re.search(rf'"{key}"\s*=\s*(\d+)', line)
            if m:
                current_usb[key] = m.group(1)

        m = re.search(r'"IOCalloutDevice"\s*=\s*"(/dev/cu\.usb(?:modem|serial)[^"]+)"', line)
        if m:
            vid = int(current_usb.get("idVendor", "0"))
            pid = int(current_usb.get("idProduct", "0"))
            serial_devices.append({
                "device": m.group(1),
                "product": current_usb.get("kUSBProductString", "?"),
                "vendor": current_usb.get("kUSBVendorString", "?"),
                "serial": current_usb.get("USB Serial Number", "?"),
                "vidpid": f"{vid:04X}:{pid:04X}" if vid else "?",
            })

    return sorted(serial_devices, key=lambda d: d["device"])


def _devices_by_node(devices):
    """Return devices keyed by their stable device node."""
    return {d["device"]: d for d in devices}


def _diff_devices(previous, current):
    """Yield added and removed devices between two discovery snapshots."""
    previous_by_node = _devices_by_node(previous)
    current_by_node = _devices_by_node(current)

    for node in sorted(set(current_by_node) - set(previous_by_node)):
        yield {"action": "add", **current_by_node[node]}

    for node in sorted(set(previous_by_node) - set(current_by_node)):
        yield {"action": "remove", **previous_by_node[node]}


class _IOKitWatcher:
    """Push-driven watcher backed by IOKit service notifications."""

    _IO_OBJECT_NULL = 0
    _K_IO_FIRST_MATCH = b"IOServiceFirstMatch"
    _K_IO_TERMINATED = b"IOServiceTerminate"
    _K_CF_RUN_LOOP_DEFAULT_MODE = ctypes.c_void_p.in_dll(
        ctypes.CDLL("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"),
        "kCFRunLoopDefaultMode",
    )

    def __init__(self, on_change):
        self._on_change = on_change
        self._ready = threading.Event()
        self._stop = threading.Event()
        self._callbacks = []
        self._iterators = []
        self._notify_port = None
        self._run_loop = None
        self._thread = None
        self._error = None

        self._iokit = ctypes.CDLL("/System/Library/Frameworks/IOKit.framework/IOKit")
        self._corefoundation = ctypes.CDLL(
            "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"
        )
        self._configure_functions()

    def _configure_functions(self):
        self._iokit.IONotificationPortCreate.argtypes = [ctypes.c_uint32]
        self._iokit.IONotificationPortCreate.restype = ctypes.c_void_p
        self._iokit.IONotificationPortDestroy.argtypes = [ctypes.c_void_p]

        self._iokit.IONotificationPortGetRunLoopSource.argtypes = [ctypes.c_void_p]
        self._iokit.IONotificationPortGetRunLoopSource.restype = ctypes.c_void_p

        self._iokit.IOServiceMatching.argtypes = [ctypes.c_char_p]
        self._iokit.IOServiceMatching.restype = ctypes.c_void_p

        self._callback_type = ctypes.CFUNCTYPE(None, ctypes.c_void_p, ctypes.c_uint32)
        self._iokit.IOServiceAddMatchingNotification.argtypes = [
            ctypes.c_void_p,
            ctypes.c_char_p,
            ctypes.c_void_p,
            self._callback_type,
            ctypes.c_void_p,
            ctypes.POINTER(ctypes.c_uint32),
        ]
        self._iokit.IOServiceAddMatchingNotification.restype = ctypes.c_int

        self._iokit.IOIteratorNext.argtypes = [ctypes.c_uint32]
        self._iokit.IOIteratorNext.restype = ctypes.c_uint32
        self._iokit.IOObjectRelease.argtypes = [ctypes.c_uint32]
        self._iokit.IOObjectRelease.restype = ctypes.c_int

        self._corefoundation.CFRunLoopGetCurrent.restype = ctypes.c_void_p
        self._corefoundation.CFRunLoopAddSource.argtypes = [
            ctypes.c_void_p,
            ctypes.c_void_p,
            ctypes.c_void_p,
        ]
        self._corefoundation.CFRunLoopRun.argtypes = []
        self._corefoundation.CFRunLoopStop.argtypes = [ctypes.c_void_p]

    def start(self):
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()
        self._ready.wait()
        if self._error:
            raise self._error

    def stop(self):
        self._stop.set()
        if self._run_loop:
            self._corefoundation.CFRunLoopStop(self._run_loop)
        if self._thread:
            self._thread.join()

    def _run(self):
        try:
            self._run_loop = self._corefoundation.CFRunLoopGetCurrent()
            self._notify_port = self._iokit.IONotificationPortCreate(0)
            if not self._notify_port:
                raise RuntimeError("IONotificationPortCreate failed")

            source = self._iokit.IONotificationPortGetRunLoopSource(self._notify_port)
            if not source:
                raise RuntimeError("IONotificationPortGetRunLoopSource failed")

            self._corefoundation.CFRunLoopAddSource(
                self._run_loop,
                source,
                self._K_CF_RUN_LOOP_DEFAULT_MODE,
            )

            self._register(self._K_IO_FIRST_MATCH)
            self._register(self._K_IO_TERMINATED)

            self._ready.set()
            self._corefoundation.CFRunLoopRun()
        except Exception as exc:
            self._error = exc
            self._ready.set()
        finally:
            for iterator in self._iterators:
                self._iokit.IOObjectRelease(iterator)
            if self._notify_port:
                self._iokit.IONotificationPortDestroy(self._notify_port)

    def _register(self, notification_type):
        matching = self._iokit.IOServiceMatching(b"IOSerialBSDClient")
        if not matching:
            raise RuntimeError("IOServiceMatching failed for IOSerialBSDClient")

        iterator = ctypes.c_uint32(self._IO_OBJECT_NULL)
        callback = self._callback_type(self._handle_notification)
        result = self._iokit.IOServiceAddMatchingNotification(
            self._notify_port,
            notification_type,
            matching,
            callback,
            None,
            ctypes.byref(iterator),
        )
        if result:
            raise RuntimeError(f"IOServiceAddMatchingNotification failed: {result}")

        self._callbacks.append(callback)
        self._iterators.append(iterator.value)
        self._drain(iterator.value)

    def _handle_notification(self, _refcon, iterator):
        self._drain(iterator)
        if not self._stop.is_set():
            self._on_change()

    def _drain(self, iterator):
        while True:
            service = self._iokit.IOIteratorNext(iterator)
            if service == self._IO_OBJECT_NULL:
                break
            self._iokit.IOObjectRelease(service)


def watch_changes(initial="events"):
    """Yield current USB serial devices, then add/remove events from IOKit."""
    previous = discover()
    condition = threading.Condition()
    pending = []

    def on_change():
        nonlocal previous
        current = discover()
        changes = list(_diff_devices(previous, current))
        previous = current
        if changes:
            with condition:
                pending.extend(changes)
                condition.notify()

    watcher = _IOKitWatcher(on_change)

    try:
        watcher.start()
        if initial == "snapshot":
            yield {"action": "snapshot", "devices": previous}
        elif initial == "events":
            for device in previous:
                yield {"action": "present", **device}

        while True:
            with condition:
                while not pending:
                    condition.wait()
                yield pending.pop(0)
    finally:
        watcher.stop()
