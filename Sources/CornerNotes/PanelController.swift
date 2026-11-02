import AppKit
import SwiftUI

final class PanelController {
    static let shared = PanelController()

    let handleWindow: NSWindow
    let panelWindow: FloatingPanel
    private let handleView: HandleView
    private var hoverTimer: Timer?
    private var isExpanded = false
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private var localKeyMonitor: Any?
    private var hotkeyMonitor: Any?

    private init() {
        handleView = HandleView(frame: NSRect(x: 0, y: 0, width: 44, height: 44))
        handleView.toolTip = "CornerNotes — click or hover to open (⌃⌥N)"
        handleWindow = NSWindow(contentRect: handleView.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        handleWindow.isOpaque = false
        handleWindow.backgroundColor = .clear
        handleWindow.level = .floating
        handleWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        handleWindow.hasShadow = true
        handleWindow.contentView = handleView
        handleWindow.ignoresMouseEvents = false

        panelWindow = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 520))

        // Host SwiftUI
        let hosting = NSHostingView(rootView: ContentView())
        hosting.frame = panelWindow.contentView!.bounds
        hosting.autoresizingMask = [.width, .height]
        panelWindow.contentView?.addSubview(hosting)

        handleView.onHover = { [weak self] hovering in
            if hovering { self?.expand() }
        }
        handleView.onClick = { [weak self] in self?.expand() }
        handleWindow.title = "CornerNotes"
        handleWindow.standardWindowButton(.closeButton)?.isHidden = true

        // No tracking area on panel; it stays expanded until click-outside.
        reposition()
        panelWindow.orderOut(nil)
        handleWindow.orderFrontRegardless()

        // Global click monitor to collapse (other apps)
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.isExpanded else { return }
            let loc = NSEvent.mouseLocation
            if !self.panelWindow.frame.contains(loc) && !self.handleWindow.frame.contains(loc) {
                self.collapse()
            }
        }
        // Local click monitor to collapse (same app)
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isExpanded else { return event }
            let loc = NSEvent.mouseLocation
            if !self.panelWindow.frame.contains(loc) && !self.handleWindow.frame.contains(loc) {
                self.collapse()
            }
            return event
        }

        // Escape to collapse
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.collapse(); return nil }
            return event
        }

        // Global hotkey: Ctrl+Option+N to toggle panel
        hotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if mods == [.control, .option], event.keyCode == 45 {
                if self?.isExpanded == true { self?.collapse() } else { self?.expand() }
            }
        }

        NotificationCenter.default.addObserver(self, selector: #selector(cornerChanged), name: .cornerChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    @objc private func cornerChanged() { reposition() }
    @objc private func screenChanged() { reposition() }

    func expand() {
        guard !isExpanded else { return }
        isExpanded = true
        reposition(expanded: true)
        panelWindow.orderFrontRegardless()
        panelWindow.makeKeyAndOrderFront(nil)
    }

    func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        panelWindow.orderOut(nil)
        reposition(expanded: false)
    }

    func reposition(expanded: Bool? = nil) {
        let exp = expanded ?? isExpanded
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        let margin: CGFloat = 12
        let corner = Store.shared.state.corner
        let handleSize: CGFloat = 44
        let panelSize = panelWindow.frame.size

        // Handle position
        var hx: CGFloat, hy: CGFloat
        switch corner {
        case .bottomRight: hx = vf.maxX - handleSize - margin; hy = vf.minY + margin
        case .bottomLeft:  hx = vf.minX + margin; hy = vf.minY + margin
        case .topRight:    hx = vf.maxX - handleSize - margin; hy = vf.maxY - handleSize - margin
        case .topLeft:     hx = vf.minX + margin; hy = vf.maxY - handleSize - margin
        }
        handleWindow.setFrame(NSRect(x: hx, y: hy, width: handleSize, height: handleSize), display: true)

        // Panel position (grows from corner)
        if exp {
            var px: CGFloat, py: CGFloat
            switch corner {
            case .bottomRight: px = vf.maxX - panelSize.width - margin; py = vf.minY + margin
            case .bottomLeft:  px = vf.minX + margin; py = vf.minY + margin
            case .topRight:    px = vf.maxX - panelSize.width - margin; py = vf.maxY - panelSize.height - margin
            case .topLeft:     px = vf.minX + margin; py = vf.maxY - panelSize.height - margin
            }
            panelWindow.setFrame(NSRect(x: px, y: py, width: panelSize.width, height: panelSize.height), display: true)
        }
    }
}