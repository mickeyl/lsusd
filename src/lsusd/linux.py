"""Linux USB serial device discovery and event watching."""

import socket
from pathlib import Path

from lsusd import usb_ids


def _read_sysfs(path):
    """Read a sysfs attribute file, returning stripped content or None."""
    try:
        return path.read_text().strip()
    except (OSError, PermissionError):
        return None


def _find_usb_ancestor(device_path):
    """Walk up from a sysfs tty device path to the nearest USB device directory."""
    p = device_path.resolve()
    while p != Path("/"):
        if (p / "idVendor").is_file() and (p / "idProduct").is_file():
            return p
        p = p.parent
    return None


def discover():
    """Discover USB serial devices via sysfs on Linux."""
    devices = []
    tty_class = Path("/sys/class/tty")
    if not tty_class.is_dir():
        return devices

    for entry in sorted(tty_class.iterdir()):
        device_link = entry / "device"
        if not device_link.exists():
            continue

        usb_dir = _find_usb_ancestor(device_link)
        if not usb_dir:
            continue

        vid = _read_sysfs(usb_dir / "idVendor") or "0000"
        pid = _read_sysfs(usb_dir / "idProduct") or "0000"
        product = _read_sysfs(usb_dir / "product")
        vendor = _read_sysfs(usb_dir / "manufacturer")
        serial = _read_sysfs(usb_dir / "serial") or "?"

        if not product or not vendor:
            ids_vendor, ids_product = usb_ids.lookup(vid, pid)
            if not vendor and ids_vendor:
                vendor = ids_vendor
            if not product and ids_product:
                product = ids_product

        product = product or "?"
        vendor = vendor or "?"

        devices.append({
            "device": f"/dev/{entry.name}",
            "product": product,
            "vendor": vendor,
            "serial": serial,
            "vidpid": f"{vid.upper()}:{pid.upper()}",
        })

    return devices


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


def _parse_uevent(payload):
    """Parse a null-separated kernel uevent payload into a dictionary."""
    event = {}
    for item in payload.decode("utf-8", errors="replace").split("\0"):
        if "=" not in item:
            continue
        key, value = item.split("=", 1)
        event[key] = value
    return event


def _is_tty_event(event):
    """Return True for kernel uevents that can affect USB serial tty devices."""
    if event.get("SUBSYSTEM") == "tty":
        return True
    devname = event.get("DEVNAME", "")
    return devname.startswith(("ttyUSB", "ttyACM"))


def watch_changes(initial="events"):
    """Yield current USB serial devices, then add/remove events from uevents."""
    netlink_kobject_uevent = 15
    kobject_uevent_group = 1

    with socket.socket(socket.AF_NETLINK, socket.SOCK_DGRAM, netlink_kobject_uevent) as sock:
        sock.bind((0, kobject_uevent_group))
        previous = discover()
        if initial == "snapshot":
            yield {"action": "snapshot", "devices": previous}
        elif initial == "events":
            for device in previous:
                yield {"action": "present", **device}

        while True:
            event = _parse_uevent(sock.recv(65535))
            if not _is_tty_event(event):
                continue

            current = discover()
            changes = list(_diff_devices(previous, current))
            previous = current
            for change in changes:
                yield change
