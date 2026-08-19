# lsusd — List USB Devices

A zero-dependency `lsusb` successor for macOS and Linux. `lsusd` lists USB
devices with their USB metadata (bus, address, vendor, product, serial number,
VID:PID, device release, speed), can render the physical USB tree, and still
provides the original USB serial device view when requested.

The repository also contains **LSUSD for macOS**, a native macOS 26 menu-bar
app that presents the CLI's discovery, topology, serial monitoring, and export
features in a professional SwiftUI interface. The app talks to IOKit directly;
it neither launches nor parses the Python CLI.

One practical motivation for `lsusd` is that Homebrew's macOS `lsusb` formula
is a shell wrapper around `system_profiler SPUSBDataType`. On newer macOS
systems that data type can return no devices even when many USB devices are
connected; the USB data is available through `ioreg` and `SPUSBHostDataType`
instead. `lsusd` uses the IOKit registry directly, so it does not depend on
that stale `system_profiler` data type.

## Native macOS menu-bar app

The app lives in [`macOS/`](macOS/README.md) and targets macOS 26 or later. Its
menu-bar label shows the current USB and USB-serial device counts as
`USB·serial`. IOKit first-match and termination notifications keep the label,
the popover, and the event history current without polling.

The compact popover provides switchable USB and serial device lists plus
inline settings and quit controls. A separate device window covers the full
CLI surface: device details, optional hubs, expandable topology, serial device
nodes, event history, and plain-text, CSV, and JSON export.

The app is deliberately independent from the CLI package. Install either or
both products:

```bash
brew install lsusd
brew install --cask lsusd-menubar
```

For local development, install XcodeGen and Shark, then use:

```bash
make mac-build
make mac-test
make mac-run
```

The interface uses the macOS system typeface and native system controls; no
custom fonts are bundled.

## Example Output

```
❯ lsusd
┌─────┬────────┬─────────────┬────────────────────────────┬────────────┬───────────────────┬───────────┬─────────┬───────┐
│ Bus │ Device │ Location ID │        USB Product         │ USB Vendor │     USB Serial    │  VID:PID  │ Release │ Speed │
├─────┼────────┼─────────────┼────────────────────────────┼────────────┼───────────────────┼───────────┼─────────┼───────┤
│ 001 │ 003    │ 0x01210000  │ AX88179A                   │ ASIX       │ 00000000003C6D    │ 0B95:1790 │ 2.00    │ 5G    │
├─────┼────────┼─────────────┼────────────────────────────┼────────────┼───────────────────┼───────────┼─────────┼───────┤
│ 002 │ 013    │ 0x02121100  │ USB JTAG/serial debug unit │ Espressif  │ 34:85:18:AA:B7:C8 │ 303A:1001 │ 1.01    │ 12M   │
├─────┼────────┼─────────────┼────────────────────────────┼────────────┼───────────────────┼───────────┼─────────┼───────┤
│ 008 │ 002    │ 0x08200000  │ PSSD T7                    │ Samsung    │ S5TDNS0RB02541D   │ 04E8:4001 │ 1.00    │ 10G   │
└─────┴────────┴─────────────┴────────────────────────────┴────────────┴───────────────────┴───────────┴─────────┴───────┘
```

### Tree Output

