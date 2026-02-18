"""CLI entry point and table formatting."""

import argparse
import platform
import sys

from lsusd import __version__
from lsusd.spinner import Spinner


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


def format_plain(devices, separator="\t"):
    """Render devices as plain delimited text."""
    lines = []
    for d in devices:
        lines.append(separator.join([
            d["device"], d["product"], d["vendor"], d["serial"], d["vidpid"],
        ]))
    return "\n".join(lines)


def parse_args(argv=None):
    parser = argparse.ArgumentParser(
        prog="lsusd",
        description="List USB serial devices with their associated USB metadata.",
    )
    parser.add_argument(
        "--version", action="version", version=f"%(prog)s {__version__}",
    )

    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        "-p", "--plain", action="store_true",
        help="plain tab-separated output (no headers, no box drawing)",
    )
    group.add_argument(
        "-c", "--csv", action="store_true",
        help="CSV output with header row",
    )
    group.add_argument(
        "-j", "--json", action="store_true",
        help="JSON output",
    )

    parser.add_argument(
        "-n", "--no-spinner", action="store_true",
        help="disable the progress spinner",
    )

    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)

    system = platform.system()
    if system == "Darwin":
        from lsusd.darwin import discover
    elif system == "Linux":
        from lsusd.linux import discover
    else:
        print(f"Unsupported platform: {system}", file=sys.stderr)
        sys.exit(1)

    use_spinner = not args.no_spinner and sys.stderr.isatty()

    if use_spinner:
        with Spinner():
            devices = discover()
    else:
        devices = discover()

    if not devices:
        print("No USB serial devices found.")
        sys.exit(0)

    if args.json:
        import json
        print(json.dumps(devices, indent=2))
    elif args.csv:
        import csv
        import io
        buf = io.StringIO()
        writer = csv.writer(buf)
        writer.writerow(["device", "product", "vendor", "serial", "vidpid"])
        for d in devices:
            writer.writerow([d["device"], d["product"], d["vendor"], d["serial"], d["vidpid"]])
        print(buf.getvalue(), end="")
    elif args.plain:
        print(format_plain(devices))
    else:
        headers = ["Device Node", "USB Product", "USB Vendor", "USB Serial", "VID:PID"]
        rows = [(d["device"], d["product"], d["vendor"], d["serial"], d["vidpid"]) for d in devices]
        print(format_table(rows, headers))


if __name__ == "__main__":
    main()
