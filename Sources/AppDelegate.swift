import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var converter: KeyboardConverter!
    private var shortcutManager: ShortcutManager!
    private var settingsController: SettingsWindowController?

    private var isEnabled = true
    private var accessibilityMenuItem: NSMenuItem!
    private var accessibilityPollTimer: Timer?
    private var wasAccessibilityGranted = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        converter       = KeyboardConverter()
        shortcutManager = ShortcutManager(converter: converter)

        applyStoredSettings()
        setupStatusBar()
        shortcutManager.start()

        AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        )

        wasAccessibilityGranted = AXIsProcessTrusted()

        if !wasAccessibilityGranted {
            accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self else { return }
                if AXIsProcessTrusted() {
                    self.accessibilityPollTimer?.invalidate()
                    self.accessibilityPollTimer = nil
                    self.shortcutManager.stop()
                    self.shortcutManager.start()
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcutManager.stop()
    }

    private func applyStoredSettings() {
        let defaults = UserDefaults.standard
        let layouts  = converter.installedLayouts

        // From layout — restore or default to first layout
        if let id = defaults.string(forKey: "fromLayoutID"),
           let layout = layouts.first(where: { $0.id == id }) {
            converter.fromLayout = layout
        } else {
            let first = layouts.first
            converter.fromLayout = first
            defaults.set(first?.id, forKey: "fromLayoutID")
        }

        // To layout — restore or default to second distinct layout
        if let id = defaults.string(forKey: "toLayoutID"),
           let layout = layouts.first(where: { $0.id == id }) {
            converter.toLayout = layout
        } else {
            let second = layouts.first { $0.id != converter.fromLayout?.id }
            converter.toLayout = second
            defaults.set(second?.id, forKey: "toLayoutID")
        }

        // Trigger key
        if let raw = defaults.value(forKey: "triggerKeyRaw") as? Int,
           let key = TriggerKey(rawValue: raw) {
            shortcutManager.triggerKey = key
        }

        // Timeout
        let timeout = defaults.double(forKey: "doublePressTimeout")
        if timeout > 0 { shortcutManager.doublePressTimeout = timeout }

        // Cmd+A+A shortcut
        shortcutManager.cmdDoubleAEnabled = defaults.bool(forKey: "cmdDoubleAEnabled")
    }


    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Retype")
            btn.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.delegate = self

        let enableItem = NSMenuItem(title: "Enabled",
                                    action: #selector(toggleEnabled(_:)),
                                    keyEquivalent: "")
        enableItem.state  = .on
        enableItem.target = self
        menu.addItem(enableItem)

        menu.addItem(.separator())

        accessibilityMenuItem = NSMenuItem(title: "", action: #selector(openAccessibilitySettings),
                                           keyEquivalent: "")
        accessibilityMenuItem.target = self
        menu.addItem(accessibilityMenuItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…",
                                      action: #selector(openSettings),
                                      keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Retype",
                                  action: #selector(quit),
                                  keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        isEnabled.toggle()
        sender.state = isEnabled ? .on : .off

        let symbol = isEnabled ? "keyboard" : "keyboard.badge.ellipsis"
        statusItem.button?.image = NSImage(systemSymbolName: symbol,
                                           accessibilityDescription: "Retype")
        statusItem.button?.image?.isTemplate = true

        if isEnabled { shortcutManager.start() } else { shortcutManager.stop() }
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }

    @objc private func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(
                converter: converter,
                shortcutManager: shortcutManager
            )
        }
        settingsController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        let trusted = AXIsProcessTrusted()
        if trusted {
            accessibilityMenuItem.title  = "✓ Accessibility granted"
            accessibilityMenuItem.action = nil
        } else {
            accessibilityMenuItem.title  = "⚠️ Accessibility not granted — click to fix"
            accessibilityMenuItem.action = #selector(openAccessibilitySettings)
        }
    }
}
