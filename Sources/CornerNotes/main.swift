import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let controller = AppController()

// Status bar
let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
statusItem.button?.title = "CN"
let menu = NSMenu()
let showItem = NSMenuItem(title: "Show Panel", action: #selector(AppController.showPanel), keyEquivalent: "")
showItem.target = controller
menu.addItem(showItem)
let settingsItem = NSMenuItem(title: "Settings", action: #selector(AppController.openSettings), keyEquivalent: ",")
settingsItem.target = controller
menu.addItem(settingsItem)
menu.addItem(.separator())
let quitItem = NSMenuItem(title: "Quit CornerNotes", action: #selector(AppController.quit), keyEquivalent: "q")
quitItem.target = controller
menu.addItem(quitItem)
statusItem.menu = menu

app.delegate = controller

_ = PanelController.shared

app.run()