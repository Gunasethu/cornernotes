import SwiftUI

struct UnifiedView: View {
    @ObservedObject var store = Store.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CornerNotes").font(.title3.bold())
                Spacer()
                Button {
                    store.state.pinned.toggle()
                    store.scheduleSave()
                    NotificationCenter.default.post(name: .pinChanged, object: nil)
                } label: {
                    Image(systemName: store.state.pinned ? "pin.fill" : "pin")
                }
                .buttonStyle(.plain)
                .help(store.state.pinned ? "Unpin panel" : "Pin panel")
            }
            EditorView(store: store)
                .frame(minHeight: 200, maxHeight: 420)
        }
        .padding(12)
        .frame(width: 340)
    }
}

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
    static let pinChanged = Notification.Name("pinChanged")
    static let collapsePanel = Notification.Name("collapsePanel")
}

struct ContentView: View {
    var body: some View {
        UnifiedView()
    }
}
