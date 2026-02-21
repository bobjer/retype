import Cocoa

enum TriggerKey: Int, CaseIterable {
    case leftShift    = 56
    case rightShift   = 60
    case leftControl  = 59
    case leftOption   = 58
    case leftCommand  = 55

    var displayName: String {
        switch self {
        case .leftShift:   return "Left Shift"
        case .rightShift:  return "Right Shift"
        case .leftControl: return "Left Control"
        case .leftOption:  return "Left Option (Alt)"
        case .leftCommand: return "Left Command"
        }
    }

    var requiredFlag: NSEvent.ModifierFlags {
        switch self {
        case .leftShift, .rightShift: return .shift
        case .leftControl:            return .control
        case .leftOption:             return .option
        case .leftCommand:            return .command
        }
    }
}

// MARK: -

class ShortcutManager {

    private let converter: KeyboardConverter

    // Configurable settings
    var triggerKey: TriggerKey = .leftShift
    var doublePressTimeout: TimeInterval = 0.40
    var cmdDoubleAEnabled: Bool = false

    private var lastDownTime: TimeInterval = 0   // for modifier double-press
    private var lastCmdATime: TimeInterval = 0   // for Cmd+A+A
    private var globalFlagsMonitor: Any?
    private var globalKeyMonitor: Any?

    init(converter: KeyboardConverter) {
        self.converter = converter
    }

    func start() {
        guard globalFlagsMonitor == nil else { return }

        // Modifier key double-press (Shift / Ctrl / Option / Command)
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        // Key-down monitor: handles Cmd+A+A and resets modifier double-press timer
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }

            // Cmd+A while ⌘ is held → Cmd+A+A trigger
            if self.cmdDoubleAEnabled,
               event.keyCode == 0x00,                          // 'A' key
               event.modifierFlags.contains(.command) {
                let now = ProcessInfo.processInfo.systemUptime
                if self.lastCmdATime > 0 && (now - self.lastCmdATime) < self.doublePressTimeout {
                    self.lastCmdATime = 0
                    // Text is already selected by the first Cmd+A — go straight to copy/convert/paste
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                        self?.performConversion()
                    }
                } else {
                    self.lastCmdATime = now
                }
                // Do NOT reset the modifier double-press timer for Cmd+A
                return
            }

            // Any other key resets both timers
            self.lastDownTime = 0
            self.lastCmdATime = 0
        }
    }

    func stop() {
        if let m = globalFlagsMonitor { NSEvent.removeMonitor(m); globalFlagsMonitor = nil }
        if let m = globalKeyMonitor   { NSEvent.removeMonitor(m); globalKeyMonitor   = nil }
    }

    // MARK: - Modifier double-press

    private func handleFlagsChanged(_ event: NSEvent) {
        guard Int(event.keyCode) == triggerKey.rawValue else { return }
        guard event.modifierFlags.contains(triggerKey.requiredFlag) else { return }

        let now = ProcessInfo.processInfo.systemUptime

        if lastDownTime > 0 && (now - lastDownTime) < doublePressTimeout {
            lastDownTime = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.performConversion()
            }
        } else {
            lastDownTime = now
        }
    }

    // MARK: - Conversion workflow

    private func performConversion() {
        let pasteboard = NSPasteboard.general
        let changeCountBefore = pasteboard.changeCount
        let savedContents = saveClipboard()

        simulateKeyCombo(keyCode: 8, flags: .maskCommand) // Cmd+C

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
            guard let self else { return }

            guard pasteboard.changeCount != changeCountBefore else { return }

            guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
                self.restoreClipboard(savedContents)
                return
            }

            let converted = self.converter.convert(text)
            guard converted != text else {
                self.restoreClipboard(savedContents)
                return
            }

            pasteboard.clearContents()
            pasteboard.setString(converted, forType: .string)
            self.simulateKeyCombo(keyCode: 9, flags: .maskCommand) // Cmd+V

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.restoreClipboard(savedContents)
            }
        }
    }

    private func simulateKeyCombo(keyCode: CGKeyCode, flags: CGEventFlags) {
        let src = CGEventSource(stateID: .hidSystemState)
        guard
            let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true),
            let up   = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        else { return }
        down.flags = flags
        down.post(tap: .cgSessionEventTap)
        up.flags = flags
        up.post(tap: .cgSessionEventTap)
    }

    // MARK: - Clipboard

    private struct ClipboardSnapshot {
        let types: [NSPasteboard.PasteboardType]
        let data:  [NSPasteboard.PasteboardType: Data]
    }

    private func saveClipboard() -> [ClipboardSnapshot] {
        (NSPasteboard.general.pasteboardItems ?? []).map { item in
            var d: [NSPasteboard.PasteboardType: Data] = [:]
            for t in item.types { if let v = item.data(forType: t) { d[t] = v } }
            return ClipboardSnapshot(types: item.types, data: d)
        }
    }

    private func restoreClipboard(_ snapshots: [ClipboardSnapshot]) {
        guard !snapshots.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        for snap in snapshots {
            let item = NSPasteboardItem()
            for t in snap.types { if let v = snap.data[t] { item.setData(v, forType: t) } }
            pb.writeObjects([item])
        }
    }
}
