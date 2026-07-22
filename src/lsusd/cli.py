"""CLI entry point and table formatting."""

import argparse
import platform
import sys
from datetime import datetime

from lsusd import __version__
from lsusd.spinner import Spinner

WATCH_HEADERS = ["action", "device", "product", "vendor", "serial", "vidpid", "release"]
DEVICE_HEADERS = [
    "Device Node", "USB Product", "USB Vendor", "USB Serial", "VID:PID", "Release",
]
DEVICE_FIELDS = ["device", "product", "vendor", "serial", "vidpid", "release"]
ALL_DEVICE_HEADERS = [
    "Bus", "Device", "Location ID", "USB Product", "USB Vendor", "USB Serial", "VID:PID", "Release", "Speed",
]
ALL_DEVICE_FIELDS = [
    "bus", "address", "location", "product", "vendor", "serial", "vidpid", "release", "speed",
]


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


def format_plain(devices, fields=DEVICE_FIELDS, separator="\t"):
    """Render devices as plain delimited text."""
    lines = []
    for d in devices:
        lines.append(separator.join(d[field] for field in fields))
    return "\n".join(lines)


def _format_tree_label(device):
    """Render one USB tree node."""
    parts = [
        f"Bus {device['bus']}",
        f"Dev {device['address']}",
        f"ID {device['vidpid']}",
        device["vendor"],
        device["product"],
        f"release={device['release']}",
        f"speed={device['speed']}",
        f"loc={device['location']}",
    ]
    if device["serial"] != "?":
        parts.append(f"serial={device['serial']}")
    if device.get("hub"):
        parts.append("hub")
    return " ".join(parts)


def format_tree(nodes):
    """Render USB devices as a Unicode tree."""
    lines = []

    def walk(children, prefix=""):
        for index, node in enumerate(children):
            last = index == len(children) - 1
            connector = "\u2514\u2500 " if last else "\u251c\u2500 "
            child_prefix = "   " if last else "\u2502  "
            lines.append(prefix + connector + _format_tree_label(node["device"]))
            walk(node["children"], prefix + child_prefix)

    walk(nodes)
    return "\n".join(lines)


def format_watch_plain(event, separator="\t"):
    """Render one watch event as plain delimited text."""
    return separator.join(event[field] for field in WATCH_HEADERS)


def format_watch_line(event):
    """Render one watch event as a compact dmesg-like line."""
    timestamp = datetime.now().isoformat(timespec="seconds")
    return (
        f"{timestamp} usb-serial {event['action']} {event['device']} "
        f"product={event['product']!r} vendor={event['vendor']!r} "
        f"serial={event['serial']!r} vidpid={event['vidpid']} release={event['release']}"
    )


def _watch_event_summary(event):
    """Render a compact description of the last watch event."""
    return f"{event['action']} {event['device']} ({event['product']}, {event['vidpid']})"


def _event_device(event):
    """Return the device portion of a watch event."""
    return {field: event[field] for field in DEVICE_FIELDS}


def _update_watch_devices(devices, event):
    """Apply a watch event to a device map keyed by device node."""
    if event["action"] in ("present", "add"):
        devices[event["device"]] = _event_device(event)
    elif event["action"] == "remove":
        devices.pop(event["device"], None)


def _devices_by_node(devices):
    """Return devices keyed by device node."""
    return {device["device"]: device for device in devices}


def format_watch_screen(devices, last_event):
    """Render the interactive watch screen."""
    now = datetime.now().isoformat(timespec="seconds")
    rows = [
        tuple(device[field] for field in DEVICE_FIELDS)
        for device in sorted(devices.values(), key=lambda d: d["device"])
    ]

    lines = [
        f"lsusd watch  {len(rows)} USB serial device(s)  {now}",
        "Press Ctrl-C to stop.",
        "",
    ]
    if rows:
        lines.append(format_table(rows, DEVICE_HEADERS))
    else:
        lines.append("No USB serial devices connected.")

    if last_event:
        lines.extend(["", f"Last event: {_watch_event_summary(last_event)}"])
    return "\n".join(lines)


