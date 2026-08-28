# Changelog

All notable user-facing changes to LSUSD are documented in this file.

## [2.1.2] - 2026-08-28

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

[2.1.2]: https://github.com/mickeyl/lsusd/compare/macos-v2.1.1...macos-v2.1.2
[2.1.1]: https://github.com/mickeyl/lsusd/compare/macos-v2.1.0...macos-v2.1.1
[2.1.0]: https://github.com/mickeyl/lsusd/releases/tag/macos-v2.1.0
