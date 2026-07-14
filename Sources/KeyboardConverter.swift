import Carbon
import Foundation

class KeyboardConverter {

    enum ConversionDirection: String, CaseIterable {
        case automatic
        case fromTo
        case toFrom

        var displayName: String {
            switch self {
            case .automatic: return "Automatic (safe)"
            case .fromTo:    return "From → To"
            case .toFrom:    return "To → From"
            }
        }
    }

    enum ConversionResult: Equatable {
        case converted(String)
        case ambiguous(forward: String, reverse: String)
        case unchanged
        case unavailable
    }

    struct ModifierState: OptionSet, Hashable {
        let rawValue: UInt32

        // UCKeyTranslate modifierKeyState = Carbon modifier bits >> 8 (shiftKey 0x200 -> 2, optionKey 0x800 -> 8)
        static let shift = ModifierState(rawValue: 2)
        static let option = ModifierState(rawValue: 8)
    }

    struct KeyStroke: Hashable {
        let keyCode: Int
        let modifiers: ModifierState
    }

    struct Layout: Identifiable, Hashable {
        let id: String
        let name: String

        // char -> physical key + modifier state
        let charToKey: [Character: KeyStroke]
        // physical key + modifier state -> character
        let keyStrokeToChar: [KeyStroke: Character]

        func key(for char: Character, includingOption: Bool) -> KeyStroke? {
            guard let keyStroke = charToKey[char] else { return nil }
            if !includingOption && keyStroke.modifiers.contains(.option) {
                return nil
            }
            return keyStroke
        }

        func char(for keyStroke: KeyStroke) -> Character? {
            keyStrokeToChar[keyStroke]
        }

        // Hashable/Equatable based on ID only
        static func == (lhs: Layout, rhs: Layout) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    private(set) var installedLayouts: [Layout] = []
    var fromLayout: Layout?
    var toLayout: Layout?
    var includeOptionModifierVariants = true
    var conversionDirection: ConversionDirection = .automatic

    /// The layout that was actually used as the conversion target (set after each convert() call)
    private(set) var lastConvertedToLayout: Layout?

    convenience init() {
        self.init(layouts: KeyboardConverter.loadInstalledLayouts())
    }

    init(layouts: [Layout]) {
        installedLayouts = layouts
    }

    var hasUsableLayoutPair: Bool {
        guard let from = fromLayout, let to = toLayout else { return false }
        return from.id != to.id
    }

    func convert(_ text: String) -> String {
        switch conversion(for: text) {
        case let .converted(converted): return converted
        case .ambiguous, .unchanged, .unavailable: return text
        }
    }

    func conversion(for text: String, direction: ConversionDirection? = nil) -> ConversionResult {
        guard let from = fromLayout, let to = toLayout, from.id != to.id else {
            return .unavailable
        }

        let requestedDirection = direction ?? conversionDirection
        let forward = Self.map(text, from: from, to: to, includingOption: includeOptionModifierVariants)
        let reverse = Self.map(text, from: to, to: from, includingOption: includeOptionModifierVariants)

        switch requestedDirection {
        case .fromTo:
            return complete(forward, target: to, original: text)
        case .toFrom:
            return complete(reverse, target: from, original: text)
        case .automatic:
            let evidence = Self.directionalEvidence(
                in: text,
                from: from,
                to: to,
                includingOption: includeOptionModifierVariants
            )
            if evidence.forward > evidence.reverse {
                return complete(forward, target: to, original: text)
            }
            if evidence.reverse > evidence.forward {
                return complete(reverse, target: from, original: text)
            }
            if forward == text && reverse == text {
                return .unchanged
            }
            return .ambiguous(forward: forward, reverse: reverse)
        }
    }

    private func complete(_ converted: String, target: Layout, original: String) -> ConversionResult {
        guard converted != original else { return .unchanged }
        lastConvertedToLayout = target
        return .converted(converted)
    }

