# lsusd — List USB Serial Devices

A zero-dependency command-line tool that maps USB serial device nodes to their USB metadata (vendor, product, serial number, VID:PID).

## Example Output

```
┌──────────────────────────┬───────────────────────┬──────────────┬──────────────┬───────────┐
│       Device Node        │      USB Product      │  USB Vendor  │  USB Serial  │  VID:PID  │
├──────────────────────────┼───────────────────────┼──────────────┼──────────────┼───────────┤
│ /dev/cu.usbmodem1124301  │ ELM327 OBD-II Adapter │ OBDII LLC    │ 00A037       │ 1FFB:2048 │
├──────────────────────────┼───────────────────────┼──────────────┼──────────────┼───────────┤
│ /dev/cu.usbserial-110    │ USB-Serial Controller  │ Prolific     │ ?            │ 067B:2303 │
└──────────────────────────┴───────────────────────┴──────────────┴──────────────┴───────────┘
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

## Supported Platforms

- **macOS** — discovers devices via `ioreg` (`/dev/cu.usbmodem*`, `/dev/cu.usbserial*`)
- **Linux** — discovers devices via sysfs (`/dev/ttyUSB*`, `/dev/ttyACM*`)

## License

MIT
