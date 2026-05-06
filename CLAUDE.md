# lsusd

CLI tool to list USB devices with their associated USB metadata. As of 2.0,
`lsusd` is positioned as a zero-dependency `lsusb` successor for macOS and
Linux:

- Default command lists all non-hub USB devices.
- `--hubs` includes USB hubs in device and tree output.
- `--tree` renders the USB device hierarchy.
- `--serial` preserves the original USB serial device-node view.
- `--watch` is still USB-serial-specific.

## Releasing

1. Bump `version` in `pyproject.toml`
2. Commit and push
3. Create a GitHub release: `gh release create v<version> --title "v<version>" --notes "<summary>"`
4. Build and publish to PyPI: `python3 -m build && python3 -m twine upload dist/lsusd-<version>*`
5. Update Homebrew formula in `~/Documents/late/homebrew-formulae/Formula/lsusd.rb`:
   - Update `url` tag to `v<version>`
   - Update `version`
   - Update `sha256` (get via `curl -sL https://github.com/mickeyl/lsusd/archive/refs/tags/v<version>.tar.gz | shasum -a 256`)
   - Commit and push the formula repo
