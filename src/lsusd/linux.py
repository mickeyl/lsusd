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


def _format_bus(value):
    """Return a USB bus number as three decimal digits."""
    try:
        return f"{int(value):03d}"
    except (TypeError, ValueError):
        return "000"


def _format_speed(value):
    """Return a sysfs USB speed value in lsusb-like units."""
    if not value:
        return "?"
    speed = value.rstrip("0").rstrip(".")
    return f"{speed}M"


def _is_hub(usb_dir):
    """Return True for USB hub device directories."""
    return (_read_sysfs(usb_dir / "bDeviceClass") or "").lower() == "09"


def _usb_device_row(usb_dir):
    """Convert a sysfs USB device directory to a display row."""
    vid = (_read_sysfs(usb_dir / "idVendor") or "0000").upper()
    pid = (_read_sysfs(usb_dir / "idProduct") or "0000").upper()
    product = _read_sysfs(usb_dir / "product")
    vendor = _read_sysfs(usb_dir / "manufacturer")
    serial = _read_sysfs(usb_dir / "serial") or "?"

    if not product or not vendor:
        ids_vendor, ids_product = usb_ids.lookup(vid, pid)
        if not vendor and ids_vendor:
            vendor = ids_vendor
        if not product and ids_product:
            product = ids_product

    bus = _format_bus(_read_sysfs(usb_dir / "busnum"))
    address = _format_bus(_read_sysfs(usb_dir / "devnum"))

    return {
        "device": f"/dev/bus/usb/{bus}/{address}",
        "bus": bus,
        "address": address,
        "location": _read_sysfs(usb_dir / "devpath") or usb_dir.name,
        "product": product or "?",
        "vendor": vendor or "?",
        "serial": serial,
        "vidpid": f"{vid}:{pid}",
        "speed": _format_speed(_read_sysfs(usb_dir / "speed")),
        "hub": _is_hub(usb_dir),
    }


def discover_all(include_hubs=False):
    """Discover all USB devices via sysfs on Linux."""
    devices = []
    usb_bus = Path("/sys/bus/usb/devices")
    if not usb_bus.is_dir():
        return devices

    for usb_dir in sorted(usb_bus.iterdir()):
        if not (usb_dir / "idVendor").is_file() or not (usb_dir / "idProduct").is_file():
            continue
        device = _usb_device_row(usb_dir)
        if device["hub"] and not include_hubs:
            continue
        devices.append(device)

    return sorted(devices, key=lambda d: (d["bus"], d["address"], d["location"]))


def _usb_parent_name(name):
    """Return the sysfs device name of a USB device's physical parent."""
    if name.startswith("usb"):
        return None
    bus, _, port_path = name.partition("-")
    if not port_path:
        return None
    if "." not in port_path:
        return f"usb{bus}"
    return f"{bus}-{port_path.rsplit('.', 1)[0]}"


def _tree_from_name(name, children_by_parent, rows_by_name, include_hubs):
    """Build visible USB tree nodes for one sysfs device name."""
    children = []
    for child_name in sorted(children_by_parent.get(name, [])):
        children.extend(_tree_from_name(child_name, children_by_parent, rows_by_name, include_hubs))

    device = rows_by_name[name]
    if device["hub"] and not include_hubs:
        return children

    return [{"device": device, "children": children}]


def discover_tree(include_hubs=False):
    """Discover all USB devices as a visible hierarchy on Linux."""
    usb_bus = Path("/sys/bus/usb/devices")
    if not usb_bus.is_dir():
        return []

    rows_by_name = {}
    children_by_parent = {}
    roots = []

    for usb_dir in sorted(usb_bus.iterdir()):
        if not (usb_dir / "idVendor").is_file() or not (usb_dir / "idProduct").is_file():
            continue
        rows_by_name[usb_dir.name] = _usb_device_row(usb_dir)

    for name in rows_by_name:
        parent = _usb_parent_name(name)
        if parent and parent in rows_by_name:
            children_by_parent.setdefault(parent, []).append(name)
        else:
            roots.append(name)

    tree = []
    for name in sorted(roots):
        tree.extend(_tree_from_name(name, children_by_parent, rows_by_name, include_hubs))
    return tree


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
