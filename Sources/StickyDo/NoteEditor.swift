import SwiftUI

/// The sticky itself — plain text or a checklist, plus pasted images.
/// Used both in pinned desktop windows and in the menu bar popover.
struct NoteEditor: View {
    @EnvironmentObject var store: NoteStore
    let id: UUID
    var inWindow: Bool
    var onBack: (() -> Void)? = nil

    @FocusState private var focused: UUID?
    @State private var hovered: UUID?
    @State private var copied = false
    @State private var dropTargeted = false

    var body: some View {
        if let note = store.note(id) {
            VStack(alignment: .leading, spacing: 6) {
                toolbar(note)
                TextField("Title", text: store.titleBinding(id))
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .semibold))
                Divider().opacity(0.4)

                if note.kind == .text {
                    TextEditor(text: store.bodyBinding(id))
                        .font(.system(size: 13))
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(maxHeight: .infinity)
                } else {
                    checklist(note).frame(maxHeight: .infinity)
                }

                if !note.images.isEmpty { imageStrip(note) }
                footer(note)
            }
            .padding(.horizontal, 12)
            .padding(.top, inWindow ? 6 : 10)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(note.color.color)
            .overlay(dropTargeted ? RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.35), lineWidth: 2).padding(3) : nil)
            .onDrop(of: [.image, .fileURL], isTargeted: $dropTargeted) { PasteRouter.handleDrop($0, into: id) }
            .environment(\.colorScheme, .light)
            .foregroundStyle(Color.black.opacity(0.85))
            .onAppear { if !inWindow { PasteRouter.popoverNote = id } }
            .onDisappear { if !inWindow, PasteRouter.popoverNote == id { PasteRouter.popoverNote = nil } }
        } else {
            Text("This sticky was deleted.").padding()
        }
    }

    // MARK: Toolbar

    @ViewBuilder private func toolbar(_ note: Note) -> some View {
        HStack(spacing: 10) {
            if inWindow {
                Spacer().frame(width: 18) // room for the close button (close = unpin)
                // The window itself handles dragging in this strip (see NoteWindow.sendEvent).
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .allowsHitTesting(false)
            } else {
                if let onBack {
                    Button(action: onBack) { Image(systemName: "chevron.left") }
                        .help("Back to all stickies")
                }
                Spacer()
            }

            Button { store.toggleKind(id) } label: {
                Image(systemName: note.kind == .text ? "checklist" : "text.alignleft")
            }
            .help(note.kind == .text ? "Turn into checklist" : "Turn into plain text")

            Button {
                MarkdownExport.copy(note)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
            } label: { Image(systemName: copied ? "checkmark" : "doc.on.doc") }
                .help("Copy as Markdown")

            Menu {
                ForEach(NoteColor.allCases, id: \.self) { c in
                    Button(c.rawValue.capitalized) { store.update(id) { $0.color = c } }
                }
                Divider()
                Button(note.mode == .desktop ? "Keep on top of other windows" : "Let other windows cover it") {
                    store.update(id, touch: false) { $0.mode = $0.mode == .desktop ? .onTop : .desktop }
                }
            } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .help("Color & window options")

            if !inWindow {
                Button {
                    store.update(id, touch: false) { $0.pinned.toggle() }
                } label: { Image(systemName: note.pinned ? "pin.fill" : "pin") }
                    .help(note.pinned ? "Unpin from desktop" : "Pin to desktop")
            }

            Button {
                store.setArchived(id, !note.archived)
                if !inWindow { onBack?() }
            } label: { Image(systemName: note.archived ? "tray.and.arrow.up" : "archivebox") }
                .help(note.archived ? "Restore" : "Archive (keeps it in history)")
        }
        .buttonStyle(.plain)
        .font(.system(size: 13))
        .foregroundStyle(Color.black.opacity(0.6))
        .frame(height: inWindow ? 26 : 20)
    }

    // MARK: Checklist

    private func checklist(_ note: Note) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(note.items) { item in row(item) }
                Button { addItem(after: nil) } label: {
                    Label("Add item", systemImage: "plus").font(.system(size: 12))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary).padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func row(_ item: TodoItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Button { toggle(item.id) } label: {
                Image(systemName: item.done ? "checkmark.square.fill" : "square")
                    .font(.system(size: 14))
                    .foregroundStyle(item.done ? Color.black.opacity(0.45) : Color.black.opacity(0.7))
            }
            .buttonStyle(.plain)

            TextField("To do…", text: store.itemTextBinding(id, item.id), axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .strikethrough(item.done)
                .opacity(item.done ? 0.5 : 1)
                .focused($focused, equals: item.id)
                .onSubmit { addItem(after: item.id) }
                .onKeyPress(.delete) {
                    // Backspace on an empty item removes it
                    guard store.note(id)?.items.first(where: { $0.id == item.id })?.text.isEmpty == true else { return .ignored }
                    removeItem(item.id, focusPrevious: true)
                    return .handled
                }

            if hovered == item.id {
                Button { removeItem(item.id, focusPrevious: false) } label: {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }
        .onHover { hovered = $0 ? item.id : (hovered == item.id ? nil : hovered) }
    }

    // MARK: Images

    private func imageStrip(_ note: Note) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(note.images, id: \.self) { name in ImageThumb(noteID: id, name: name) }
            }
        }
        .frame(height: 72)
    }

    // MARK: Footer

    @ViewBuilder private func footer(_ note: Note) -> some View {
        HStack {
            if note.kind == .checklist, !note.nonEmptyItems.isEmpty {
                let total = note.nonEmptyItems.count
                let done = note.nonEmptyItems.filter(\.done).count
                Text("\(done) of \(total) done")
                ProgressView(value: Double(done), total: Double(total))
                    .progressViewStyle(.linear).frame(width: 50).tint(.black.opacity(0.5))
            } else if note.images.isEmpty {
                Text("⌘V or drop to add images")
            }
            Spacer()
            if note.kind == .checklist, note.doneCount > 0 {
                Button("Clear done") { store.update(id) { $0.items.removeAll(where: \.done) } }
                    .buttonStyle(.plain)
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(Color.black.opacity(0.45))
    }

    // MARK: Actions

    private func toggle(_ itemID: UUID) {
        store.update(id) { n in
            if let i = n.items.firstIndex(where: { $0.id == itemID }) { n.items[i].done.toggle() }
        }
    }

    private func addItem(after itemID: UUID?) {
        let new = TodoItem()
        store.update(id) { n in
            if let itemID, let i = n.items.firstIndex(where: { $0.id == itemID }) {
                n.items.insert(new, at: i + 1)
            } else {
                n.items.append(new)
            }
        }
        DispatchQueue.main.async { focused = new.id }
    }

    private func removeItem(_ itemID: UUID, focusPrevious: Bool) {
        var prev: UUID?
        store.update(id) { n in
            guard let i = n.items.firstIndex(where: { $0.id == itemID }) else { return }
            if i > 0 { prev = n.items[i - 1].id }
            n.items.remove(at: i)
        }
        if focusPrevious, let prev { DispatchQueue.main.async { focused = prev } }
    }
}

/// A thumbnail: click to open full size in Preview, hover to remove.
struct ImageThumb: View {
    @EnvironmentObject var store: NoteStore
    let noteID: UUID
    let name: String
    @State private var hover = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let img = ImageStore.load(name) {
                Image(nsImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .onTapGesture { NSWorkspace.shared.open(ImageStore.url(name)) }
                    .help("Click to open")
            } else {
                RoundedRectangle(cornerRadius: 5).fill(.black.opacity(0.1)).frame(width: 72, height: 72)
            }
            if hover {
                Button { store.removeImage(noteID, name) } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 14))
                        .foregroundStyle(.white, .black.opacity(0.6))
                }
                .buttonStyle(.plain).padding(3)
            }
        }
        .onHover { hover = $0 }
    }
}
