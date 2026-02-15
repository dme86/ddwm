# ddwm

`ddwm` (Dan's Darwin Window Manager) is a keyboard-driven tiling window manager for macOS with dynamic dwm-style behavior: windows are managed as a deterministic stack per workspace and continuously reflow in `tile` (main + stack) or `monocle` layout.

## Installation

### Build from source
Currently, source compilation is the supported installation path.

Requirements:
- macOS
- Swift toolchain matching `Package.swift`
- Xcode (for app bundle/release workflows)

Build debug binaries:
```bash
./build-debug.sh
```

Run app server:
```bash
./run-debug.sh
```

Run CLI:
```bash
./run-cli.sh --help
```

## Configuration

Default config lives at:
- `docs/config-examples/default-config.toml`

User config path:
- `~/.ddwm.toml`

First-time setup:
```bash
cp docs/config-examples/default-config.toml ~/.ddwm.toml
```

Apply changes:
- If auto-reload is enabled, save the file.
- Otherwise run:
```bash
ddwm reload-config
```

## Basic Usage

Core commands:
- Focus next/prev: `ddwm focus dfs-next`, `ddwm focus dfs-prev`
- Swap with main: `ddwm swap master`
- Reorder stack: `ddwm move up`, `ddwm move down`
- Adjust main ratio: `ddwm resize smart +5`, `ddwm resize smart -5`
- Toggle layout: `ddwm layout tile monocle`
- Toggle floating: `ddwm layout floating tiling`

Config keybindings are defined under `[mode.main.binding]` in `~/.ddwm.toml` (single-mode dwm setup).

Example keybinds:
```toml
[mode.main.binding]
alt-shift-m = 'layout tile monocle'
alt-shift-j = 'focus dfs-next'
alt-shift-k = 'focus dfs-prev'
alt-enter = 'swap master'
alt-1 = 'workspace 1'
alt-2 = 'workspace 2'
alt-3 = 'workspace 3'
alt-4 = 'workspace 4'
alt-keypad1 = 'workspace 1'
alt-keypad2 = 'workspace 2'
alt-keypad3 = 'workspace 3'
alt-keypad4 = 'workspace 4'
```

## Troubleshooting

- `ddwm` CLI cannot connect:
  - Ensure the app/server is running (`./run-debug.sh` or installed app is open).
- Commands do nothing:
  - Reload config (`ddwm reload-config`) and check for syntax errors.
- Accessibility issues:
  - Grant Accessibility permissions to `ddwm` in macOS Settings.
- Multi-monitor odd behavior:
  - Verify monitor arrangement in macOS Display settings.

## License

See `LICENSE.txt`.
