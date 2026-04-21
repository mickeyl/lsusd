"""Lookup of USB vendor/product names from a local usb.ids database."""

from pathlib import Path

_USB_IDS_PATHS = [
    "/usr/share/hwdata/usb.ids",
    "/usr/share/misc/usb.ids",
    "/var/lib/usbutils/usb.ids",
    "/usr/local/share/usb.ids",
]

_cache = None


def _load():
    """Parse the first available usb.ids file into {vid: (vendor, {pid: product})}."""
    for path in _USB_IDS_PATHS:
        p = Path(path)
        if not p.is_file():
            continue
        try:
            text = p.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        table = {}
        current_vid = None
        for line in text.splitlines():
            if not line or line.startswith("#"):
                continue
            if line.startswith("\t\t"):
                continue
            if line.startswith("\t"):
                if current_vid is None:
                    continue
                stripped = line[1:]
                if len(stripped) < 6 or stripped[4:6] != "  ":
                    continue
                pid = stripped[:4].lower()
                if not all(c in "0123456789abcdef" for c in pid):
                    continue
                table[current_vid][1][pid] = stripped[6:].strip()
            else:
                if len(line) < 6 or line[4:6] != "  ":
                    current_vid = None
                    continue
                vid = line[:4].lower()
                if not all(c in "0123456789abcdef" for c in vid):
                    current_vid = None
                    continue
                current_vid = vid
                table[vid] = (line[6:].strip(), {})
        return table
    return {}


def lookup(vid, pid):
    """Return (vendor_name, product_name) for a VID:PID, with None for misses."""
    global _cache
    if _cache is None:
        _cache = _load()
    entry = _cache.get(vid.lower())
    if not entry:
        return (None, None)
    vendor_name, products = entry
    return (vendor_name, products.get(pid.lower()))