```
❯ lsusd --tree --hubs
├─ Bus 002 Dev 001 ID 0451:8142 ? IOUSBHostDevice speed=480M loc=0x02100000 serial=05040051F077 hub
│  ├─ Bus 002 Dev 002 ID 17CC:1340 Native Instruments KOMPLETE KONTROL S25 speed=480M loc=0x02130000 serial=D1141A43
│  ├─ Bus 002 Dev 003 ID 05E3:0610 GenesysLogic USB2.1 Hub speed=480M loc=0x02120000 hub
│  │  ├─ Bus 002 Dev 004 ID 05E3:0610 GenesysLogic USB2.1 Hub speed=480M loc=0x02121000 hub
│  │  │  ├─ Bus 002 Dev 007 ID 0A12:1243 Audioengine Ltd. Audioengine 2+ speed=12M loc=0x02121400 serial=ABCDEFB1180003
│  │  │  ├─ Bus 002 Dev 008 ID 1A86:55D3 ? USB Single Serial speed=12M loc=0x02121200 serial=5ABA054875
│  │  │  └─ Bus 002 Dev 013 ID 303A:1001 Espressif USB JTAG/serial debug unit speed=12M loc=0x02121100 serial=34:85:18:AA:B7:C8
│  │  ├─ Bus 002 Dev 005 ID 05E3:0610 GenesysLogic USB2.1 Hub speed=480M loc=0x02122000 hub
│  │  │  ├─ Bus 002 Dev 009 ID 16D0:0EAC RUSOKU technologies TouCAN converter s/n: 00005351 speed=12M loc=0x02122100 serial=00005351
│  │  │  └─ Bus 002 Dev 014 ID 303A:82BF ENIAC Flexbar speed=12M loc=0x02122400 serial=F078E4E385A0
│  │  └─ Bus 002 Dev 006 ID 05E3:0610 GenesysLogic USB2.1 Hub speed=480M loc=0x02123000 hub
│  │     ├─ Bus 002 Dev 010 ID 045E:0039 Microsoft Microsoft 5-Button Mouse with IntelliEye(TM) speed=1.5M loc=0x02123100
│  │     ├─ Bus 002 Dev 011 ID 046D:082D ? HD Pro Webcam C920 speed=480M loc=0x02123200 serial=CA12361F
│  │     └─ Bus 002 Dev 012 ID 045E:07A5 Microsoft Microsoft® Nano Transceiver v2.1 speed=12M loc=0x02123300
│  └─ Bus 002 Dev 015 ID 043E:9A39 LG Electronics Inc. USB Controls speed=12M loc=0x02140000 serial=105NTKF6Q309
├─ Bus 003 Dev 001 ID 0BDA:0411 Generic USB3.2 Hub speed=5G loc=0x03200000 hub
├─ Bus 003 Dev 002 ID 0BDA:5411 Generic USB2.1 Hub speed=480M loc=0x03100000 hub
│  └─ Bus 003 Dev 003 ID 0BDA:1101 Realtek HID Device speed=480M loc=0x03140000
├─ Bus 001 Dev 001 ID 2109:2817 VIA Labs, Inc. USB2.0 Hub speed=480M loc=0x01100000 serial=000000000 hub
│  └─ Bus 001 Dev 004 ID 2109:8817 VIA Labs, Inc. PD3.0 USB-C Device speed=480M loc=0x01150000 serial=0000000000000001
├─ Bus 001 Dev 002 ID 2109:0817 VIA Labs, Inc. USB3.0 Hub speed=5G loc=0x01200000 serial=000000000 hub
│  └─ Bus 001 Dev 003 ID 0B95:1790 ASIX AX88179A speed=5G loc=0x01210000 serial=00000000003C6D
├─ Bus 000 Dev 001 ID 0BDA:0411 Generic USB3.2 Hub speed=5G loc=0x00200000 hub
├─ Bus 000 Dev 002 ID 0BDA:5411 Generic USB2.1 Hub speed=480M loc=0x00100000 hub
│  └─ Bus 000 Dev 003 ID 0BDA:1101 Realtek HID Device speed=480M loc=0x00140000
├─ Bus 008 Dev 001 ID 05E3:0608 ? USB2.0 Hub speed=480M loc=0x08300000 hub
└─ Bus 008 Dev 002 ID 04E8:4001 Samsung PSSD T7 speed=10G loc=0x08200000 serial=S5TDNS0RB02541D
```

## Installation

### pip / pipx

```bash
pip install lsusd
# or
pipx install lsusd
```

### Homebrew

```bash
brew tap mickeyl/formulae
brew install lsusd
```

### From source

```bash
pip install -e .
```

## Usage

```bash
lsusd
# or
python -m lsusd
```

### Options

