# Changelog

All notable user-facing changes to LSUSD are documented in this file.

## [2.1.3] - 2026-10-17 (CLI)

- Keep the CLI version aligned with the macOS 2.1.3 release. CLI behavior is
  unchanged from 2.1.2.

## [macOS 2.1.3] - 2026-10-17

### Added

- Show available serial device nodes in the USB device table, topology,
  inspector, and menu-bar panel. Multi-port devices list every port.
- Copy an individual serial port path from the right-click menu in the app.

### Changed

- Use the CLI-compatible `device` field instead of `location` in USB device
  exports. Missing nodes remain `?` in data exports and display as an em dash
  in the interface.

## [2.1.2] - 2026-10-17 (CLI)

### Changed

- Use an em dash for missing values in human-readable CLI output, including
  USB serial numbers. Data formats retain their existing question marks.
- Add automatic terminal colors for device nodes, USB IDs, speed tiers, and
  watch events. Respect `NO_COLOR` and `TERM=dumb`; keep redirected output
  and data formats free of color codes.
- Show available serial device nodes in the default CLI table, plain, CSV,
  JSON, and tree output. Multiple ports on one USB device are listed together.
- Replace the CLI Location ID column (`location`) with Device Node (`device`).
  Location information remains internal for ordering and physical port matching.
  Scripts that read the previous `location` field or third plain-text column
  must account for the new serial device node value (`?` when absent).
- Keep `--serial` as a compatibility option for the original per-port view.

## [macOS 2.1.2] - 2026-08-28

### Fixed

- Recognized USB devices reconnected to the same port without leaving duplicate
  removed and new entries in the open menu-bar panel.

## [2.1.1] - 2026-08-21

### Added

- Added a dedicated macOS app icon for Spotlight, Finder, and system app
  pickers.
- Added visual markers for devices connected or removed while the menu-bar
  panel is open.

### Improved

- Kept the open device list synchronized with IOKit connection and termination
  notifications.
- Preserved removed devices for one panel cycle so hardware changes remain
  visible instead of disappearing immediately.
- Updated the Settings and About attribution.

## [2.1.0] - 2026-08-19

### Added

- Added the native macOS 26 menu-bar app with USB and serial counts, device
  lists, topology, event history, settings, and export support.
- Added color-coded USB speed badges and configurable device sorting.

[2.1.3]: https://github.com/mickeyl/lsusd/compare/v2.1.2...v2.1.3
[macOS 2.1.3]: https://github.com/mickeyl/lsusd/compare/macos-v2.1.2...macos-v2.1.3
[2.1.2]: https://github.com/mickeyl/lsusd/compare/v2.1.1...v2.1.2
[macOS 2.1.2]: https://github.com/mickeyl/lsusd/compare/macos-v2.1.1...macos-v2.1.2
[2.1.1]: https://github.com/mickeyl/lsusd/compare/macos-v2.1.0...macos-v2.1.1
[2.1.0]: https://github.com/mickeyl/lsusd/releases/tag/macos-v2.1.0
