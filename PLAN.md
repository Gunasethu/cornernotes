# CornerNotes — Plan

A small, native macOS floating panel for quick notes and to-dos, pinned to a screen corner.

## 1. Goal & UX

- A **tiny handle (tab)** is always visible in a chosen screen corner.
- **Hover** over the handle (or panel) **expands** the full panel.
- Once expanded, the panel **stays open** until the user **clicks outside**, then collapses back to the handle.
- Panel hosts two sections: **Notes** (paragraphs + bullet points) and **To-dos** (normal + completed with strikethrough).
- Everything persists locally; no network.

## 2. Tech stack (decided)

- **Native Swift** via Swift Package Manager (no Xcode required).
- **AppKit** for the floating window/panel behavior (`NSPanel`, always-on-top, all-spaces).
- **SwiftUI** for the in-panel UI (hosted in `NSHostingView`).
- **JSON** persistence in `~/Library/Application Support/CornerNotes/`.
- Build output is a proper `.app` bundle via a small script.

## 3. Window & corner behavior

- `NSPanel`, borderless, non-activating, `.floating` level, `.canJoinAllSpaces`.
- Rounded corners + shadow; frosted-glass background (`NSVisualEffectView`, dark material).
- **Handle**: ~44×44 rounded tab with SF Symbol icon, always visible.
- **Expanded panel**: ~360×520, grows from the chosen corner (bottom-right → expands left/up).
- **Corner**: configurable (bottom-right / top-right / bottom-left / top-left), stored in state. Default: bottom-right.
- **Positioning**: recompute on launch, screen change, and corner change; respect safe areas/margins (12px).
- **Collapse triggers**: click outside panel, `Esc` key. **Expand triggers**: hover on handle/panel.
- **Draggable**: panel can be dragged to reposition (optional, off by default to honor "sticks to corner").

## 4. Data model

```swift
enum NoteKind { case paragraph, bullet }
struct NoteBlock: Codable, Identifiable { id: UUID; kind: NoteKind; text: String }
struct TodoItem: Codable, Identifiable { id: UUID; text: String; done: Bool }
struct AppState: Codable {
    var notes: [NoteBlock]
    var todos: [TodoItem]
    var corner: Corner
    var launchAtLogin: Bool
}
```

- Auto-save on every edit (debounced ~300ms).
- Atomic write (temp file + rename).

## 5. UI (SwiftUI)

- `ContentView`: header (title + settings gear), `NotesView`, `TodosView`.
- `NotesView`: list of editable blocks.
  - Paragraph block = multi-line text editor.
  - Bullet block = single-line row prefixed with "•".
  - Toolbar: "+ Paragraph", "+ Bullet", delete (swipe/trailing button).
- `TodosView`: list of rows with checkbox + text.
  - Tap checkbox → toggle `done` → strikethrough + dimmed text.
  - Add via bottom text field + Return.
  - Delete via swipe/trailing button.
- `SettingsView`: corner picker, launch-at-login toggle, about.

## 6. Extras

- **Status bar item** (menu bar) with Open / Settings / Quit (accessory app, no Dock icon).
- **Launch at login** via `SMAppService` (macOS 13+), toggle in settings.
- **Keyboard**: `⌘N` new note, `⌘T` new todo, `Esc` collapse.
- Optional global hotkey to toggle panel (later).

## 7. Project layout

```
CornerNotes/
  Package.swift
  Sources/CornerNotes/
    main.swift
    AppDelegate.swift
    FloatingPanel.swift
    PanelController.swift
    Models.swift
    Store.swift
    HotCorner.swift
    Views/ (ContentView, NotesView, TodoView, SettingsView)
  Resources/Info.plist
  Scripts/build_app.sh
  PLAN.md
  README.md
```

## 8. Milestones

1. **M1 — Scaffold**: SPM project, build `.app`, launch empty accessory app.
2. **M2 — Floating shell**: panel + handle, hover expand, click-outside collapse, corner positioning.
3. **M3 — Content**: notes blocks + todos with in-memory state.
4. **M4 — Persistence**: JSON store + auto-save.
5. **M5 — Settings**: corner picker, launch-at-login.
6. **M6 — Polish**: vibrancy, animations, icons, shortcuts.
7. **M7 — Package**: build script, install to `/Applications`, README.

## 9. Open questions / assumptions

- Corner default chosen by user at runtime (configurable) — implemented as setting.
- Tech stack defaulted to native Swift (feasibility verified: SPM + AppKit build works on this machine).
- App name: **CornerNotes**.
- No cloud sync; local-only.
- Minimum macOS: 13 (Ventura) for `SMAppService` and modern SwiftUI.

## 10. Risks

- Non-activating panel + SwiftUI text editing: need panel to become key on expand for typing; handle carefully.
- Click-outside detection in multi-space: use global event monitor + frame hit-test.
- Hover detection across spaces: tracking areas must be recreated on space change.

---

**Next step:** confirm this plan, then start M1.
