"""macOS USB serial device discovery via ioreg."""

import re
import subprocess


def discover():
    """Discover USB serial devices via ioreg on macOS."""
    raw = subprocess.run(["ioreg", "-l"], capture_output=True, text=True).stdout

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
