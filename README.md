# CornerNotes

A small floating macOS panel for quick notes and to-dos, pinned to a screen corner.

## Run

- Open `/Applications/CornerNotes.app` (or `build/CornerNotes.app`).
- A tiny handle appears in the bottom-right corner.
- Hover the handle to expand; click outside to collapse.
- Menu bar icon "CN" → Show Panel / Settings / Quit.

## Build

```sh
cd CornerNotes
./Scripts/build_app.sh
```

Requires macOS 13+ and the Xcode Command Line Tools (`xcode-select --install`).

## Data

Stored in `~/Library/Application Support/CornerNotes/state.json`.

## Settings

Corner picker and launch-at-login toggle inside the panel (gear icon).