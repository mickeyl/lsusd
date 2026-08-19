# lsusd

This repository contains two related products:

1. `lsusd`, a zero-dependency Python CLI and `lsusb` successor for macOS and
   Linux.
2. `macOS/`, the native LSUSD menu-bar app for macOS 26 and later.

The CLI provides these discovery and output contracts:

- Default command lists all non-hub USB devices.
- `--hubs` includes USB hubs in device and tree output.
- `--tree` renders the USB device hierarchy.
- `--serial` preserves the original USB serial device-node view.
- `--watch` is still USB-serial-specific.

## Native macOS App

- `macOS/project.yml` is the XcodeGen source of truth. Do not hand-edit the
  generated `macOS/LSUSD.xcodeproj`.
- `LSUSDCore` owns Sendable USB models, direct IOKit discovery, topology, and
  export formatting. The app does not invoke or parse the Python CLI.
- `AppModel` is the main-actor UI state boundary. Keep blocking IOKit work off
  the main actor and preserve Swift 6 strict-concurrency correctness.
- Device and serial changes are push-driven through IOKit matching
  notifications. Do not add a polling timer for counts, lists, or events.
- The menu-bar label shows `USB·serial` counts. The popover uses the USB and
  serial count controls to switch lists; settings and quit are icon-only
  controls at the bottom, with settings shown inline.
- Use native macOS controls, semantic system colors, SF Symbols, and the system
  typeface. Do not add custom fonts.
- Keep the App Sandbox USB and user-selected file entitlements intact.

Run `make mac-build` after app or project changes and `make mac-test` after core
model, discovery, topology, or export changes. XcodeGen and Shark are local
build prerequisites.

## USB Device Release Metadata

All discovery modes expose the standard USB `bcdDevice` descriptor as the
`release` field. The normal table labels it `Release`; tree output uses
`release=<value>`. Serial watch events carry the same field so table, plain,
CSV, and JSON output stay aligned.

Treat `bcdDevice` as a manufacturer-assigned device release, not as a guaranteed
firmware or Semantic Versioning field. Preserve the conventional USB BCD
presentation with two groups (`0x0100` becomes `1.00`, `0x0060` becomes `0.60`)
and do not invent a major/minor/patch interpretation. macOS supplies the raw
integer through IOKit; Linux supplies its formatted value through the sysfs
`bcdDevice` attribute.

Run `make check` after changing CLI discovery or output contracts. It compiles
the sources, runs the unit tests, and checks the CLI entry point.

## Releasing the CLI

1. Bump `version` in `pyproject.toml`
2. Commit and push
3. Create a GitHub release: `gh release create v<version> --title "v<version>" --notes "<summary>"`
4. Build and publish to PyPI: `python3 -m build && python3 -m twine upload dist/lsusd-<version>*`
5. Update Homebrew formula in `~/Documents/late/homebrew-formulae/Formula/lsusd.rb`:
   - Update `url` tag to `v<version>`
   - Update `version`
   - Update `sha256` (get via `curl -sL https://github.com/mickeyl/lsusd/archive/refs/tags/v<version>.tar.gz | shasum -a 256`)
   - Commit and push the formula repo

## Releasing the macOS App

The app and CLI use the same marketing version but independent release tags.
App releases use `macos-v<version>` so an existing CLI tag such as `v2.1.0`
does not collide with the app release.

1. Set `MARKETING_VERSION` for both targets in `macOS/project.yml`.
2. Commit the release state. The app build number is stamped from the Git
   commit count.
3. Run `make mac-test` and `make mac-build`.
4. Create the Developer-ID-signed, hardened, notarized release archive with
   `make mac-release NOTARY_PROFILE=<notarytool-profile>`.
5. Verify the printed SHA-256 and the artifact name
   `macOS/Dist/LSUSD-<version>-macOS.zip` against
   `../homebrew-formulae/Casks/lsusd-menubar.rb`.
6. Create and push tag `macos-v<version>`, then attach that exact ZIP to the
   matching GitHub release. Do not rebuild the archive after recording its
   checksum.
7. Run `brew style Casks/lsusd-menubar.rb` and, once the asset is live,
   `brew audit --new --cask Casks/lsusd-menubar.rb` in the tap before committing
   and pushing the Cask.

The Homebrew CLI package remains `Formula/lsusd.rb`; the `.app` bundle belongs
in the separate `Casks/lsusd-menubar.rb` Cask.