| Flag | Description |
|------|-------------|
| `-p`, `--plain` | Tab-separated output, no headers — suitable for `cut`, `awk`, etc. |
| `-c`, `--csv` | CSV output with header row |
| `-j`, `--json` | JSON array output, or JSON Lines in watch mode |
| `-n`, `--no-spinner` | Disable the progress spinner |
| `-w`, `--watch` | Watch USB serial devices in a live table |
| `-a`, `--all` | Show all non-hub USB devices (default; kept for compatibility) |
| `--serial` | Show only USB serial devices |
| `--hubs` | Include USB hubs in device and tree output |
| `-t`, `--tree` | Show USB devices as a tree |
| `--version` | Print version and exit |

### USB Device Mode

```bash
lsusd
lsusd --all
lsusd --all --hubs
lsusd --plain
lsusd --json
lsusd --tree
lsusd --tree --hubs
```

By default, `lsusd` lists all non-hub USB devices visible to the platform.
`--all` is kept as an explicit alias for this default mode. Add `--hubs` to
include USB hubs. The columns are `bus`, `address`, `location`, `product`,
`vendor`, `serial`, `vidpid`, `release`, and `speed`.

`release` is the BCD-coded `bcdDevice` value from the standard USB device
descriptor. Manufacturers commonly use it for the device's firmware release,
but USB defines it more generally as a manufacturer-assigned device release
number. It uses the conventional USB two-group notation (`0x0100` becomes
`1.00`); `lsusd` does not infer a major/minor/patch version. A device that does
not expose the value is shown as `?`.

`--tree` shows the USB device hierarchy. Like `--all`, it hides hubs by default
and includes them with `--hubs`.

On macOS, both modes use the IOKit `IOUSB` registry plane instead of
`system_profiler`, which avoids the stale `SPUSBDataType` dependency used by
older `lsusb` wrappers.

### USB Serial Mode

```bash
lsusd --serial
lsusd --serial --plain
lsusd --serial --json
```

`--serial` shows the original lsusd view: USB serial device nodes mapped to
their USB metadata. The columns are `device`, `product`, `vendor`, `serial`,
`vidpid`, and `release`.

### Watch Mode

```bash
lsusd --watch
lsusd --watch --plain
lsusd --watch --json
```

`--watch` shows a live terminal table of connected USB serial devices and
redraws it after add/remove events. The machine-readable formats still emit
event streams: `--plain` and `--csv` use the columns `action`, `device`,
`product`, `vendor`, `serial`, `vidpid`, and `release`; `--json` emits
newline-delimited JSON objects. Initial devices use action `present`.

```
❯ lsusd --watch
lsusd watch  4 USB serial device(s)  2026-05-01T14:22:09
Press Ctrl-C to stop.

┌─────────────────────────┬────────────────────────────┬────────────┬───────────────────┬───────────┬─────────┐
│       Device Node       │        USB Product         │ USB Vendor │     USB Serial    │  VID:PID  │ Release │
├─────────────────────────┼────────────────────────────┼────────────┼───────────────────┼───────────┼─────────┤
│ /dev/cu.usbmodem2121101 │ USB JTAG/serial debug unit │ Espressif  │ D8:3B:DA:70:69:7C │ 303A:1001 │ 1.01    │
└─────────────────────────┴────────────────────────────┴────────────┴───────────────────┴───────────┴─────────┘
```

The watch implementation is push-driven, not a polling loop. On macOS, lsusd
subscribes to IOKit `IOSerialBSDClient` first-match and termination
notifications. On Linux, lsusd listens to kernel uevents through the netlink
socket. After an event arrives, lsusd takes a fresh snapshot only to compute the
added or removed device rows.

## Supported Platforms

- **macOS** — discovers USB devices via the `ioreg` `IOUSB` plane; serial mode maps `/dev/cu.usbmodem*` and `/dev/cu.usbserial*`
- **Linux** — discovers devices via sysfs (`/sys/bus/usb/devices` for USB device mode; any tty with a USB ancestor for serial mode)

## License

MIT
