import AppKit
import SwiftUI
import Combine

/// A borderless-looking window that can still take keyboard focus.
final class NoteWindow: NSWindow {
    var noteID: UUID!
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Height of the top bar that acts as a drag handle, and width reserved for buttons at either end.
    private let barHeight: CGFloat = 34
    private let leftButtons: CGFloat = 30
    private let rightButtons: CGFloat = 115

    /// Intercept clicks before SwiftUI sees them: dragging the top bar (or ⌘-dragging anywhere) moves the sticky.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            let p = event.locationInWindow
            let inBar = p.y >= frame.height - barHeight && p.x > leftButtons && p.x < frame.width - rightButtons
            if inBar || event.modifierFlags.contains(.command) {
                trackDrag()
                return
            }
        }
        super.sendEvent(event)
    }

    private func trackDrag() {
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        NSCursor.closedHand.push()
        defer { NSCursor.pop() }
        let start = NSEvent.mouseLocation
        let origin = frame.origin
        while let e = nextEvent(matching: [.leftMouseDragged, .leftMouseUp], until: .distantFuture, inMode: .eventTracking, dequeue: true) {
            if e.type == .leftMouseUp { break }
            let now = NSEvent.mouseLocation
            setFrameOrigin(NSPoint(x: origin.x + now.x - start.x, y: origin.y + now.y - start.y))
        }
    }

    /// Don't snap the sticky back to one screen — let it go anywhere across displays.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// Keeps one desktop window open for every pinned, non-archived note.
@MainActor
final class PinManager: NSObject, NSWindowDelegate {
    static let shared = PinManager()

    private let store = NoteStore.shared
    private var windows: [UUID: NoteWindow] = [:]
    private var cancellable: AnyCancellable?

    func start() {
        cancellable = store.$notes
            .receive(on: RunLoop.main)
            .sink { [weak self] notes in self?.sync(notes) }
    }

    func focus(_ id: UUID) {
        guard let w = windows[id] else { return }
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    private func sync(_ notes: [Note]) {
        let wanted = Dictionary(uniqueKeysWithValues: notes.filter { $0.pinned && !$0.archived }.map { ($0.id, $0) })

        for (id, w) in windows where wanted[id] == nil {
            w.delegate = nil          // closing programmatically; don't treat as "unpin"
            w.close()
            windows[id] = nil
        }
        for (id, note) in wanted {
            let w = windows[id] ?? makeWindow(note)
            apply(note, to: w)
        }
    }

    private func makeWindow(_ note: Note) -> NoteWindow {
        let frame = note.frame.map { onScreen($0.nsRect) } ?? defaultFrame()
        let w = NoteWindow(contentRect: frame,
                           styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                           backing: .buffered, defer: false)
        w.noteID = note.id
        w.isReleasedWhenClosed = false
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isMovableByWindowBackground = true
        w.standardWindowButton(.miniaturizeButton)?.isHidden = true
        w.standardWindowButton(.zoomButton)?.isHidden = true
        w.minSize = NSSize(width: 180, height: 140)
        w.hasShadow = true
        w.contentView = NSHostingView(rootView: NoteEditor(id: note.id, inWindow: true).environmentObject(store))
        w.setFrame(frame, display: false)
        w.delegate = self
        windows[note.id] = w
        w.orderFrontRegardless()
        if note.frame == nil { store.update(note.id, touch: false) { $0.frame = Rect(w.frame) } }
        return w
    }

    private func apply(_ note: Note, to w: NoteWindow) {
        w.backgroundColor = note.color.nsColor
        switch note.mode {
        case .desktop:
            // Normal window layer: a desktop-icon-level window can't reliably be clicked or dragged
            // (macOS treats clicks there as clicks on the wallpaper).
            if w.level != .normal { w.level = .normal; w.orderFrontRegardless() }
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        case .onTop:
            if w.level != .floating { w.level = .floating; w.orderFrontRegardless() }
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        }
    }

    /// If the saved position is on a display that's no longer connected, bring it back onto the main screen.
    private func onScreen(_ r: NSRect) -> NSRect {
        let visible = NSScreen.screens.contains { $0.visibleFrame.intersects(r.insetBy(dx: 40, dy: 40)) }
        if visible { return r }
        let s = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSRect(x: s.maxX - r.width - 40, y: s.maxY - r.height - 40, width: r.width, height: r.height)
    }

    private func defaultFrame() -> NSRect {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let offset = CGFloat(windows.count % 8) * 28
        return NSRect(x: screen.maxX - 300 - offset, y: screen.maxY - 300 - offset, width: 260, height: 260)
    }

    // MARK: NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        guard let w = notification.object as? NoteWindow, let id = w.noteID else { return }
        windows[id] = nil
        store.update(id, touch: false) { $0.pinned = false }   // closing = unpin, never delete
    }
    func windowDidMove(_ notification: Notification) { saveFrame(notification) }
    func windowDidChangeScreen(_ notification: Notification) { saveFrame(notification) }
    func windowDidEndLiveResize(_ notification: Notification) { saveFrame(notification) }

    private func saveFrame(_ notification: Notification) {
        guard let w = notification.object as? NoteWindow, let id = w.noteID else { return }
        store.update(id, touch: false) { $0.frame = Rect(w.frame) }
    }
}
