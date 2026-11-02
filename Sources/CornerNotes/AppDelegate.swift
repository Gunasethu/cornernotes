import AppKit

final class AppController: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var menu: NSMenu?

    @objc func showPanel() { PanelController.shared.expand() }
    @objc func openSettings() { PanelController.shared.expand() }
    @objc func quit() { NSApp.terminate(nil) }
}