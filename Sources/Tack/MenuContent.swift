import SwiftUI
import ServiceManagement

/// The popover shown from the menu bar icon: all stickies, search, history (archive).
struct MenuContent: View {
    @EnvironmentObject var store: NoteStore
    @State private var selected: UUID?
    @State private var showArchive = false
    @State private var query = ""
    @State private var launchAtLogin = false
    @State private var loginNeedsApproval = false

    var body: some View {
        Group {
            if let selected, store.note(selected) != nil {
                NoteEditor(id: selected, inWindow: false) { self.selected = nil }
            } else {
                list
            }
        }
        .frame(width: 340, height: 480)
    }

    private var filtered: [Note] {
        let base = showArchive ? store.archive : store.active
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter { n in
            n.title.lowercased().contains(q) || n.body.lowercased().contains(q) || n.items.contains { $0.text.lowercased().contains(q) }
        }
    }

    private var list: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("", selection: $showArchive) {
                    Text("Stickies (\(store.active.count))").tag(false)
                    Text("History (\(store.archive.count))").tag(true)
                }
                .pickerStyle(.segmented).labelsHidden()
                Button { selected = store.create(kind: .text) } label: { Image(systemName: "square.and.pencil") }
                    .buttonStyle(.borderless).help("New text sticky")
                Button { selected = store.create(kind: .checklist) } label: { Image(systemName: "checklist") }
                    .buttonStyle(.borderless).help("New checklist")
                Button { _ = store.create(kind: .text, pinned: true) } label: { Image(systemName: "pin") }
                    .buttonStyle(.borderless).help("New sticky pinned to desktop")
            }
            TextField("Search", text: $query).textFieldStyle(.roundedBorder)

            if filtered.isEmpty {
                Spacer()
                Text(showArchive ? "Archived stickies show up here." : "No stickies yet.\nClick ✎ to create one.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filtered) { note in card(note) }
                    }
                }
            }

            Divider()
            HStack {
                Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
                    .toggleStyle(.checkbox).font(.caption)
                if loginNeedsApproval {
                    Button("Approve…") { SMAppService.openSystemSettingsLoginItems() }
                        .buttonStyle(.link).font(.caption)
                        .help("macOS needs you to allow Tack in System Settings → Login Items")
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.buttonStyle(.borderless).font(.caption)
            }
        }
        .padding(12)
        .onAppear(perform: refreshLoginStatus)
    }

    private func refreshLoginStatus() {
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled || status == .requiresApproval
        loginNeedsApproval = status == .requiresApproval
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Tack: launch at login \(on ? "register" : "unregister") failed: \(error)")
        }
        refreshLoginStatus()
        if loginNeedsApproval { SMAppService.openSystemSettingsLoginItems() }
    }

    private func card(_ note: Note) -> some View {
        let items = note.nonEmptyItems
        let open = items.filter { !$0.done }
        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(note.displayTitle).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Spacer()
                    if note.kind == .checklist, !items.isEmpty {
                        Text("\(items.count - open.count)/\(items.count)")
                            .font(.caption2.monospacedDigit()).foregroundStyle(.black.opacity(0.5))
                    }
                }
                if note.kind == .text {
                    let preview = note.body.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !preview.isEmpty {
                        Text(preview).font(.caption).lineLimit(3).foregroundStyle(.black.opacity(0.7))
                    }
                } else {
                    ForEach(open.prefix(3)) { item in
                        Text("☐ \(item.text)").font(.caption).lineLimit(1).foregroundStyle(.black.opacity(0.7))
                    }
                    if open.isEmpty && !items.isEmpty {
                        Text("All done ✓").font(.caption).foregroundStyle(.black.opacity(0.5))
                    }
                }
                if !note.images.isEmpty {
                    Label("\(note.images.count)", systemImage: "photo").font(.caption2).foregroundStyle(.black.opacity(0.5))
                }
                Text(note.updatedAt, format: .relative(presentation: .named))
                    .font(.caption2).foregroundStyle(.black.opacity(0.4))
            }
            VStack(spacing: 8) {
                if showArchive {
                    Button { store.setArchived(note.id, false) } label: { Image(systemName: "tray.and.arrow.up") }
                        .help("Restore")
                    Button { store.delete(note.id) } label: { Image(systemName: "trash") }
                        .help("Delete forever")
                } else {
                    Button { store.update(note.id, touch: false) { $0.pinned.toggle() } } label: {
                        Image(systemName: note.pinned ? "pin.fill" : "pin")
                    }
                    .help(note.pinned ? "Unpin from desktop" : "Pin to desktop")
                    Button { store.setArchived(note.id, true) } label: { Image(systemName: "archivebox") }
                        .help("Archive")
                }
            }
            .buttonStyle(.plain).foregroundStyle(.black.opacity(0.55))
        }
        .padding(10)
        .background(note.color.color, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture {
            if note.pinned { PinManager.shared.focus(note.id) }
            selected = note.id
        }
        .contextMenu {
            Button("Copy as Markdown") { MarkdownExport.copy(note) }
            Button("Duplicate") { if let id = store.duplicate(note.id) { selected = id } }
            Button("Delete forever", role: .destructive) { store.delete(note.id) }
        }
        .environment(\.colorScheme, .light)
    }
}
