# iyh

Native macOS menu bar utility that converts text typed with the wrong keyboard layout.

## How it works

- `⇧⌘1` converts selected text.
- With no selection, it converts the last word before the cursor.
- It uses physical key positions instead of a hard-coded layout table.
- After replacement, it selects the next available macOS layout. Press `⇧⌘1` again to continue cycling.
- Password fields are intentionally ignored.

Example: with the `ABC` layout, `ghbdtn` is converted using the next available layout.

## Build

```sh
./scripts/build.sh
```

Built app: `dist/iyh.app` (Universal: Intel + Apple Silicon).

To install:

```sh
./scripts/install.sh
```

On first launch, macOS asks for permission to control your computer. Enable `iyh` in:

`System Settings → Privacy & Security → Accessibility`.

The app does not record keystrokes, use the network, or change the clipboard. It reads and replaces only the selection or the word immediately before the cursor through the macOS Accessibility API.
