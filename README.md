# lsusd — List USB Serial Devices

A zero-dependency command-line tool that maps USB serial device nodes to their USB metadata (vendor, product, serial number, VID:PID).

## Example Output

```
❯ lsusd
┌────────────────────────────────┬────────────────────────────┬──────────────────┬───────────────────┬───────────┐
│          Device Node           │        USB Product         │    USB Vendor    │     USB Serial    │  VID:PID  │
├────────────────────────────────┼────────────────────────────┼──────────────────┼───────────────────┼───────────┤
│ /dev/cu.usbmodem2121101        │ USB JTAG/serial debug unit │ Espressif        │ D8:3B:DA:70:69:7C │ 303A:1001 │
├────────────────────────────────┼────────────────────────────┼──────────────────┼───────────────────┼───────────┤
│ /dev/cu.usbmodemF078E4E385A03  │ Flexbar                    │ ENIAC            │ F078E4E385A0      │ 303A:82BF │
├────────────────────────────────┼────────────────────────────┼──────────────────┼───────────────────┼───────────┤
│ /dev/cu.usbserial-113010893810 │ OBDLink SX                 │ ScanTool.net LLC │ 113010893810      │ 0403:6015 │
├────────────────────────────────┼────────────────────────────┼──────────────────┼───────────────────┼───────────┤
│ /dev/cu.usbserial-ST8XVRNW     │ ElmScan 5 Compact          │ ScanTool.net LLC │ ST8XVRNW          │ 0403:6001 │
└────────────────────────────────┴────────────────────────────┴──────────────────┴───────────────────┴───────────┘
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
| `-j`, `--json` | JSON array output |
| `-n`, `--no-spinner` | Disable the progress spinner |
| `--version` | Print version and exit |

## Supported Platforms

- **macOS** — discovers devices via `ioreg` (`/dev/cu.usbmodem*`, `/dev/cu.usbserial*`)
- **Linux** — discovers devices via sysfs (`/dev/ttyUSB*`, `/dev/ttyACM*`)

## License

MIT
