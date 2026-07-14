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
    var onResult: ((ConversionTransactionResult) -> Void)?

    // Configurable settings
    var triggerKey: TriggerKey = .leftShift
    var doublePressTimeout: TimeInterval = 0.40
    var cmdDoubleAEnabled: Bool = false
    var switchLayoutAfterConversion: Bool = false

    private var lastDownTime: TimeInterval = 0   // for modifier double-press
    private var lastCmdATime: TimeInterval = 0   // for Cmd+A+A
    private var globalFlagsMonitor: Any?
    private var globalKeyMonitor: Any?
    private lazy var transaction = ConversionTransaction(
        convert: { [weak self] text in
            self?.converter.conversion(for: text) ?? .unavailable
        },
        completion: { [weak self] result in
            self?.handleTransactionResult(result)
        }
    )

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
                    // Let the original Cmd+A finish selecting before reading the selection.
                    DispatchQueue.main.async { [weak self] in
                        self?.startConversion()
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
            DispatchQueue.main.async { [weak self] in
                self?.startConversion()
            }
        } else {
            lastDownTime = now
        }
    }

    private func startConversion() {
        transaction.start()
    }

    private func handleTransactionResult(_ result: ConversionTransactionResult) {
        if result == .converted, switchLayoutAfterConversion {
            converter.switchInputSourceToLastTarget()
        }
        onResult?(result)
    }
}