def parse_args(argv=None):
    parser = argparse.ArgumentParser(
        prog="lsusd",
        description="List USB devices with their associated USB metadata.",
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
        help="JSON output (newline-delimited in watch mode)",
    )

    parser.add_argument(
        "-n", "--no-spinner", action="store_true",
        help="disable the progress spinner",
    )
    parser.add_argument(
        "-w", "--watch", action="store_true",
        help="watch USB serial devices in a live table",
    )
    parser.add_argument(
        "-a", "--all", action="store_true",
        help="show all non-hub USB devices (default; kept for compatibility)",
    )
    parser.add_argument(
        "--serial", action="store_true",
        help="show only USB serial devices",
    )
    parser.add_argument(
        "--hubs", action="store_true",
        help="include USB hubs in device and tree output",
    )
    parser.add_argument(
        "-t", "--tree", action="store_true",
        help="show USB devices as a tree",
    )

    args = parser.parse_args(argv)
    if args.all and args.serial:
        parser.error("--all cannot be combined with --serial")
    if args.hubs and args.serial:
        parser.error("--hubs cannot be combined with --serial")
    if args.tree and args.serial:
        parser.error("--tree cannot be combined with --serial")
    if args.all and args.watch:
        parser.error("--all cannot be combined with --watch")
    if args.hubs and args.watch:
        parser.error("--hubs cannot be combined with --watch")
    if args.tree and args.watch:
        parser.error("--tree cannot be combined with --watch")
    if args.tree and (args.plain or args.csv or args.json):
        parser.error("--tree cannot be combined with --plain, --csv, or --json")
    return args


def print_devices(devices, args):
    """Print a one-shot device list in the selected output format."""
    fields = DEVICE_FIELDS if args.serial else ALL_DEVICE_FIELDS
    headers = DEVICE_HEADERS if args.serial else ALL_DEVICE_HEADERS

    if args.json:
        import json
        print(json.dumps([{field: d[field] for field in fields} for d in devices], indent=2))
    elif args.csv:
        import csv
        import io
        buf = io.StringIO()
        writer = csv.writer(buf)
        writer.writerow(fields)
        for d in devices:
            writer.writerow([d[field] for field in fields])
        print(buf.getvalue(), end="")
    elif args.plain:
        print(format_plain(devices, fields))
    else:
        rows = [tuple(d[field] for field in fields) for d in devices]
        print(format_table(rows, headers))


def watch_devices(watch_changes, args):
    """Stream USB serial add/remove events in the selected output format."""
    use_tui = not (args.json or args.csv or args.plain) and sys.stdout.isatty()
    csv_writer = None
    if args.csv:
        import csv
        csv_writer = csv.writer(sys.stdout)
        csv_writer.writerow(WATCH_HEADERS)
        sys.stdout.flush()

    devices = {}
    event_source = watch_changes(initial="snapshot") if use_tui else watch_changes()
    for event in event_source:
        if args.json:
            import json
            print(json.dumps(event), flush=True)
        elif args.csv:
            csv_writer.writerow([event[field] for field in WATCH_HEADERS])
            sys.stdout.flush()
        elif args.plain:
            print(format_watch_plain(event), flush=True)
        else:
            if use_tui:
                if event["action"] == "snapshot":
                    devices = _devices_by_node(event["devices"])
                    event = None
                else:
                    _update_watch_devices(devices, event)
                print("\033[H\033[2J" + format_watch_screen(devices, event), flush=True)
            else:
                print(format_watch_line(event), flush=True)


def main(argv=None):
    args = parse_args(argv)

    system = platform.system()
    if system == "Darwin":
        from lsusd.darwin import discover, discover_all, discover_tree, watch_changes
    elif system == "Linux":
        from lsusd.linux import discover, discover_all, discover_tree, watch_changes
    else:
        print(f"Unsupported platform: {system}", file=sys.stderr)
        sys.exit(1)

    if args.watch:
        try:
            watch_devices(watch_changes, args)
        except KeyboardInterrupt:
            sys.exit(130)
        return

    use_spinner = not args.no_spinner and sys.stderr.isatty()

    if use_spinner:
        with Spinner():
            if args.tree:
                devices = discover_tree(include_hubs=args.hubs)
            elif args.serial:
                devices = discover()
            else:
                devices = discover_all(include_hubs=args.hubs)
    else:
        if args.tree:
            devices = discover_tree(include_hubs=args.hubs)
        elif args.serial:
            devices = discover()
        else:
            devices = discover_all(include_hubs=args.hubs)

    if not devices:
        noun = "USB serial devices" if args.serial else "USB devices"
        print(f"No {noun} found.")
        sys.exit(0)

    if args.tree:
        print(format_tree(devices))
        return

    print_devices(devices, args)


if __name__ == "__main__":
    main()
