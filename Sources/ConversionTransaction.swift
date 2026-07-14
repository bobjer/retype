import Cocoa

protocol PasteboardManaging: AnyObject {
    var changeCount: Int { get }
    func snapshot() -> ClipboardSnapshot
    func string() -> String?
    func writeTemporaryText(_ text: String, transactionID: UUID)
    func ownsTemporaryContents(transactionID: UUID) -> Bool
    func restore(_ snapshot: ClipboardSnapshot)
}

protocol KeyEventInjecting {
    func copySelection()
    func paste()
}

protocol ConversionScheduling {
    func schedule(after delay: TimeInterval, _ action: @escaping () -> Void)
}

struct ClipboardSnapshot: Equatable {
    struct Item: Equatable {
        let data: [NSPasteboard.PasteboardType: Data]
    }

    let items: [Item]
}

enum ConversionTransactionResult: Equatable {
    case converted
    case ambiguous
    case unchanged
    case noText
    case copyTimedOut
    case busy
}

final class SystemPasteboardManager: PasteboardManaging {
    private static let transactionType = NSPasteboard.PasteboardType("com.retype.transaction-id")
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    var changeCount: Int { pasteboard.changeCount }

    func snapshot() -> ClipboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            var data: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let value = item.data(forType: type) {
                    data[type] = value
                }
            }
            return ClipboardSnapshot.Item(data: data)
        }
        return ClipboardSnapshot(items: items)
    }

    func string() -> String? {
        pasteboard.string(forType: .string)
    }

    func writeTemporaryText(_ text: String, transactionID: UUID) {
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setString(transactionID.uuidString, forType: Self.transactionType)
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
    }

    func ownsTemporaryContents(transactionID: UUID) -> Bool {
        pasteboard.string(forType: Self.transactionType) == transactionID.uuidString
    }

    func restore(_ snapshot: ClipboardSnapshot) {
        pasteboard.clearContents()
        guard !snapshot.items.isEmpty else { return }

        let items = snapshot.items.map { snapshotItem -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in snapshotItem.data {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(items)
    }
}

struct SystemKeyEventInjector: KeyEventInjecting {
    func copySelection() {
        post(keyCode: 8) // Cmd+C
    }

    func paste() {
        post(keyCode: 9) // Cmd+V
    }

    private func post(keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }
}

struct MainQueueScheduler: ConversionScheduling {
    func schedule(after delay: TimeInterval, _ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
    }
}

final class ConversionTransaction {
    private enum State {
        case idle
        case waitingForCopy(Context)
        case waitingToRestore(snapshot: ClipboardSnapshot, transactionID: UUID)
    }

    private struct Context {
        let snapshot: ClipboardSnapshot
        let changeCount: Int
        let startedAt: TimeInterval
    }

    private let pasteboard: PasteboardManaging
    private let keyEvents: KeyEventInjecting
    private let scheduler: ConversionScheduling
    private let convert: (String) -> KeyboardConverter.ConversionResult
    private let completion: (ConversionTransactionResult) -> Void
    private let now: () -> TimeInterval
    private let copyTimeout: TimeInterval
    private let pollInterval: TimeInterval
    private let pasteSettlingDelay: TimeInterval
    private var state: State = .idle

    init(
        pasteboard: PasteboardManaging = SystemPasteboardManager(),
        keyEvents: KeyEventInjecting = SystemKeyEventInjector(),
        scheduler: ConversionScheduling = MainQueueScheduler(),
        copyTimeout: TimeInterval = 0.75,
        pollInterval: TimeInterval = 0.025,
        pasteSettlingDelay: TimeInterval = 0.25,
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        convert: @escaping (String) -> KeyboardConverter.ConversionResult,
        completion: @escaping (ConversionTransactionResult) -> Void
    ) {
        self.pasteboard = pasteboard
        self.keyEvents = keyEvents
        self.scheduler = scheduler
        self.copyTimeout = copyTimeout
        self.pollInterval = pollInterval
        self.pasteSettlingDelay = pasteSettlingDelay
        self.now = now
        self.convert = convert
        self.completion = completion
    }

    @discardableResult
    func start() -> Bool {
        guard case .idle = state else {
            completion(.busy)
            return false
        }

        state = .waitingForCopy(Context(
            snapshot: pasteboard.snapshot(),
            changeCount: pasteboard.changeCount,
            startedAt: now()
        ))
        keyEvents.copySelection()
        pollForCopiedText()
        return true
    }

    private func pollForCopiedText() {
        guard case let .waitingForCopy(context) = state else { return }

        if pasteboard.changeCount != context.changeCount {
            handleCopiedText()
            return
        }

        if now() - context.startedAt >= copyTimeout {
            state = .idle
            completion(.copyTimedOut)
            return
        }

        scheduler.schedule(after: pollInterval) { [weak self] in
            self?.pollForCopiedText()
        }
    }

    private func handleCopiedText() {
        guard case .waitingForCopy = state else { return }
        guard let text = pasteboard.string(), !text.isEmpty else {
            state = .idle
            completion(.noText)
            return
        }

        switch convert(text) {
        case let .converted(convertedText):
            let transactionID = UUID()
            let snapshot = stateSnapshot
            pasteboard.writeTemporaryText(convertedText, transactionID: transactionID)
            state = .waitingToRestore(snapshot: snapshot, transactionID: transactionID)
            keyEvents.paste()
            scheduler.schedule(after: pasteSettlingDelay) { [weak self] in
                self?.restoreClipboardIfStillOwned()
            }
        case .ambiguous:
            state = .idle
            completion(.ambiguous)
        case .unchanged, .unavailable:
            state = .idle
            completion(.unchanged)
        }
    }

    private var stateSnapshot: ClipboardSnapshot {
        guard case let .waitingForCopy(context) = state else {
            preconditionFailure("Clipboard snapshot is only available while waiting for copy")
        }
        return context.snapshot
    }

    private func restoreClipboardIfStillOwned() {
        guard case let .waitingToRestore(snapshot, transactionID) = state else { return }
        state = .idle

        // Never overwrite clipboard data created by the user or another app after Retype pasted.
        if pasteboard.ownsTemporaryContents(transactionID: transactionID) {
            pasteboard.restore(snapshot)
        }
        completion(.converted)
    }
}
