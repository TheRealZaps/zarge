import AppKit

/// Zarge has no menu bar icon and no login item. The helper does the work as a launchd
/// daemon; this app only shows a glass panel to install it and set the threshold, and quits
/// when the panel closes.
let app = NSApplication.shared
let appDelegate = AppDelegate()
app.delegate = appDelegate
app.setActivationPolicy(.regular)
app.run()
