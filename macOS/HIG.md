# LSUSD macOS Interface Guidelines

## Product shape

LSUSD is a menu-bar utility with a compact status panel and one optional device window. The status panel is optimized for quick inspection; dense inventory, topology, event history, search, and export live in the device window.

## Platform and appearance

- Minimum platform: macOS 26.
- Follow the system Light or Dark appearance.
- Use native SwiftUI controls, materials, tables, inspectors, menus, and toolbars.
- Do not bundle or register custom fonts. Use system text styles and monospaced system variants for technical identifiers.

## Semantic roles

- Primary text: device product and primary labels.
- Secondary text: vendor, status context, timestamps, and unavailable metadata.
- Data text: VID:PID, location ID, serial number, release, and device node.
- Speed badge: system caption text in a semantic capsule; never monospaced. The
  tint is gray through 12 Mbit/s, blue through 480 Mbit/s, orange below
  10 Gbit/s, and purple from 10 Gbit/s upward. Color supplements the visible
  speed value and is never the sole information carrier.
- Serial badge: terminal SF Symbol in a semantic capsule, suffixed to the product name.
- Success: connected/add events and devices first detected while the status panel is open.
- Secondary: present/initial state.
- Destructive: disconnected/remove events and devices removed while the status panel is open.

## Live device changes

- The menu-bar count and main device window always reflect the current IOKit snapshot.
- While the status panel remains open, newly detected devices use a visible `New` badge and a subtle success tint.
- Removed devices remain in the open status panel with a `Removed` badge, destructive tint, and struck-through name. They are not actionable.
- Closing and reopening the status panel, or using its refresh control, starts a new presentation cycle: removed rows disappear and transient badges clear.
- USB changes stay notification-driven. A short notification debounce may allow the IOKit registry to settle, but must not become a polling loop.

## Layout metrics

- Menu panel size: 380 x 760 points, constrained by the available screen height.
- Main window minimum: 820 x 500 points; default: 1100 x 680 points.
- Inspector width: 260-380 points.
- Dense table and tree rows use native macOS control metrics.
- Scrollable menu rows reserve 12 points between trailing badges and the scroll indicator.

## Accessibility and localization

- All icon-only controls need explicit accessibility labels and help text.
- Dynamic device data is never used as a localization key.
- All user-visible interface copy is available in English and German.
- Technical exports remain locale-neutral and preserve the CLI field names and formats.
