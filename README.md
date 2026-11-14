# Tack

Sticky notes that live in your macOS menu bar: checklists, text and images, which you can pin to the desktop.

## Why

Tack is for small lists and scraps of text, like a packing list, today's errands or a note from a call. Apple's Stickies lives only on the desktop, and a full notes app is too heavy for a three-item list. Tack is one click away in the menu bar, and when a note needs to stay in view, you tack it to the desktop.

## Features

- **Menu bar popover** lists all your stickies, with search across titles and items.
- **Text or checklist**: a sticky is either free text or a to-do list, and you can switch between the two. In a checklist, Return adds an item, Backspace on an empty item removes it, and "Clear done" removes checked items.
- **Images**: paste with ⌘V (screenshots, copied images, image files from Finder) or drag them in. Click a thumbnail to open it full size.
- **Copy as Markdown**: copies the title, the text or `- [x]` checklist items, and any image links.
- **Pin to desktop**: a pinned sticky becomes its own window. Drag it by its top bar (or ⌘-drag from anywhere on it) across any of your displays, resize it, and change its colour. Each one has two modes:
  - *Normal*: an ordinary window that shows on every Space; other apps can cover it.
  - *Always on top*: floats above everything.
  Closing a pinned window only unpins the sticky. Nothing is deleted.
- **History**: archive a sticky to keep it. The History tab lets you browse, search, restore, or permanently delete old ones. Right-click a sticky and choose "Duplicate as new list" to reuse it as a template, with all items unchecked.
- **Persistence**: data is saved as JSON in `~/Library/Application Support/Tack/notes.json`, and images are saved in `images/` next to it. Pinned stickies reopen where you left them. Set `TACK_DATA_DIR` to use a different folder, for example for testing.

## Download

Get `Tack.zip` from the [latest release](https://github.com/boyanangelov/tack/releases/latest), unzip it and move `Tack.app` to your Applications folder.

The app is not signed with an Apple Developer ID, so macOS blocks it the first time. To allow it, open System Settings → Privacy & Security and click **Open Anyway**, or run:

```sh
xattr -dr com.apple.quarantine /Applications/Tack.app
```

## Requirements

- An Apple Silicon Mac (M1 or later) running macOS 14 (Sonoma) or later
- To build from source: the Xcode Command Line Tools (`xcode-select --install`). Xcode itself is not needed.

## Build & run

```sh
./install.sh            # build, copy to ~/Applications and start it
./build.sh              # or just build -> build/Tack.app
open build/Tack.app
```

## Start at login

Tick **Launch at login** at the bottom of the popover. Run Tack from `~/Applications` (`./install.sh` puts it there), so the login item points at a copy that stays put. If macOS asks for approval, click **Approve…** to open System Settings → Login Items.

## License

[MIT](LICENSE)
