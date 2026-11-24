<img src="Branding/icon.png" width="128" alt="TrustyShots icon">

# TrustyShots

**Pick your shots. Paste them all.**

A macOS menu bar app for handing over several screenshots at once.

**Select → ⌘C → paste.** Works with Claude Code, claude.ai, ChatGPT, Gmail, Obsidian and anything else that accepts pasted files.

> Version 0.1.0, in development.

## Features

- **Multi-select:** thumbnails of the newest 60 images, pasted in the order you click them
- **One copy for everything:** apps get the files, terminals get paths
- **Drag and drop:** drag one screenshot, or the whole selection
- **Large preview** with Space
- **Safe delete:** files go to the Trash, and ⌘Z restores them
- **Saves macshot ⌘C captures**, which macshot itself only copies (optional)
- **Auto-clean:** trashes images older than 14 days (optional, off by default)
- **Nine themes:** Light, Dark, Nord, Gruvbox, Dracula, Catppuccin, Tokyo Night, Solarized, One Dark

## Install

There is no installer yet, so build it from source. You need macOS 14 or later and the Xcode Command Line Tools (`xcode-select --install`). Xcode is not required.

```sh
./build.sh
open "dist/TrustyShots.app"
```

The app appears in the menu bar, not in the Dock. The build is signed ad hoc, so it is not ready to distribute to other Macs.

## Use

1. Click the menu bar icon.
2. Click the screenshots you want. The badges show the order.
3. Press **⌘C**, then paste with **⌘V** where you need them.

| Action | How |
|---|---|
| Open or close the panel | Click the icon, or use your own shortcut |
| Copy the selection | ⌘C |
| Select all shown | ⌘A |
| Preview | Space, over a thumbnail |
| Delete the selection | **Delete** button |
| Undo a delete | ⌘Z |
| Close the preview or panel | Esc |
| Move the panel | Drag the handle at the top |
| Reset position and size | Double-click the handle |
| About, Settings, Reset Position, Trash All, Quit | Right-click the icon |

## Settings

| Setting | Default |
|---|---|
| Folder | Your macOS screenshot folder; `~/Screenshots` if none is set or it is a shared one such as Desktop |
| Theme | Choose from nine |
| Toggle panel (global shortcut) | None |
| Save macshot ⌘C captures | Off |
| Hide after copy | Off |
| Hide when clicking outside | On |
| Trash images older than 14 days | Off |
| Start at login | Off |

**Trash All and auto-clean act on every image in the folder**, including those not shown. Use a folder that holds only screenshots.

## Privacy

- The app has no network code.
- ⌘C puts only the screenshots you selected on the clipboard.
- For terminals, it copies the selection to a private folder, the outbox: `~/Library/Caches/io.github.zkrogfoss.trustyshots/outbox`. The next ⌘C replaces the contents. Deleting screenshots in the app or quitting empties it.

## Claude Code

Pasting works with default settings. If your settings turn on `permissions.blockReadsOutsideWorkingDirectories`, you get paths instead of images. Allow the outbox in `~/.claude/settings.json`:

```json
{
  "permissions": {
    "additionalDirectories": ["~/Library/Caches/io.github.zkrogfoss.trustyshots/outbox"]
  }
}
```

Merge this into your existing settings. Only the outbox becomes readable, not your screenshot folder.

## Known limits

- **Firefox** pastes only the first file ([bug 864052](https://bugzilla.mozilla.org/show_bug.cgi?id=864052)). Drag the selection instead.
- **macshot captures** are saved only when macshot's capture overlay was open within the last 3 seconds. Images copied in other apps are ignored.

## Development

Swift, AppKit and SwiftUI, with no third-party dependencies.

```text
Sources/TrustyShots/
├── main.swift            app, menu bar icon, panel position
├── MenuBarIcon.swift     menu bar icon
├── ShelfPanel.swift      panel window and keys
├── PanelView.swift       panel layout
├── WindowDrag.swift      drag handle
├── Tile.swift            thumbnails, selection, dragging
├── Preview.swift         large preview
├── Store.swift           screenshots, selection, auto-clean
├── Copier.swift          clipboard and outbox
├── TrashBin.swift        Trash and undo
├── ClipboardSaver.swift  macshot captures
├── HotKey.swift          global shortcut
├── SettingsWindow.swift  settings
├── Prefs.swift           saved preferences
├── Theme.swift           themes
└── LoginItem.swift       start at login
```

To try it on another folder for one run, quit the app and start it with:

```sh
"dist/TrustyShots.app/Contents/MacOS/TrustyShots" -folder /path/to/images
```

Two linker warnings about missing search paths are expected with the Command Line Tools.

## License

Copyright (c) 2026 zkrogfoss. [GPL-3.0-only](LICENSE), without any warranty.
