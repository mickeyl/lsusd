"""CLI entry point and table formatting."""

import platform
import sys


def format_table(rows, headers):
    """Render rows as a Unicode box-drawing table."""
    widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(cell))

    def line(left, mid, right, fill="\u2500"):
        return left + mid.join(fill * (w + 2) for w in widths) + right

    def data_row(cells):
        return "\u2502" + "\u2502".join(f" {c:<{w}} " for c, w in zip(cells, widths)) + "\u2502"

    lines = [line("\u250c", "\u252c", "\u2510")]
    lines.append(data_row(h.center(w) for h, w in zip(headers, widths)))
    for row in rows:
        lines.append(line("\u251c", "\u253c", "\u2524"))
        lines.append(data_row(row))
    lines.append(line("\u2514", "\u2534", "\u2518"))
    return "\n".join(lines)


def main():
    system = platform.system()
    if system == "Darwin":
        from lsusd.darwin import discover
    elif system == "Linux":
        from lsusd.linux import discover
    else:
        print(f"Unsupported platform: {system}", file=sys.stderr)
        sys.exit(1)

    devices = discover()

    if not devices:
        print("No USB serial devices found.")
        sys.exit(0)

    headers = ["Device Node", "USB Product", "USB Vendor", "USB Serial", "VID:PID"]
    rows = [(d["device"], d["product"], d["vendor"], d["serial"], d["vidpid"]) for d in devices]
    print(format_table(rows, headers))


if __name__ == "__main__":
    main()
