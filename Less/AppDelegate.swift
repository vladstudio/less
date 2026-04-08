import Cocoa
import MacAppKit

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var toggleItem: NSStatusItem!
    private var expanderItem: NSStatusItem!
    private var dragTimer: Timer?
    private var isRelaunching = false
    private let toggleKey = "NSStatusItem Preferred Position LessToggle"
    private let expanderKey = "NSStatusItem Preferred Position LessExpander"

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
        dragTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.relaunch()
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
            isRelaunching = false
            applyState(activate: false)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        dragTimer?.invalidate()
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

        snapExpanderPosition()

        // Expander (hides items when wide)
        expanderItem = NSStatusBar.system.statusItem(withLength: 0)
        expanderItem.autosaveName = "LessExpander"
    }

    // MARK: - Toggle

    @objc private func statusItemClicked() {
        guard !isRelaunching, let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            isExpanded.toggle()
            if isExpanded {
                isRelaunching = true
                relaunch()
            } else {
                applyState(activate: false)
            }
        }
    }

    private func snapExpanderPosition() {
        if let togglePos = UserDefaults.standard.object(forKey: toggleKey) as? Double {
            UserDefaults.standard.set(togglePos + 1, forKey: expanderKey)
        }
    }

    private func applyState(activate: Bool) {
        snapExpanderPosition()
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
        menu.delegate = self

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
    }

    func menuDidClose(_ menu: NSMenu) {
        toggleItem.menu = nil
    }

    @objc private func openAbout() {
        guard let url = URL(string: "https://apps.vlad.studio/less") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func toggleLogin() {
        LoginItem.toggle()
    }
}
