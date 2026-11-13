import SwiftUI
import AppKit

@MainActor
final class NoteStore: ObservableObject {
    static let shared = NoteStore()

    @Published private(set) var notes: [Note] = []
    private var saveWork: DispatchWorkItem?

    let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StickyDo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("notes.json")
    }()

    private init() { load() }

    // MARK: Queries
    func note(_ id: UUID) -> Note? { notes.first { $0.id == id } }

    var active: [Note] { notes.filter { !$0.archived }.sorted { $0.updatedAt > $1.updatedAt } }
    var archive: [Note] { notes.filter { $0.archived }.sorted { $0.updatedAt > $1.updatedAt } }

    // MARK: Mutations
    func update(_ id: UUID, touch: Bool = true, _ change: (inout Note) -> Void) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        var n = notes[i]
        change(&n)
        if touch { n.updatedAt = Date() }
        guard n != notes[i] else { return }
        notes[i] = n
        scheduleSave()
    }

    @discardableResult
    func create(kind: NoteKind = .text, pinned: Bool = false) -> UUID {
        let colors = NoteColor.allCases
        let last = active.first?.color
        var note = Note()
        note.kind = kind
        if kind == .checklist { note.items = [TodoItem()] }
        note.color = .yellow
        if let last, let idx = colors.firstIndex(of: last) { note.color = colors[(idx + 1) % colors.count] }
        note.pinned = pinned
        notes.append(note)
        scheduleSave()
        return note.id
    }

    func setArchived(_ id: UUID, _ archived: Bool) {
        update(id) { $0.archived = archived; if archived { $0.pinned = false } }
    }

    /// Switch between a plain-text note and a checklist, carrying the content across.
    func toggleKind(_ id: UUID) {
        update(id) { n in
            if n.kind == .text {
                if n.items.allSatisfy({ $0.text.isEmpty }) {
                    n.items = n.body.split(whereSeparator: \.isNewline)
                        .map { TodoItem(text: String($0).trimmingCharacters(in: .whitespaces)) }
                        .filter { !$0.text.isEmpty }
                    if n.items.isEmpty { n.items = [TodoItem()] }
                }
                n.kind = .checklist
            } else {
                if n.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    n.body = n.items.map(\.text).filter { !$0.isEmpty }.joined(separator: "\n")
                }
                n.kind = .text
            }
        }
    }

    func addImage(_ id: UUID, _ image: NSImage) {
        guard note(id) != nil, let name = ImageStore.save(image) else { return }
        update(id) { $0.images.append(name) }
    }

    func removeImage(_ id: UUID, _ name: String) {
        update(id) { $0.images.removeAll { $0 == name } }
        ImageStore.delete(name)
    }

    func bodyBinding(_ id: UUID) -> Binding<String> {
        Binding(get: { self.note(id)?.body ?? "" },
                set: { v in self.update(id) { $0.body = v } })
    }

    func delete(_ id: UUID) {
        note(id)?.images.forEach(ImageStore.delete)
        notes.removeAll { $0.id == id }
        scheduleSave()
    }

    func duplicate(_ id: UUID) -> UUID? {
        guard var copy = note(id) else { return nil }
        copy.id = UUID(); copy.archived = false; copy.pinned = false; copy.frame = nil
        copy.createdAt = Date(); copy.updatedAt = Date()
        copy.items = copy.items.map { TodoItem(text: $0.text, done: false) }
        copy.images = copy.images.compactMap { ImageStore.load($0).flatMap(ImageStore.save) }
        notes.append(copy)
        scheduleSave()
        return copy.id
    }

    // MARK: Bindings
    func titleBinding(_ id: UUID) -> Binding<String> {
        Binding(get: { self.note(id)?.title ?? "" },
                set: { v in self.update(id) { $0.title = v } })
    }

    func itemTextBinding(_ id: UUID, _ itemID: UUID) -> Binding<String> {
        Binding(get: { self.note(id)?.items.first { $0.id == itemID }?.text ?? "" },
                set: { v in self.update(id) { n in
                    if let i = n.items.firstIndex(where: { $0.id == itemID }) { n.items[i].text = v }
                } })
    }

    // MARK: Persistence
    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        do { notes = try dec.decode([Note].self, from: data) }
        catch {
            // Keep the unreadable file instead of overwriting it.
            let backup = fileURL.deletingPathExtension().appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: fileURL, to: backup)
            NSLog("StickyDo: failed to load notes: \(error)")
        }
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in Task { @MainActor in self?.saveNow() } }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func saveNow() {
        saveWork?.cancel(); saveWork = nil
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        do { try enc.encode(notes).write(to: fileURL, options: .atomic) }
        catch { NSLog("StickyDo: failed to save notes: \(error)") }
    }
}
