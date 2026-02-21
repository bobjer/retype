import Carbon
import Foundation

class KeyboardConverter {

    struct Layout: Identifiable, Hashable {
        let id: String
        let name: String

        // char → (keyCode, isShifted)
        let charToKey: [Character: (keyCode: Int, shifted: Bool)]
        // keyCode → unshifted/shifted character
        let keyToChar: [Int: Character]
        let keyToCharShifted: [Int: Character]

        func key(for char: Character) -> (keyCode: Int, shifted: Bool)? {
            charToKey[char]
        }

        func char(for keyCode: Int, shifted: Bool) -> Character? {
            shifted ? keyToCharShifted[keyCode] : keyToChar[keyCode]
        }

        // Hashable/Equatable based on ID only
        static func == (lhs: Layout, rhs: Layout) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    private(set) var installedLayouts: [Layout] = []
    var fromLayout: Layout?
    var toLayout: Layout?

    init() {
        installedLayouts = Self.loadInstalledLayouts()
    }

    func convert(_ text: String) -> String {
        guard let from = fromLayout, let to = toLayout else { return text }

        // Auto-detect direction: count how many characters exist in each layout
        var forwardMatches = 0
        var reverseMatches = 0
        for char in text {
            if char.isWhitespace || char.isNewline { continue }
            if from.key(for: char) != nil { forwardMatches += 1 }
            if to.key(for: char) != nil { reverseMatches += 1 }
        }

        return forwardMatches >= reverseMatches
            ? Self.map(text, from: from, to: to)
            : Self.map(text, from: to, to: from)
    }

    private static func map(_ text: String, from: Layout, to: Layout) -> String {
        String(text.map { char in
            guard let key = from.key(for: char) else { return char }
            return to.char(for: key.keyCode, shifted: key.shifted) ?? char
        })
    }

    static func loadInstalledLayouts() -> [Layout] {
        // Only enabled keyboard layouts (not IMEs, not panel input sources)
        let filter: [String: Any] = [
            kTISPropertyInputSourceType as String: kTISTypeKeyboardLayout as String
        ]

        guard let unmanaged = TISCreateInputSourceList(filter as CFDictionary, false) else {
            return []
        }
        let list = unmanaged.takeRetainedValue()
        let count = CFArrayGetCount(list)

        var layouts: [Layout] = []
        for i in 0..<count {
            guard let rawPtr = CFArrayGetValueAtIndex(list, i) else { continue }
            let source = Unmanaged<TISInputSource>.fromOpaque(rawPtr).takeUnretainedValue()
            if let layout = buildLayout(from: source) {
                layouts.append(layout)
            }
        }

        return layouts.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    private static func buildLayout(from source: TISInputSource) -> Layout? {
        // Require Unicode layout data (some legacy layouts don't have it)
        guard
            let namePtr  = TISGetInputSourceProperty(source, kTISPropertyLocalizedName),
            let idPtr    = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
            let dataPtr  = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
        let id   = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
        let data = Unmanaged<CFData>.fromOpaque(dataPtr).takeUnretainedValue()

        var keyToChar:        [Int: Character] = [:]
        var keyToCharShifted: [Int: Character] = [:]
        var charToKey: [Character: (keyCode: Int, shifted: Bool)] = [:]

        for keyCode in printableKeyCodes {
            if let c = translateKey(keyCode: keyCode, shifted: false, data: data) {
                keyToChar[keyCode] = c
                if charToKey[c] == nil { charToKey[c] = (keyCode, false) }
            }
            if let c = translateKey(keyCode: keyCode, shifted: true, data: data) {
                keyToCharShifted[keyCode] = c
                if charToKey[c] == nil { charToKey[c] = (keyCode, true) }
            }
        }

        guard !charToKey.isEmpty else { return nil }
        return Layout(id: id, name: name, charToKey: charToKey,
                      keyToChar: keyToChar, keyToCharShifted: keyToCharShifted)
    }

    /// Translate a physical keyCode + shift state to the character it produces
    /// in the given keyboard layout data, using UCKeyTranslate
    private static func translateKey(keyCode: Int, shifted: Bool, data: CFData) -> Character? {
        let ptr = CFDataGetBytePtr(data)!
        let keyboard = UnsafeRawPointer(ptr).assumingMemoryBound(to: UCKeyboardLayout.self)

        // modifierKeyState: 0 = none, 2 = Shift
        let modState: UInt32 = shifted ? 2 : 0
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var charCount = 0

        let err = UCKeyTranslate(
            keyboard,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            modState,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysMask),
            &deadKeyState,
            4,
            &charCount,
            &chars
        )

        guard err == noErr, charCount > 0 else { return nil }
        guard let scalar = Unicode.Scalar(chars[0]) else { return nil }
        let char = Character(scalar)

        // Filter out non-printable characters
        let value = scalar.value
        guard value >= 0x20, value != 0x7F else { return nil }
        guard !char.isNewline else { return nil }

        return char
    }

    // MARK: - Key codes for all printable keys (ANSI layout positions)
    // Numbers, letters, punctuation — excludes space, function keys, etc.
    private static let printableKeyCodes: [Int] = [
        // Letters
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,  // a s d f h g z x
        0x08, 0x09, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10,  // c v b q w e r y
        0x11, 0x1F, 0x20, 0x22, 0x23, 0x25, 0x26, 0x28,  // t o u i p l j k
        0x2D, 0x2E,                                         // n m
        // Number row
        0x12, 0x13, 0x14, 0x15, 0x17, 0x16, 0x1A, 0x1C, 0x19, 0x1D,  // 1-9, 0
        // Symbols
        0x18, 0x1B,       // = -
        0x21, 0x1E,       // [ ]
        0x27, 0x29, 0x2A, // ' ; \
        0x2B, 0x2F, 0x2C, // , . /
        0x32,             // ` (grave / tilde)
    ]
}
