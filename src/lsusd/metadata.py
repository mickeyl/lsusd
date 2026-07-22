"""Shared formatting for USB descriptor metadata."""


def format_bcd_device_release(value):
    """Format the raw BCD device release from a USB device descriptor."""
    try:
        value = int(value)
    except (TypeError, ValueError):
        return "?"
    if not 0 <= value <= 0xFFFF:
        return "?"
    return f"{value >> 8:X}.{value & 0xFF:02X}"
