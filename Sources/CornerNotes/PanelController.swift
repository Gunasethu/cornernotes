import AppKit
import SwiftUI

final class PanelController: NSResponder {
    static let shared = PanelController()

    var handleWindow: NSWindow!
    var panelWindow: FloatingPanel!
    private var handleView: HandleView!
    private let handleWidth: CGFloat = 16
    private let handleHeight: CGFloat = 60

    private var isExpanded = false
    private var isEditing = false
    private var pendingCollapse = false
    private var mouseOverHandle = false
    private var mouseOverPanel = false

    private var collapseTimer: Timer?
    private var editingTimer: Timer?

    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private var localKeyMonitor: Any?
    private var hotkeyMonitor: Any?

    private override init() {
        super.init()
        handleView = HandleView(frame: NSRect(x: 0, y: 0, width: handleWidth, height: handleHeight))
        handleView.toolTip = "CornerNotes — click or hover (⌃⌥N)"
        handleWindow = NSWindow(contentRect: handleView.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        handleWindow.isOpaque = false
        handleWindow.backgroundColor = .clear
        handleWindow.level = .floating
        handleWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        handleWindow.hasShadow = false
        handleWindow.contentView = handleView
        handleWindow.ignoresMouseEvents = false

        panelWindow = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 520))
        panelWindow.alphaValue = 0

        let hosting = NSHostingView(rootView: ContentView())
        hosting.frame = panelWindow.contentView!.bounds
        hosting.autoresizingMask = [.width, .height]
        panelWindow.contentView?.addSubview(hosting)

        // Hover tracking on panel via a tracking area owned by self (NSResponder)
        let panelTracking = NSTrackingArea(rect: panelWindow.contentView!.bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: ["area": "panel"])
        panelWindow.contentView?.addTrackingArea(panelTracking)

        handleView.onHover = { [weak self] hovering in
            guard let self = self else { return }
            if hovering {
                self.mouseOverHandle = true
                self.cancelCollapse()
                self.expand()
            } else {
                self.mouseOverHandle = false
                self.scheduleCollapse()
            }
        }
        handleView.onClick = { [weak self] in self?.expand() }

        reposition()
        panelWindow.orderOut(nil)
        handleWindow.orderFrontRegardless()

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self else { return }
            if Store.shared.state.pinned { return }
            let loc = NSEvent.mouseLocation
            if self.panelWindow.frame.contains(loc) {
                self.setEditing(true)
                self.resetEditingTimer()
            } else if self.handleWindow.frame.contains(loc) {
                self.expand()
            } else {
                self.collapse()
            }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return event }
            if Store.shared.state.pinned { return event }
            let loc = NSEvent.mouseLocation
            if self.panelWindow.frame.contains(loc) {
                self.setEditing(true)
                self.resetEditingTimer()
            } else if !self.handleWindow.frame.contains(loc) {
                self.collapse()
            }
            return event
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if event.keyCode == 53 { self.collapse(); return nil }
            if self.panelWindow.isKeyWindow {
                self.setEditing(true)
                self.resetEditingTimer()
            }
            return event
        }
        hotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if mods == [.control, .option], event.keyCode == 45 {
                if self?.isExpanded == true { self?.collapse() } else { self?.expand() }
            }
        }

        NotificationCenter.default.addObserver(self, selector: #selector(cornerChanged), name: .cornerChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(pinChanged), name: .pinChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        if Store.shared.state.pinned {
            DispatchQueue.main.async { [weak self] in self?.expand() }
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - NSResponder hover on panel
    override func mouseEntered(with event: NSEvent) {
        mouseOverPanel = true
        cancelCollapse()
    }
    override func mouseExited(with event: NSEvent) {
        mouseOverPanel = false
        scheduleCollapse()
    }

    @objc private func cornerChanged() { reposition() }
    @objc private func pinChanged() {
        if Store.shared.state.pinned {
            cancelCollapse()
            expand()
        } else if !mouseOverHandle && !mouseOverPanel {
            scheduleCollapse()
        }
    }
    @objc private func screenChanged() { reposition() }

    func expand() {
        guard !isExpanded else { return }
        isExpanded = true
        reposition(expanded: true)
        panelWindow.alphaValue = 0
        // slide in from left
        var startFrame = panelWindow.frame
        startFrame.origin.x -= panelWindow.frame.width * 0.15
        panelWindow.setFrame(startFrame, display: false)
        panelWindow.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        panelWindow.makeKeyAndOrderFront(nil)
        if let tv = BlockTextView.current {
            panelWindow.makeFirstResponder(tv)
        }
        handleWindow.alphaValue = 0  // hide handle while expanded
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.panelWindow.animator().alphaValue = 1
            self.reposition(expanded: true)
        }, completionHandler: nil)
    }

    func collapse() {
        guard !Store.shared.state.pinned else { return }
        guard isExpanded else { return }
        isExpanded = false
        isEditing = false
        pendingCollapse = false
        cancelCollapse()
        cancelEditingTimer()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.panelWindow.animator().alphaValue = 0
            var f = self.panelWindow.frame
            f.origin.x -= self.panelWindow.frame.width * 0.1
            self.panelWindow.animator().setFrameOrigin(f.origin)
        }, completionHandler: { [weak self] in
            self?.panelWindow.orderOut(nil)
            self?.handleWindow.alphaValue = 1
            self?.reposition(expanded: false)
        })
    }

    func setEditing(_ value: Bool) {
        isEditing = value
        if !value && pendingCollapse {
            pendingCollapse = false
            performCollapseIfPossible()
        }
    }

    private func resetEditingTimer() {
        editingTimer?.invalidate()
        editingTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            self?.setEditing(false)
        }
    }

    private func cancelEditingTimer() {
        editingTimer?.invalidate()
        editingTimer = nil
    }

    private func scheduleCollapse() {
        cancelCollapse()
        if isEditing {
            pendingCollapse = true
            return
        }
        collapseTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            self?.performCollapseIfPossible()
        }
    }

    private func cancelCollapse() {
        collapseTimer?.invalidate()
        collapseTimer = nil
    }

    private func performCollapseIfPossible() {
        if Store.shared.state.pinned { return }
        if mouseOverHandle || mouseOverPanel { return }
        if isEditing {
            pendingCollapse = true
            return
        }
        collapse()
    }

    func reposition(expanded: Bool? = nil) {
        let exp = expanded ?? isExpanded
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        let margin: CGFloat = 12
        let panelSize = NSSize(width: 360, height: 520)

        // Handle: left edge, vertical center
        let hx: CGFloat = vf.minX
        let hy: CGFloat = vf.midY - handleHeight / 2
        handleWindow.setFrame(NSRect(x: hx, y: hy, width: handleWidth, height: handleHeight), display: true)

        if exp {
            let px: CGFloat = vf.minX + margin
            var py: CGFloat = hy - (panelSize.height / 2) + (handleHeight / 2)
            py = max(vf.minY + margin, min(vf.maxY - panelSize.height - margin, py))
            panelWindow.setFrame(NSRect(x: px, y: py, width: panelSize.width, height: panelSize.height), display: true)
        }
    }
}
