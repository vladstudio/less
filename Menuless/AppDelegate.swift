import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    private var toggleItem: NSStatusItem!
    private var expanderItem: NSStatusItem!
    private var dragTimer: Timer?
    private let toggleKey = "NSStatusItem Preferred Position MenulessToggle"

    private var isExpanded: Bool {
        get {
            if UserDefaults.standard.object(forKey: "isExpanded") == nil { return true }
            return UserDefaults.standard.bool(forKey: "isExpanded")
        }
        set { UserDefaults.standard.set(newValue, forKey: "isExpanded") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        try? task.run()
        NSApp.terminate(nil)
    }

    // MARK: - Setup

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Menuless", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Menuless", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }

    private func setupStatusItems() {
        // Toggle button (always visible)
        toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        toggleItem.autosaveName = "MenulessToggle"
        if let button = toggleItem.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Snap expander position to toggle before creating it
        let expanderKey = "NSStatusItem Preferred Position MenulessExpander"
        if let togglePos = UserDefaults.standard.object(forKey: toggleKey) as? Double {
            UserDefaults.standard.set(togglePos + 1, forKey: expanderKey)
        }

        // Expander (to the left of toggle — hides items when wide)
        expanderItem = NSStatusBar.system.statusItem(withLength: 0)
        expanderItem.autosaveName = "MenulessExpander"
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

        let title = NSMenuItem(title: "Menuless", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        let login = NSMenuItem(title: "Start on Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        toggleItem.menu = menu
        toggleItem.button?.performClick(nil)
        toggleItem.menu = nil
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("Login item error: \(error)")
        }
    }
}
