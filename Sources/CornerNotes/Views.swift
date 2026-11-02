import SwiftUI

struct UnifiedView: View {
    @ObservedObject var store = Store.shared
    @FocusState private var focusedID: UUID?
    @State private var rowHover: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("CornerNotes").font(.title3.bold())
                Spacer()
                Button { showSettings.toggle() } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
            }

            // Add task button
            Button {
                let b = Block(kind: .task, text: "", done: false)
                store.state.blocks.append(b)
                store.scheduleSave()
                focusedID = b.id
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle")
                    Text("Add task")
                }
                .font(.callout)
            }
            .buttonStyle(.plain)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach($store.state.blocks) { $block in
                        BlockRow(block: $block,
                                 focusedID: $focusedID,
                                 rowHover: $rowHover)
                    }

                    // Empty typing area
                    TextField("Click to type...", text: Binding(
                        get: { "" },
                        set: { newVal in
                            if !newVal.isEmpty {
                                let b = Block(kind: .paragraph, text: newVal, done: false)
                                store.state.blocks.append(b)
                                store.scheduleSave()
                                focusedID = b.id
                            }
                        }
                    ))
                    .textFieldStyle(.plain)
                    .padding(4)
                    .onSubmit {
                        // already handled via binding
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    // append empty paragraph if none focused
                    if focusedID == nil {
                        let b = Block(kind: .paragraph, text: "", done: false)
                        store.state.blocks.append(b)
                        store.scheduleSave()
                        focusedID = b.id
                    }
                }
            }
            .frame(maxHeight: 420)
        }
        .padding(12)
        .frame(width: 340)
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    @State private var showSettings = false
}

struct BlockRow: View {
    @Binding var block: Block
    @ObservedObject var store = Store.shared
    var focusedID: FocusState<UUID?>.Binding
    @Binding var rowHover: UUID?

    @State private var isHovered = false

    var body: some View {
        Group {
            if block.kind == .task {
                HStack(spacing: 8) {
                    Button {
                        block.done.toggle()
                        store.scheduleSave()
                    } label: {
                        Image(systemName: block.done ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(block.done ? .green : .secondary)
                    }
                    .buttonStyle(.plain)

                    TextField("Task", text: $block.text)
                        .textFieldStyle(.plain)
                        .strikethrough(block.done)
                        .foregroundStyle(block.done ? .secondary : .primary)
                        .focused(focusedID, equals: block.id)
                        .onChange(of: block.text) { _ in store.scheduleSave() }

                    if isHovered || focusedID.wrappedValue == block.id {
                        Button(role: .destructive) {
                            store.state.blocks.removeAll { $0.id == block.id }
                            store.scheduleSave()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)
                .onHover { h in isHovered = h }
            } else {
                HStack(alignment: .top, spacing: 6) {
                    if block.kind == .bullet {
                        Text("•").font(.body.bold())
                            .padding(.top, 2)
                    }
                    TextField(block.kind == .bullet ? "Bullet" : "Paragraph", text: $block.text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .focused(focusedID, equals: block.id)
                        .onChange(of: block.text) { newValue in
                            // convert "- " to bullet
                            if block.kind == .paragraph && newValue.hasPrefix("- ") {
                                block.kind = .bullet
                                block.text = String(newValue.dropFirst(2))
                            }
                            store.scheduleSave()
                        }
                }
                .padding(4)
                .onHover { h in isHovered = h }
            }
        }
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
    var body: some View {
        UnifiedView()
    }
}