import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var converter: KeyboardConverter!
    private var shortcutManager: ShortcutManager!
    private let settings = AppSettings()
    private var settingsController: SettingsWindowController?

    private var isEnabled = true
    private var enableMenuItem: NSMenuItem!
    private var accessibilityMenuItem: NSMenuItem!
    private var statusMenuItem: NSMenuItem!
    private var accessibilityPollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        converter       = KeyboardConverter()
        shortcutManager = ShortcutManager(converter: converter)
        shortcutManager.onResult = { [weak self] result in
            DispatchQueue.main.async {
                self?.updateConversionStatus(result)
            }
        }

        applyStoredSettings()
        setupStatusBar()

        AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        )

        refreshShortcutMonitoring()

        if !AXIsProcessTrusted() {
            accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self else { return }
                if AXIsProcessTrusted() {
                    self.accessibilityPollTimer?.invalidate()
                    self.accessibilityPollTimer = nil
                    self.refreshShortcutMonitoring()
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcutManager.stop()
    }

    private func applyStoredSettings() {
        let layouts  = converter.installedLayouts

        // From layout — restore or default to first layout
        if let id = settings.fromLayoutID,
           let layout = layouts.first(where: { $0.id == id }) {
            converter.fromLayout = layout
        } else {
            let first = layouts.first
            converter.fromLayout = first
            settings.fromLayoutID = first?.id
        }

        // To layout — restore or default to second distinct layout
        if let id = settings.toLayoutID,
           let layout = layouts.first(where: { $0.id == id }),
           layout.id != converter.fromLayout?.id {
            converter.toLayout = layout
        } else {
            let second = layouts.first { $0.id != converter.fromLayout?.id }
            converter.toLayout = second
            settings.toLayoutID = second?.id
        }

        // Trigger key
        if let raw = settings.triggerKeyRaw,
           let key = TriggerKey(rawValue: raw) {
            shortcutManager.triggerKey = key
        }

        // Timeout
        if let timeout = settings.doublePressTimeout {
            shortcutManager.doublePressTimeout = timeout
        }

        // Cmd+A+A shortcut
        shortcutManager.cmdDoubleAEnabled = settings.cmdDoubleAEnabled
        converter.conversionDirection = settings.conversionDirection

        // Option/Alt modifier variants
        converter.includeOptionModifierVariants = settings.includeOptionModifierVariants

        // Switch layout after conversion
        shortcutManager.switchLayoutAfterConversion = settings.switchLayoutAfterConversion
    }


    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Retype")
            btn.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.delegate = self

        enableMenuItem = NSMenuItem(title: "Enabled",
                                    action: #selector(toggleEnabled(_:)),
                                    keyEquivalent: "")
        enableMenuItem.state  = .on
        enableMenuItem.target = self
        menu.addItem(enableMenuItem)

        statusMenuItem = NSMenuItem(title: "Checking requirements…", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(.separator())

        accessibilityMenuItem = NSMenuItem(title: "", action: #selector(openAccessibilitySettings),
                                           keyEquivalent: "")
        accessibilityMenuItem.target = self
        updateAccessibilityMenuItem(trusted: AXIsProcessTrusted())
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
        refreshShortcutMonitoring()
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }

    private func updateAccessibilityMenuItem(trusted: Bool) {
        if trusted {
            accessibilityMenuItem.title  = "Accessibility granted"
            accessibilityMenuItem.action = nil
        } else {
            accessibilityMenuItem.title  = "Accessibility not granted - click to fix"
            accessibilityMenuItem.action = #selector(openAccessibilitySettings)
        }
    }

    private func refreshShortcutMonitoring() {
        let trusted = AXIsProcessTrusted()
        let hasPair = converter.hasUsableLayoutPair
        let shouldRun = isEnabled && trusted && hasPair

        if shouldRun { shortcutManager.start() } else { shortcutManager.stop() }

        updateAccessibilityMenuItem(trusted: trusted)
        enableMenuItem?.isEnabled = trusted && hasPair

        if !trusted {
            updateStatus("Accessibility permission required")
        } else if !hasPair {
            updateStatus("Choose two different keyboard layouts in Settings")
        } else if !isEnabled {
            updateStatus("Conversion disabled")
        } else {
            updateStatus("Ready")
        }
    }

    private func updateConversionStatus(_ result: ConversionTransactionResult) {
        switch result {
        case .converted:
            updateStatus("Converted")
        case .ambiguous:
            updateStatus("Ambiguous text — choose an explicit direction in Settings")
        case .unchanged:
            updateStatus("Selection cannot be converted with the current layouts")
        case .noText:
            updateStatus("No plain text in the selection")
        case .copyTimedOut:
            updateStatus("Could not copy the selection")
        case .busy:
            updateStatus("Conversion already in progress")
        }
    }

    private func updateStatus(_ message: String) {
        statusMenuItem?.title = message
        let active = message == "Ready"
        let symbol = active ? "keyboard" : "keyboard.badge.ellipsis"
        statusItem?.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: message)
        statusItem?.button?.image?.isTemplate = true
    }

    @objc private func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(
                converter: converter,
                shortcutManager: shortcutManager,
                settings: settings
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
        refreshShortcutMonitoring()
    }
}