    /// Switch the system input source to the layout we just converted into
    func switchInputSourceToLastTarget() {
        guard let targetID = lastConvertedToLayout?.id else { return }
        let filter = [kTISPropertyInputSourceID: targetID] as CFDictionary
        guard let unmanaged = TISCreateInputSourceList(filter, false) else { return }
        let list = unmanaged.takeRetainedValue()
        guard CFArrayGetCount(list) > 0,
              let rawPtr = CFArrayGetValueAtIndex(list, 0) else { return }
        let source = Unmanaged<TISInputSource>.fromOpaque(rawPtr).takeUnretainedValue()
        TISSelectInputSource(source)
    }

    private static func map(_ text: String, from: Layout, to: Layout, includingOption: Bool) -> String {
        String(text.map { char in
            guard let key = from.key(for: char, includingOption: includingOption) else { return char }
            return to.char(for: key) ?? char
        })
    }

    private static func directionalEvidence(
        in text: String,
        from: Layout,
        to: Layout,
        includingOption: Bool
    ) -> (forward: Int, reverse: Int) {
        var forward = 0
        var reverse = 0

        for char in text where !char.isWhitespace && !char.isNewline {
            let forwardCharacter = mappedCharacter(char, from: from, to: to, includingOption: includingOption)
            let reverseCharacter = mappedCharacter(char, from: to, to: from, includingOption: includingOption)

            let supportsForward = forwardCharacter != char
            let supportsReverse = reverseCharacter != char
            if supportsForward && !supportsReverse { forward += 1 }
            if supportsReverse && !supportsForward { reverse += 1 }
        }

        return (forward, reverse)
    }

    private static func mappedCharacter(
        _ char: Character,
        from: Layout,
        to: Layout,
        includingOption: Bool
    ) -> Character {
        guard let key = from.key(for: char, includingOption: includingOption) else { return char }
        return to.char(for: key) ?? char
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

        var keyStrokeToChar: [KeyStroke: Character] = [:]
        var charToKey: [Character: KeyStroke] = [:]

        for keyCode in printableKeyCodes {
            for modifiers in supportedModifierStates {
                guard let c = translateKey(keyCode: keyCode, modifiers: modifiers, data: data) else {
                    continue
                }

                let keyStroke = KeyStroke(keyCode: keyCode, modifiers: modifiers)
                keyStrokeToChar[keyStroke] = c
                if charToKey[c] == nil { charToKey[c] = keyStroke }
            }
        }

        guard !charToKey.isEmpty else { return nil }
        return Layout(id: id, name: name, charToKey: charToKey,
                      keyStrokeToChar: keyStrokeToChar)
    }

    /// Translate a physical keyCode + shift state to the character it produces
    /// in the given keyboard layout data, using UCKeyTranslate
    private static func translateKey(keyCode: Int, modifiers: ModifierState, data: CFData) -> Character? {
        let ptr = CFDataGetBytePtr(data)!
        let keyboard = UnsafeRawPointer(ptr).assumingMemoryBound(to: UCKeyboardLayout.self)

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var charCount = 0

        let err = UCKeyTranslate(
            keyboard,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            modifiers.rawValue,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysMask),
            &deadKeyState,
            4,
            &charCount,
            &chars
        )

        guard err == noErr, charCount > 0 else { return nil }
        let translated = String(utf16CodeUnits: chars, count: charCount)
        guard translated.count == 1, let char = translated.first else { return nil }

        // Filter out non-printable characters
        guard let scalar = char.unicodeScalars.first else { return nil }
        let value = scalar.value
        guard value >= 0x20, value != 0x7F else { return nil }
        guard !char.isNewline else { return nil }

        return char
    }

    private static let supportedModifierStates: [ModifierState] = [
        [],
        .shift,
        .option,
        [.shift, .option],
    ]

    // MARK: - Printable virtual key codes
    // ANSI plus ISO section and JIS punctuation keys. Dead-key composition is deliberately
    // excluded by kUCKeyTranslateNoDeadKeysMask, because it cannot be mapped one keystroke at a time.
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
        // ISO / JIS printable keys
        0x0A,             // ISO section
        0x5D, 0x5E, 0x5F, // JIS yen, underscore, keypad comma
    ]
}
