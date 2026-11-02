import SwiftUI

// MARK: - Notes
struct NotesView: View {
    @ObservedObject var store = Store.shared
    @State private var newParagraph: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Notes").font(.headline)
                Spacer()
                Button {
                    store.state.notes.append(NoteBlock(kind: .paragraph, text: ""))
                    store.scheduleSave()
                } label: { Image(systemName: "doc.text") }
                .help("Add paragraph")
                Button {
                    store.state.notes.append(NoteBlock(kind: .bullet, text: ""))
                    store.scheduleSave()
                } label: { Image(systemName: "list.bullet") }
                .help("Add bullet")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach($store.state.notes) { $block in
                        NoteBlockRow(block: $block, onDelete: {
                            store.state.notes.removeAll { $0.id == block.id }
                            store.scheduleSave()
                        })
                    }
                }
            }
            .frame(maxHeight: 220)
        }
    }
}

struct NoteBlockRow: View {
    @Binding var block: NoteBlock
    var onDelete: () -> Void
    @ObservedObject var store = Store.shared

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            if block.kind == .bullet {
                Text("•").font(.body.bold())
                    .padding(.top, 2)
            }
            if block.kind == .paragraph {
                TextEditor(text: $block.text)
                    .font(.body)
                    .frame(minHeight: 40, maxHeight: 120)
                    .scrollContentBackground(.hidden)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                    .onChange(of: block.text) { _ in store.scheduleSave() }
            } else {
                TextField("Bullet item", text: $block.text)
                    .textFieldStyle(.plain)
                    .padding(6)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                    .onChange(of: block.text) { _ in store.scheduleSave() }
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Todos
struct TodosView: View {
    @ObservedObject var store = Store.shared
    @State private var newText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("To-Do").font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach($store.state.todos) { $item in
                        TodoRow(item: $item)
                    }
                }
            }
            .frame(maxHeight: 180)

            HStack {
                TextField("New to-do", text: $newText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addTodo() }
                Button("Add") { addTodo() }
                    .disabled(newText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addTodo() {
        let t = newText.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        store.state.todos.append(TodoItem(text: t))
        newText = ""
        store.scheduleSave()
    }
}

struct TodoRow: View {
    @Binding var item: TodoItem
    @ObservedObject var store = Store.shared

    var body: some View {
        HStack(spacing: 8) {
            Button {
                item.done.toggle()
                store.scheduleSave()
            } label: {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.done ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Text(item.text)
                .strikethrough(item.done)
                .foregroundStyle(item.done ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(role: .destructive) {
                store.state.todos.removeAll { $0.id == item.id }
                store.scheduleSave()
            } label: {
                Image(systemName: "trash").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .background(Color.white.opacity(0.05))
        .cornerRadius(6)
    }
}

// MARK: - Settings
struct SettingsView: View {
    @ObservedObject var store = Store.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings").font(.title2.bold())
            Form {
                Picker("Corner", selection: $store.state.corner) {
                    ForEach(Corner.allCases) { c in
                        Text(c.displayName).tag(c)
                    }
                }
                .onChange(of: store.state.corner) { _ in
                    store.scheduleSave()
                    NotificationCenter.default.post(name: .cornerChanged, object: nil)
                }
                Toggle("Launch at login", isOn: $store.state.launchAtLogin)
                    .onChange(of: store.state.launchAtLogin) { v in
                        store.scheduleSave()
                        LaunchAtLogin.setEnabled(v)
                    }
            }
            Spacer()
            HStack {
                Spacer()
                Button("Done") { dismiss() }
            }
        }
        .padding()
        .frame(width: 320, height: 220)
    }
}

extension Notification.Name {
    static let cornerChanged = Notification.Name("cornerChanged")
    static let collapsePanel = Notification.Name("collapsePanel")
}

// MARK: - Content
struct ContentView: View {
    @ObservedObject var store = Store.shared
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CornerNotes").font(.title3.bold())
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
            }

            NotesView()
            Divider()
            TodosView()
        }
        .padding(12)
        .frame(width: 340)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}