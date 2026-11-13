import AppKit
import UniformTypeIdentifiers

/// Pasted / dropped images are stored as PNG files next to notes.json.
enum ImageStore {
    static let dir: URL = {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StickyDo/images", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()
    private static var cache: [String: NSImage] = [:]

    static func url(_ name: String) -> URL { dir.appendingPathComponent(name) }

    static func save(_ image: NSImage) -> String? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        let name = UUID().uuidString + ".png"
        do { try png.write(to: url(name), options: .atomic) } catch { return nil }
        cache[name] = image
        return name
    }

    static func load(_ name: String) -> NSImage? {
        if let img = cache[name] { return img }
        let img = NSImage(contentsOf: url(name))
        cache[name] = img
        return img
    }

    static func delete(_ name: String) {
        cache[name] = nil
        try? FileManager.default.removeItem(at: url(name))
    }
}

/// Routes ⌘V with an image on the clipboard to whichever sticky is in front.
@MainActor
enum PasteRouter {
    static var popoverNote: UUID?
    private static var monitor: Any?

    static func install() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            let mods = e.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard mods == .command, e.charactersIgnoringModifiers == "v", let id = target() else { return e }
            return pasteImages(into: id) ? nil : e
        }
    }

    private static func target() -> UUID? {
        if let w = NSApp.keyWindow as? NoteWindow { return w.noteID }
        return popoverNote
    }

    /// Returns true if the clipboard held images (and they were added); false lets normal text paste run.
    static func pasteImages(into id: UUID) -> Bool {
        let pb = NSPasteboard.general
        // Image files copied in Finder
        if let urls = pb.readObjects(forClasses: [NSURL.self],
                                     options: [.urlReadingFileURLsOnly: true,
                                               .urlReadingContentsConformToTypes: [UTType.image.identifier]]) as? [URL],
           !urls.isEmpty {
            urls.compactMap(NSImage.init(contentsOf:)).forEach { NoteStore.shared.addImage(id, $0) }
            return true
        }
        let hasImage = pb.availableType(from: [.png, .tiff]) != nil
        guard hasImage else { return false }
        // Plain text wins, unless the "text" is just the image's web address.
        if let str = pb.string(forType: .string), !str.hasPrefix("http") { return false }
        guard let imgs = pb.readObjects(forClasses: [NSImage.self]) as? [NSImage], !imgs.isEmpty else { return false }
        imgs.forEach { NoteStore.shared.addImage(id, $0) }
        return true
    }

    /// Drag-and-drop of images or image files onto a sticky.
    static func handleDrop(_ providers: [NSItemProvider], into id: UUID) -> Bool {
        var handled = false
        for p in providers where p.canLoadObject(ofClass: NSImage.self) {
            handled = true
            _ = p.loadObject(ofClass: NSImage.self) { obj, _ in
                guard let img = obj as? NSImage else { return }
                DispatchQueue.main.async { NoteStore.shared.addImage(id, img) }
            }
        }
        return handled
    }
}

enum MarkdownExport {
    static func markdown(_ n: Note) -> String {
        var out: [String] = []
        let t = n.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { out.append("# \(t)\n") }
        switch n.kind {
        case .text:
            let b = n.body.trimmingCharacters(in: .whitespacesAndNewlines)
            if !b.isEmpty { out.append(b) }
        case .checklist:
            let lines = n.nonEmptyItems.map { "- [\($0.done ? "x" : " ")] \($0.text)" }
            if !lines.isEmpty { out.append(lines.joined(separator: "\n")) }
        }
        if !n.images.isEmpty {
            out.append("")
            out.append(n.images.map { "![image](\(ImageStore.url($0).absoluteString))" }.joined(separator: "\n"))
        }
        return out.joined(separator: "\n")
    }

    static func copy(_ n: Note) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown(n), forType: .string)
    }
}
