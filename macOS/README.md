# LSUSD for macOS

LSUSD for macOS is a native menu-bar companion to the cross-platform `lsusd` CLI. It targets macOS 26 and uses SwiftUI, Observation, Swift Concurrency, and direct IOKit discovery. It does not launch or parse the Python CLI.

## CLI capability mapping

| CLI | macOS app |
| --- | --- |
| Default device list | Devices table and menu-bar summary |
| `--hubs` | Show USB hubs toggle |
| `--tree` | Expandable Topology view |
| `--serial` (compatibility) | Serial table with device nodes |
| `--watch` | Push-driven Serial event history |
| `--json` | Copy or export JSON |
| `--csv` | Copy or export CSV |
| `--plain` | Copy or export tab-separated text |

Device exports use the USB value formatting shared with the CLI. Since CLI
2.1.2, the CLI's default output includes serial device nodes in place of
location IDs; the app's device exports retain their existing location field. Event history
exports preserve the watch fields: `action`, `device`, `product`, `vendor`,
`serial`, `vidpid`, and `release`.

CLI 2.1.2 also uses em dashes for missing values and automatic terminal colors.
These are CLI presentation changes; the native app uses its own SwiftUI
presentation and export formatting. The current macOS app release remains
2.1.2 (`macos-v2.1.2`), published separately from CLI tag `v2.1.2`.

## Architecture

- `LSUSDCore` contains Sendable value models, direct IOKit discovery, topology construction, and export formatting.
- `AppModel` is the main-actor UI state boundary and calls the repository actor asynchronously.
- `IOKitChangeMonitor` uses matching notifications for `IOUSBHostDevice` and `IOSerialBSDClient`; device counts and watch events require no polling loop.
- The app is an `LSUIElement` menu-bar utility. Its main window is suppressed at launch and opens on demand.
- The signed app uses App Sandbox with USB and user-selected file access entitlements.

The interface follows the system appearance and uses only the macOS system typeface. Technical identifiers use the monospaced system design.

## Build and test

XcodeGen and Shark are required locally.

```sh
make mac-build
make mac-test
make mac-run
```

`make mac-build` generates `macOS/LSUSD.xcodeproj`, builds, and signs the Debug app with the configured development team. The product is written to `macOS/DerivedData/Build/Products/Debug/LSUSD.app`.

## Homebrew release

The native app ships independently from the Python formula as the
`lsusd-menubar` Homebrew Cask. App releases use the tag `macos-v<version>` and
the GitHub asset name `LSUSD-<version>-macOS.zip`.

```sh
make mac-release NOTARY_PROFILE=NOTARIZE
```

This target creates a universal Release build, signs it with Developer ID,
enables the hardened runtime, removes development-only signing entitlements,
submits it for notarization, staples the ticket, verifies Gatekeeper
acceptance, and writes the final archive to `macOS/Dist/`. Upload that exact
archive without rebuilding it, then copy the printed SHA-256 to
`../homebrew-formulae/Casks/lsusd-menubar.rb`.
