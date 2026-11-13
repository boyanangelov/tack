# StickyDo

A small, native macOS menu bar app for sticky-note checklists.

- **Menu bar popover** lists all your stickies, with search across titles and items.
- **Text or checklist**: a sticky is either free text or a to-do list, and you can switch between the two. In a checklist, Return adds an item, Backspace on an empty item removes it, and "Clear done" removes checked items.
- **Images**: paste with ⌘V (screenshots, copied images, image files from Finder) or drag them in. Click a thumbnail to open it full size.
- **Copy as Markdown**: copies the title, the text or `- [x]` checklist items, and any image links.
- **Pin to desktop**: a pinned sticky becomes its own window. Drag it by its top bar (or ⌘-drag from anywhere on it) across any of your displays, resize it, and change its colour. Each one has two modes:
  - *Normal*: an ordinary window that shows on every Space; other apps can cover it.
  - *Always on top*: floats above everything.
  Closing a pinned window only unpins the sticky. Nothing is deleted.
- **History**: archive a sticky to keep it. The History tab lets you browse, search, restore, or permanently delete old ones. Right-click a sticky and choose "Duplicate as new list" to reuse it as a template, with all items unchecked.
- **Persistence**: data is saved as JSON in `~/Library/Application Support/StickyDo/notes.json`, and images are saved in `images/` next to it. Pinned stickies reopen where you left them.
- Optional *Launch at login* (checkbox at the bottom of the popover). Run the app from `~/Applications` (`./build.sh --install`) so the login item points at a stable copy. If macOS asks for approval, click *Approve…* to open System Settings → Login Items.

## Build

Requires macOS 14+ and the Xcode Command Line Tools. Xcode is not needed.

```sh
./build.sh            # -> build/StickyDo.app
./build.sh --install  # also copies it to ~/Applications
open build/StickyDo.app
```

The app is ad-hoc signed. If Gatekeeper complains after you copy it to another Mac, right-click the app and choose Open.

## License

MIT
