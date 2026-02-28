# lsusd

CLI tool to list USB serial devices with their associated USB metadata.

## Releasing

1. Bump `version` in `pyproject.toml`
2. Commit and push
3. Create a GitHub release: `gh release create v<version> --title "v<version>" --notes "<summary>"`
4. Build and publish to PyPI: `python3 -m build && python3 -m twine upload dist/lsusd-<version>*`
