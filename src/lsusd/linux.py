"""Linux USB serial device discovery via sysfs."""

from pathlib import Path


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
        name = entry.name
        if not (name.startswith("ttyUSB") or name.startswith("ttyACM")):
            continue

        device_link = entry / "device"
        if not device_link.exists():
            continue

        usb_dir = _find_usb_ancestor(device_link)
        if not usb_dir:
            continue

        vid = _read_sysfs(usb_dir / "idVendor") or "0000"
        pid = _read_sysfs(usb_dir / "idProduct") or "0000"
        product = _read_sysfs(usb_dir / "product") or "?"
        vendor = _read_sysfs(usb_dir / "manufacturer") or "?"
        serial = _read_sysfs(usb_dir / "serial") or "?"

        devices.append({
            "device": f"/dev/{name}",
            "product": product,
            "vendor": vendor,
            "serial": serial,
            "vidpid": f"{vid.upper()}:{pid.upper()}",
        })

    return devices
