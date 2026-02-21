import Cocoa
import ServiceManagement

private let kFromLayoutID              = "fromLayoutID"
private let kToLayoutID                = "toLayoutID"
private let kTriggerKeyRaw             = "triggerKeyRaw"
private let kDoublePressTimeout        = "doublePressTimeout"
private let kSwitchLayoutAfterConvert  = "switchLayoutAfterConversion"

class SettingsWindowController: NSWindowController {

    private let converter:      KeyboardConverter
    private let shortcutManager: ShortcutManager

    private var fromPopup:    NSPopUpButton!
    private var toPopup:      NSPopUpButton!
    private var triggerPopup: NSPopUpButton!
    private var timeoutSlider: NSSlider!
    private var timeoutLabel:  NSTextField!
    private var launchCheckbox: NSButton!

    // Cached layouts list
    private var layouts: [KeyboardConverter.Layout] = []

    init(converter: KeyboardConverter, shortcutManager: ShortcutManager) {
        self.converter       = converter
        self.shortcutManager = shortcutManager

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 390, height: 350),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Retype Settings"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        guard let content = window?.contentView else { return }
        layouts = converter.installedLayouts

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 16
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            root.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20),
        ])

        root.addArrangedSubview(sectionLabel("Conversion"))

        fromPopup = makeLayoutPopup()
        toPopup   = makeLayoutPopup()
        populate(popup: fromPopup, selected: converter.fromLayout)
        populate(popup: toPopup,   selected: converter.toLayout)
        fromPopup.target = self; fromPopup.action = #selector(fromChanged(_:))
        toPopup.target   = self; toPopup.action   = #selector(toChanged(_:))

        syncConverterWithPopups()

        root.addArrangedSubview(makeRow(label: "From layout:", control: fromPopup))
        root.addArrangedSubview(makeRow(label: "To layout:",   control: toPopup))

        root.addArrangedSubview(separatorView())

        root.addArrangedSubview(sectionLabel("Shortcut"))

        triggerPopup = NSPopUpButton()
        for key in TriggerKey.allCases {
            triggerPopup.addItem(withTitle: key.displayName)
            triggerPopup.lastItem?.tag = key.rawValue
        }
        if let idx = TriggerKey.allCases.firstIndex(of: shortcutManager.triggerKey) {
            triggerPopup.selectItem(at: idx)
        }
        triggerPopup.target = self
        triggerPopup.action = #selector(triggerChanged(_:))
        root.addArrangedSubview(makeRow(label: "Trigger key:", control: triggerPopup))

        let timeout = shortcutManager.doublePressTimeout
        timeoutSlider = NSSlider(value: timeout, minValue: 0.15, maxValue: 1.0,
                                 target: self, action: #selector(timeoutChanged(_:)))
        timeoutSlider.isContinuous = true
        timeoutSlider.widthAnchor.constraint(equalToConstant: 160).isActive = true

        timeoutLabel = NSTextField(labelWithString: String(format: "%.2f s", timeout))
        timeoutLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)

        let sliderRow = NSStackView(views: [timeoutSlider, timeoutLabel])
        sliderRow.orientation = .horizontal
        sliderRow.spacing = 8
        root.addArrangedSubview(makeRow(label: "Timeout:", control: sliderRow))

        let cmdDoubleACheckbox = NSButton(
            checkboxWithTitle: "Also trigger with ⌘A + A  (hold ⌘, press A twice)",
            target: self, action: #selector(cmdDoubleAToggled(_:))
        )
        cmdDoubleACheckbox.state = shortcutManager.cmdDoubleAEnabled ? .on : .off
        root.addArrangedSubview(cmdDoubleACheckbox)

        let switchLayoutCheckbox = NSButton(
            checkboxWithTitle: "Switch keyboard layout after conversion",
            target: self, action: #selector(switchLayoutToggled(_:))
        )
        switchLayoutCheckbox.state = shortcutManager.switchLayoutAfterConversion ? .on : .off
        root.addArrangedSubview(switchLayoutCheckbox)

        root.addArrangedSubview(separatorView())

        launchCheckbox = NSButton(checkboxWithTitle: "Launch at login",
                                  target: self, action: #selector(launchToggled(_:)))
        launchCheckbox.state = isLaunchAtLoginEnabled() ? .on : .off
        root.addArrangedSubview(launchCheckbox)

        let hint = NSTextField(wrappingLabelWithString:
            "Select text, then double-press the trigger key to convert between layouts.")
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.widthAnchor.constraint(lessThanOrEqualToConstant: 350).isActive = true
        root.addArrangedSubview(hint)
    }

    private func syncConverterWithPopups() {
        guard !layouts.isEmpty else { return }
        let fromIdx = max(0, fromPopup.indexOfSelectedItem)
        let toIdx   = max(0, toPopup.indexOfSelectedItem)
        if fromIdx < layouts.count {
            converter.fromLayout = layouts[fromIdx]
            UserDefaults.standard.set(layouts[fromIdx].id, forKey: kFromLayoutID)
        }
        if toIdx < layouts.count {
            converter.toLayout = layouts[toIdx]
            UserDefaults.standard.set(layouts[toIdx].id, forKey: kToLayoutID)
        }
    }

    private func makeLayoutPopup() -> NSPopUpButton {
        let popup = NSPopUpButton()
        if layouts.isEmpty {
            popup.addItem(withTitle: "No layouts found")
            popup.isEnabled = false
        }
        return popup
    }

    private func populate(popup: NSPopUpButton, selected: KeyboardConverter.Layout?) {
        popup.removeAllItems()
        for layout in layouts {
            popup.addItem(withTitle: layout.name)
        }
        if let sel = selected, let idx = layouts.firstIndex(where: { $0.id == sel.id }) {
            popup.selectItem(at: idx)
        }
    }

    private func makeRow(label: String, control: NSView) -> NSStackView {
        let lbl = NSTextField(labelWithString: label)
        lbl.font = NSFont.systemFont(ofSize: 13)
        lbl.widthAnchor.constraint(equalToConstant: 110).isActive = true

        let row = NSStackView(views: [lbl, control])
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        return row
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let lbl = NSTextField(labelWithString: text.uppercased())
        lbl.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        lbl.textColor = .secondaryLabelColor
        return lbl
    }

    private func separatorView() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    @objc private func fromChanged(_ sender: NSPopUpButton) {
        let idx = sender.indexOfSelectedItem
        guard idx >= 0, idx < layouts.count else { return }
        let layout = layouts[idx]
        converter.fromLayout = layout
        UserDefaults.standard.set(layout.id, forKey: kFromLayoutID)
    }

    @objc private func toChanged(_ sender: NSPopUpButton) {
        let idx = sender.indexOfSelectedItem
        guard idx >= 0, idx < layouts.count else { return }
        let layout = layouts[idx]
        converter.toLayout = layout
        UserDefaults.standard.set(layout.id, forKey: kToLayoutID)
    }

    @objc private func triggerChanged(_ sender: NSPopUpButton) {
        let tag = sender.selectedItem?.tag ?? TriggerKey.leftShift.rawValue
        if let key = TriggerKey(rawValue: tag) {
            shortcutManager.triggerKey = key
            UserDefaults.standard.set(key.rawValue, forKey: kTriggerKeyRaw)
        }
    }

    @objc private func timeoutChanged(_ sender: NSSlider) {
        let val = sender.doubleValue
        shortcutManager.doublePressTimeout = val
        timeoutLabel.stringValue = String(format: "%.2f s", val)
        UserDefaults.standard.set(val, forKey: kDoublePressTimeout)
    }

    @objc private func cmdDoubleAToggled(_ sender: NSButton) {
        let enabled = sender.state == .on
        shortcutManager.cmdDoubleAEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "cmdDoubleAEnabled")
    }

    @objc private func switchLayoutToggled(_ sender: NSButton) {
        let enabled = sender.state == .on
        shortcutManager.switchLayoutAfterConversion = enabled
        UserDefaults.standard.set(enabled, forKey: kSwitchLayoutAfterConvert)
    }

    @objc private func launchToggled(_ sender: NSButton) {
        let enable = sender.state == .on
        do {
            if enable { try SMAppService.mainApp.register() }
            else       { try SMAppService.mainApp.unregister() }
        } catch {
            sender.state = enable ? .off : .on
        }
    }

    private func isLaunchAtLoginEnabled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }
}
