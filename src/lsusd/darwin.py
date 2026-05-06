"""macOS USB serial device discovery and event watching."""

import ctypes
import plistlib
import re
import subprocess
import threading

from lsusd import usb_ids


def _ioreg(*args):
    """Run ioreg and return decoded stdout."""
    return subprocess.run(["ioreg", *args], capture_output=True).stdout.decode(
        "utf-8", errors="replace"
    )


def _hex_id(value):
    """Return an integer USB ID as four uppercase hex digits."""
    try:
        return f"{int(value):04X}"
    except (TypeError, ValueError):
        return "0000"


def _location(value):
    """Return an IOKit locationID as the usual 0xhhhhhhhh string."""
    try:
        return f"0x{int(value):08x}"
    except (TypeError, ValueError):
        return "?"


def _bus_from_location(value):
    """Return a Linux-lsusb-style bus number derived from macOS locationID."""
    try:
        return f"{(int(value) >> 24) & 0xFF:03d}"
    except (TypeError, ValueError):
        return "000"


def _address(value):
    """Return a USB address as a three-digit device number."""
    try:
        return f"{int(value):03d}"
    except (TypeError, ValueError):
        return "000"


def _speed(value):
    """Format a USB link speed stored as bits per second."""
    try:
        bits = int(value)
    except (TypeError, ValueError):
        return "?"
    if bits >= 1_000_000_000:
        speed = bits / 1_000_000_000
        unit = "G"
    elif bits >= 1_000_000:
        speed = bits / 1_000_000
        unit = "M"
    elif bits >= 1_000:
        speed = bits / 1_000
        unit = "K"
    else:
        return str(bits)
    if speed.is_integer():
        return f"{int(speed)}{unit}"
    return f"{speed:g}{unit}"


def _children(node):
    """Return IORegistry children for a plist node."""
    return node.get("IORegistryEntryChildren", []) or []


def _is_usb_device(node):
    """Return True for USB device registry nodes."""
    return "idVendor" in node and "idProduct" in node


def _load_usb_tree():
    """Load the IOUSB registry plane as a plist dictionary."""
    raw = subprocess.run(
        ["ioreg", "-p", "IOUSB", "-l", "-w0", "-a"],
        capture_output=True,
    ).stdout
    if not raw:
        return {}
    try:
        return plistlib.loads(raw)
    except plistlib.InvalidFileException:
        return {}


def _walk(node):
    """Yield node and all descendants from an IORegistry plist tree."""
    yield node
    for child in _children(node):
        yield from _walk(child)


def _usb_device_row(node):
    """Convert an IOUSB device node to a display row."""
    vid = _hex_id(node.get("idVendor"))
    pid = _hex_id(node.get("idProduct"))
    ids_vendor, ids_product = usb_ids.lookup(vid, pid)

    product = (
        node.get("kUSBProductString")
        or node.get("USB Product Name")
        or ids_product
        or node.get("IORegistryEntryName")
        or "?"
    )
    vendor = (
        node.get("kUSBVendorString")
        or node.get("USB Vendor Name")
        or ids_vendor
        or "?"
    )
    serial = node.get("USB Serial Number") or node.get("kUSBSerialNumberString") or "?"
    location = _location(node.get("locationID"))
    bus = _bus_from_location(node.get("locationID"))
    address = _address(node.get("USB Address"))

    return {
        "device": f"/dev/bus/usb/{bus}/{address}",
        "bus": bus,
        "address": address,
        "location": location,
        "product": str(product).strip() or "?",
        "vendor": str(vendor).strip() or "?",
        "serial": str(serial).strip() or "?",
        "vidpid": f"{vid}:{pid}",
        "speed": _speed(node.get("UsbLinkSpeed")),
        "hub": int(node.get("bDeviceClass", -1)) == 9,
    }


def _enrich_serial_devices(serial_devices):
    """Correct serial-device metadata with the scoped IOUSB device snapshot."""
    try:
        all_devices = discover_all()
    except OSError:
        return serial_devices

    by_serial = {
        device["serial"]: device
        for device in all_devices
        if device["serial"] != "?"
    }
    by_vidpid = {}
    duplicate_vidpids = set()
    for device in all_devices:
        vidpid = device["vidpid"]
        if vidpid in by_vidpid:
            duplicate_vidpids.add(vidpid)
        by_vidpid[vidpid] = device

    enriched = []
    for device in serial_devices:
        usb_device = by_serial.get(device["serial"])
        if usb_device is None and device["vidpid"] not in duplicate_vidpids:
            usb_device = by_vidpid.get(device["vidpid"])

        if usb_device:
            corrected = dict(device)
            for field in ("product", "vendor", "serial", "vidpid"):
                corrected[field] = usb_device[field]
            enriched.append(corrected)
        else:
            enriched.append(device)

    return enriched


def discover():
    """Discover USB serial devices via ioreg on macOS."""
    raw = _ioreg("-l")

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

    return sorted(_enrich_serial_devices(serial_devices), key=lambda d: d["device"])


def discover_all(include_hubs=False):
    """Discover all USB devices via the IOUSB registry plane on macOS."""
    tree = _load_usb_tree()
    devices = []
    for node in _walk(tree):
        if not _is_usb_device(node):
            continue
        device = _usb_device_row(node)
        if device["hub"] and not include_hubs:
            continue
        devices.append(device)

    return sorted(devices, key=lambda d: (d["location"], d["address"], d["vidpid"]))


def _usb_tree_nodes(node, include_hubs):
    """Return visible USB device tree nodes below an IORegistry node."""
    children = []
    for child in _children(node):
        children.extend(_usb_tree_nodes(child, include_hubs))

    if not _is_usb_device(node):
        return children

    device = _usb_device_row(node)
    if device["hub"] and not include_hubs:
        return children

    return [{"device": device, "children": children}]


def discover_tree(include_hubs=False):
    """Discover all USB devices as a visible hierarchy on macOS."""
    return _usb_tree_nodes(_load_usb_tree(), include_hubs)


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
