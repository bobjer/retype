@testable import Retype
import XCTest

final class KeyboardConverterTests: XCTestCase {
    func testOptionCharactersConvertWhenEnabled() {
        let converter = makeConverter(includeOption: true)

        XCTAssertEqual(converter.convert("ß æ"), "ы э")
    }

    func testOptionCharactersStayUnchangedWhenDisabled() {
        let converter = makeConverter(includeOption: false)

        XCTAssertEqual(converter.convert("ß æ"), "ß æ")
    }

    func testPlainAndShiftCharactersStillConvertWhenOptionIsDisabled() {
        let converter = makeConverter(includeOption: false)

        XCTAssertEqual(converter.convert("a A"), "ф Ф")
    }

    func testAutoDetectConvertsReverseOptionDirectionWhenEnabled() {
        let converter = makeConverter(includeOption: true)

        XCTAssertEqual(converter.convert("ы э"), "ß æ")
    }

    func testUnknownCharactersStayUnchanged() {
        let converter = makeConverter(includeOption: true)

        XCTAssertEqual(converter.convert("a!"), "ф!")
    }

    func testWhitespaceDoesNotAffectDirectionDetection() {
        let converter = makeConverter(includeOption: true)

        XCTAssertEqual(converter.convert("  ы\n"), "  ß\n")
    }

    func testAutomaticConversionStopsWhenBothDirectionsHaveEqualEvidence() {
        let converter = makeConverter(includeOption: true)

        XCTAssertEqual(
            converter.conversion(for: "aф"),
            .ambiguous(forward: "фф", reverse: "aa")
        )
        XCTAssertEqual(converter.convert("aф"), "aф")
    }

    func testExplicitDirectionConvertsAmbiguousText() {
        let converter = makeConverter(includeOption: true)

        XCTAssertEqual(
            converter.conversion(for: "aф", direction: .fromTo),
            .converted("фф")
        )
        XCTAssertEqual(
            converter.conversion(for: "aф", direction: .toFrom),
            .converted("aa")
        )
    }

    func testSameLayoutPairIsUnavailable() {
        let converter = KeyboardConverter(layouts: [Self.english])
        converter.fromLayout = Self.english
        converter.toLayout = Self.english

        XCTAssertFalse(converter.hasUsableLayoutPair)
        XCTAssertEqual(converter.conversion(for: "a"), .unavailable)
    }

    private func makeConverter(includeOption: Bool) -> KeyboardConverter {
        let converter = KeyboardConverter(layouts: [Self.english, Self.ukrainian])
        converter.fromLayout = Self.english
        converter.toLayout = Self.ukrainian
        converter.includeOptionModifierVariants = includeOption
        return converter
    }

    private static let plainA = KeyboardConverter.KeyStroke(keyCode: 0x00, modifiers: [])
    private static let shiftedA = KeyboardConverter.KeyStroke(keyCode: 0x00, modifiers: [.shift])
    private static let optionS = KeyboardConverter.KeyStroke(keyCode: 0x01, modifiers: [.option])
    private static let optionQuote = KeyboardConverter.KeyStroke(keyCode: 0x27, modifiers: [.option])

    private static let english = makeLayout(
        id: "english",
        name: "English",
        characters: [
            ("a", plainA),
            ("A", shiftedA),
            ("ß", optionS),
            ("æ", optionQuote),
        ]
    )

    private static let ukrainian = makeLayout(
        id: "ukrainian",
        name: "Ukrainian",
        characters: [
            ("ф", plainA),
            ("Ф", shiftedA),
            ("ы", optionS),
            ("э", optionQuote),
        ]
    )

    private static func makeLayout(
        id: String,
        name: String,
        characters: [(Character, KeyboardConverter.KeyStroke)]
    ) -> KeyboardConverter.Layout {
        var charToKey: [Character: KeyboardConverter.KeyStroke] = [:]
        var keyStrokeToChar: [KeyboardConverter.KeyStroke: Character] = [:]

        for (character, keyStroke) in characters {
            charToKey[character] = keyStroke
            keyStrokeToChar[keyStroke] = character
        }

        return KeyboardConverter.Layout(
            id: id,
            name: name,
            charToKey: charToKey,
            keyStrokeToChar: keyStrokeToChar
        )
    }
}
