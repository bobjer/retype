@testable import Retype
import Cocoa
import XCTest

final class ConversionTransactionTests: XCTestCase {
    func testConversionRestoresOriginalClipboardAfterPaste() {
        let pasteboard = FakePasteboard(text: "original")
        let events = FakeKeyEvents()
        let scheduler = TestScheduler()
        let results = ResultRecorder()
        let transaction = makeTransaction(pasteboard: pasteboard, events: events, scheduler: scheduler, results: results)

        XCTAssertTrue(transaction.start())
        XCTAssertEqual(events.copyCount, 1)

        pasteboard.replaceExternally(with: "mistyped")
        scheduler.runNext()
        XCTAssertEqual(pasteboard.text, "MISTYPED")
        XCTAssertEqual(events.pasteCount, 1)
        XCTAssertEqual(results.values, [])

        scheduler.runNext()
        XCTAssertEqual(pasteboard.text, "original")
        XCTAssertEqual(results.values, [.converted])
    }

    func testExternalClipboardChangeIsNeverOverwrittenDuringRestore() {
        let pasteboard = FakePasteboard(text: "original")
        let events = FakeKeyEvents()
        let scheduler = TestScheduler()
        let results = ResultRecorder()
        let transaction = makeTransaction(pasteboard: pasteboard, events: events, scheduler: scheduler, results: results)

        XCTAssertTrue(transaction.start())
        pasteboard.replaceExternally(with: "mistyped")
        scheduler.runNext()
        pasteboard.replaceExternally(with: "user copied this")

        scheduler.runNext()
        XCTAssertEqual(pasteboard.text, "user copied this")
        XCTAssertEqual(results.values, [.converted])
    }

    func testEmptyClipboardIsRestoredToEmpty() {
        let pasteboard = FakePasteboard(text: nil)
        let events = FakeKeyEvents()
        let scheduler = TestScheduler()
        let results = ResultRecorder()
        let transaction = makeTransaction(pasteboard: pasteboard, events: events, scheduler: scheduler, results: results)

        XCTAssertTrue(transaction.start())
        pasteboard.replaceExternally(with: "mistyped")
        scheduler.runNext()
        scheduler.runNext()

        XCTAssertNil(pasteboard.text)
        XCTAssertEqual(pasteboard.snapshot().items, [])
    }

    func testMultipleClipboardItemsAreRestoredTogether() {
        let original = ClipboardSnapshot(items: [
            .init(data: [.string: Data("first".utf8)]),
            .init(data: [NSPasteboard.PasteboardType("public.rtf"): Data([0x7B, 0x7D])]),
        ])
        let pasteboard = FakePasteboard(snapshot: original)
        let events = FakeKeyEvents()
        let scheduler = TestScheduler()
        let results = ResultRecorder()
        let transaction = makeTransaction(pasteboard: pasteboard, events: events, scheduler: scheduler, results: results)

        XCTAssertTrue(transaction.start())
        pasteboard.replaceExternally(with: "mistyped")
        scheduler.runNext()
        scheduler.runNext()

        XCTAssertEqual(pasteboard.snapshot(), original)
    }

    func testSecondTriggerIsRejectedWhileCopyIsPending() {
        let pasteboard = FakePasteboard(text: "original")
        let events = FakeKeyEvents()
        let scheduler = TestScheduler()
        let results = ResultRecorder()
        let transaction = makeTransaction(pasteboard: pasteboard, events: events, scheduler: scheduler, results: results)

        XCTAssertTrue(transaction.start())
        XCTAssertFalse(transaction.start())
        XCTAssertEqual(events.copyCount, 1)
        XCTAssertEqual(results.values, [.busy])
    }

    func testCopyTimeoutLeavesClipboardUntouched() {
        let pasteboard = FakePasteboard(text: "original")
        let events = FakeKeyEvents()
        let scheduler = TestScheduler()
        let results = ResultRecorder()
        let transaction = makeTransaction(pasteboard: pasteboard, events: events, scheduler: scheduler, results: results)

        XCTAssertTrue(transaction.start())
        scheduler.runAll()

        XCTAssertEqual(pasteboard.text, "original")
        XCTAssertEqual(results.values, [.copyTimedOut])
    }

    private func makeTransaction(
        pasteboard: FakePasteboard,
        events: FakeKeyEvents,
        scheduler: TestScheduler,
        results: ResultRecorder
    ) -> ConversionTransaction {
        ConversionTransaction(
            pasteboard: pasteboard,
            keyEvents: events,
            scheduler: scheduler,
            copyTimeout: 0.10,
            pollInterval: 0.025,
            pasteSettlingDelay: 0.05,
            now: { scheduler.time },
            convert: { .converted($0.uppercased()) },
            completion: { results.values.append($0) }
        )
    }
}

private final class ResultRecorder {
    var values: [ConversionTransactionResult] = []
}

private final class FakePasteboard: PasteboardManaging {
    private(set) var changeCount = 0
    private(set) var text: String?
    private var transactionID: UUID?
    private var savedSnapshot: ClipboardSnapshot

    init(text: String?) {
        self.text = text
        if let text {
            self.savedSnapshot = ClipboardSnapshot(items: [.init(data: [.string: Data(text.utf8)])])
        } else {
            self.savedSnapshot = ClipboardSnapshot(items: [])
        }
    }

    init(snapshot: ClipboardSnapshot) {
        self.savedSnapshot = snapshot
        self.text = snapshot.items.first?.data[.string].flatMap { String(data: $0, encoding: .utf8) }
    }

    func snapshot() -> ClipboardSnapshot {
        savedSnapshot
    }

    func string() -> String? {
        text
    }

    func writeTemporaryText(_ text: String, transactionID: UUID) {
        self.text = text
        self.transactionID = transactionID
        self.savedSnapshot = ClipboardSnapshot(items: [.init(data: [.string: Data(text.utf8)])])
        changeCount += 1
    }

    func ownsTemporaryContents(transactionID: UUID) -> Bool {
        self.transactionID == transactionID
    }

    func restore(_ snapshot: ClipboardSnapshot) {
        savedSnapshot = snapshot
        transactionID = nil
        text = snapshot.items.first?.data[.string].flatMap { String(data: $0, encoding: .utf8) }
        changeCount += 1
    }

    func replaceExternally(with text: String) {
        self.text = text
        transactionID = nil
        savedSnapshot = ClipboardSnapshot(items: [.init(data: [.string: Data(text.utf8)])])
        changeCount += 1
    }
}

private final class FakeKeyEvents: KeyEventInjecting {
    private(set) var copyCount = 0
    private(set) var pasteCount = 0

    func copySelection() { copyCount += 1 }
    func paste() { pasteCount += 1 }
}

private final class TestScheduler: ConversionScheduling {
    private struct ScheduledAction {
        let delay: TimeInterval
        let action: () -> Void
    }

    var time: TimeInterval = 0
    private var actions: [ScheduledAction] = []

    func schedule(after delay: TimeInterval, _ action: @escaping () -> Void) {
        actions.append(ScheduledAction(delay: delay, action: action))
    }

    func runNext() {
        let scheduled = actions.removeFirst()
        time += scheduled.delay
        scheduled.action()
    }

    func runAll() {
        while !actions.isEmpty {
            runNext()
        }
    }
}
