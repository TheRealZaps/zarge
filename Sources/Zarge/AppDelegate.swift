import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
  private let model = AppModel()
  private lazy var panel = GlassPanel(rootView: PanelView(model: model))

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.mainMenu = makeMainMenu()
    panel.center()
    showPanel()
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    showPanel()
    return false
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

  func applicationDidBecomeActive(_ notification: Notification) {
    // Picks up an approval made in System Settings as soon as the user switches back.
    Task { await model.refresh() }
  }

  private func showPanel() {
    panel.makeKeyAndOrderFront(nil)
    NSApp.activate()
  }

  /// A borderless window has no close button, so Cmd+W and Cmd+Q come from this menu.
  private func makeMainMenu() -> NSMenu {
    let appMenu = NSMenu()
    appMenu.addItem(withTitle: "Quit Zarge", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

    let windowMenu = NSMenu(title: "Window")
    windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

    let mainMenu = NSMenu()
    for submenu in [appMenu, windowMenu] {
      let item = NSMenuItem()
      item.submenu = submenu
      mainMenu.addItem(item)
    }
    return mainMenu
  }
}
