import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// Main menu with Edit items so copy/paste/undo work
let mainMenu = NSMenu()
let editMenuItem = NSMenuItem()
let editMenu = NSMenu(title: "Edit")
editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
editMenu.addItem(.separator())
editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
editMenuItem.submenu = editMenu
mainMenu.addItem(editMenuItem)
app.mainMenu = mainMenu

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
DispatchQueue.main.asyncAfter(deadline: .now() + 2) { PanelController.shared.expand() }

app.run()