import SwiftUI

struct UnifiedView: View {
    @ObservedObject var store = Store.shared
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CornerNotes").font(.title3.bold())
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
            }

            Button {
                if let tv = BlockTextView.current {
                    let att = checkboxAttachment(done: false)
                    let a = NSMutableAttributedString(attachment: att)
                    a.addAttribute(NSAttributedString.Key("TaskDone"), value: false, range: NSRange(location: 0, length: 1))
                    a.append(NSAttributedString(string: " "))
                    tv.textStorage?.insert(a, at: tv.selectedRange().location)
                    tv.setSelectedRange(NSRange(location: tv.selectedRange().location + a.length, length: 0))
                    tv.window?.makeFirstResponder(tv)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle")
                    Text("Add task")
                }
                .font(.callout)
            }
            .buttonStyle(.plain)

            EditorView(store: store)
                .frame(minHeight: 200, maxHeight: 420)
        }
        .padding(12)
        .frame(width: 340)
        .sheet(isPresented: $showSettings) { SettingsView() }
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
    static let collapsePanel = Notification.Name("collapsePanel")
}

struct ContentView: View {
    var body: some View {
        UnifiedView()
    }
}