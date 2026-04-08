import Cocoa
import MacAppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var toggleItem: NSStatusItem!
    private var expanderItem: NSStatusItem!
    private var dragTimer: Timer?
    private let toggleKey = "NSStatusItem Preferred Position LessToggle"

    private var isExpanded: Bool {
        get { UserDefaults.standard.bool(forKey: "isExpanded") }
        set { UserDefaults.standard.set(newValue, forKey: "isExpanded") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["isExpanded": true])
        setupMainMenu()
        setupStatusItems()
        applyState(activate: false)

        // Watch for Cmd+drag repositioning
        UserDefaults.standard.addObserver(self, forKeyPath: toggleKey, options: .new, context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == toggleKey else { return }
        // Debounce — restart after drag ends
        dragTimer?.invalidate()
        dragTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            self.relaunch()
        }
    }

    private func relaunch() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = [Bundle.main.bundleURL.path]
        do {
            try task.run()
            NSApp.terminate(nil)
        } catch {
            print("Relaunch failed: \(error)")
        }
    }

    deinit {
        UserDefaults.standard.removeObserver(self, forKeyPath: toggleKey)
    }

    // MARK: - Setup

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        let aboutItem = NSMenuItem(title: "About Less", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        appMenu.addItem(aboutItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Less", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }

    private func setupStatusItems() {
        // Toggle button (always visible)
        toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        toggleItem.autosaveName = "LessToggle"
        if let button = toggleItem.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Snap expander position to toggle before creating it
        let expanderKey = "NSStatusItem Preferred Position LessExpander"
        if let togglePos = UserDefaults.standard.object(forKey: toggleKey) as? Double {
            UserDefaults.standard.set(togglePos + 1, forKey: expanderKey)
        }

        // Expander (to the left of toggle — hides items when wide)
        expanderItem = NSStatusBar.system.statusItem(withLength: 0)
        expanderItem.autosaveName = "LessExpander"
    }

    // MARK: - Toggle

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            isExpanded.toggle()
            applyState(activate: isExpanded)
        }
    }

    private func applyState(activate: Bool) {
        expanderItem.length = isExpanded ? 0 : 10000
        let name = isExpanded ? "chevron.left" : "chevron.right"
        let desc = isExpanded ? "Hide menu bar items" : "Show menu bar items"
        toggleItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: desc)
        if activate {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Context Menu

    private func showContextMenu() {
        let menu = NSMenu()

        let title = NSMenuItem(title: "Less", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        let login = NSMenuItem(title: "Start on Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        toggleItem.menu = menu
        toggleItem.button?.performClick(nil)
        toggleItem.menu = nil
    }

    @objc private func openAbout() {
        NSWorkspace.shared.open(URL(string: "https://apps.vlad.studio/less")!)
    }

    @objc private func toggleLogin() {
        LoginItem.toggle()
    }
}
