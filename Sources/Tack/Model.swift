import SwiftUI
import AppKit

struct TodoItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String = ""
    var done: Bool = false
    var indentation: Int? = nil

    static let maxDepth = 5
    var depth: Int { max(0, min(Self.maxDepth, indentation ?? 0)) }
}

enum PinMode: String, Codable, CaseIterable {
    case desktop   // a normal window that stays on every Space; other apps can cover it
    case onTop     // floats above all windows

    var label: String { self == .desktop ? "On desktop" : "Always on top" }
    var symbol: String { self == .desktop ? "menubar.dock.rectangle" : "square.stack.3d.up.fill" }
}

enum NoteColor: String, Codable, CaseIterable {
    case yellow, pink, blue, green, purple, orange

    var nsColor: NSColor {
        switch self {
        case .yellow: return NSColor(srgbRed: 1.00, green: 0.95, blue: 0.62, alpha: 1)
        case .pink:   return NSColor(srgbRed: 1.00, green: 0.80, blue: 0.86, alpha: 1)
        case .blue:   return NSColor(srgbRed: 0.76, green: 0.89, blue: 1.00, alpha: 1)
        case .green:  return NSColor(srgbRed: 0.80, green: 0.95, blue: 0.78, alpha: 1)
        case .purple: return NSColor(srgbRed: 0.88, green: 0.82, blue: 1.00, alpha: 1)
        case .orange: return NSColor(srgbRed: 1.00, green: 0.86, blue: 0.70, alpha: 1)
        }
    }
    var color: Color { Color(nsColor: nsColor) }
}

struct Rect: Codable, Equatable {
    var x, y, w, h: Double
    init(_ r: NSRect) { x = r.origin.x; y = r.origin.y; w = r.size.width; h = r.size.height }
    var nsRect: NSRect { NSRect(x: x, y: y, width: w, height: h) }
}

enum NoteKind: String, Codable {
    case text, checklist
}

struct Note: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String = ""
    var kind: NoteKind = .text
    var body: String = ""
    var items: [TodoItem] = []
    var images: [String] = []      // file names in ImageStore.dir
    var color: NoteColor = .yellow
    var createdAt = Date()
    var updatedAt = Date()
    var archived = false
    var pinned = false
    var mode: PinMode = .desktop
    var frame: Rect?

    init() {}

    // Tolerant decoding so notes saved by older versions still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        items = try c.decodeIfPresent([TodoItem].self, forKey: .items) ?? []
        kind = try c.decodeIfPresent(NoteKind.self, forKey: .kind) ?? (c.contains(.body) ? .text : .checklist)
        body = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
        images = try c.decodeIfPresent([String].self, forKey: .images) ?? []
        color = try c.decodeIfPresent(NoteColor.self, forKey: .color) ?? .yellow
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        archived = try c.decodeIfPresent(Bool.self, forKey: .archived) ?? false
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        mode = try c.decodeIfPresent(PinMode.self, forKey: .mode) ?? .desktop
        frame = try c.decodeIfPresent(Rect.self, forKey: .frame)
    }

    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        if kind == .text, let line = body.split(whereSeparator: \.isNewline).first { return String(line) }
        if let first = items.first(where: { !$0.text.isEmpty }) { return first.text }
        return "Untitled sticky"
    }
    var doneCount: Int { items.filter(\.done).count }
    var nonEmptyItems: [TodoItem] { items.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty } }
}
