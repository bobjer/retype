@testable import Retype
import XCTest

final class AppSettingsTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var settings: AppSettings!

    override func setUp() {
        super.setUp()
        suiteName = "RetypeTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        settings = AppSettings(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        settings = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testIncludeOptionModifierVariantsDefaultsToTrue() {
        XCTAssertTrue(settings.includeOptionModifierVariants)
    }

    func testIncludeOptionModifierVariantsPersistsFalse() {
        settings.includeOptionModifierVariants = false

        XCTAssertFalse(settings.includeOptionModifierVariants)
    }

    func testDoublePressTimeoutIgnoresMissingValue() {
        XCTAssertNil(settings.doublePressTimeout)
    }

    func testLayoutIDsPersist() {
        settings.fromLayoutID = "from"
        settings.toLayoutID = "to"

        XCTAssertEqual(settings.fromLayoutID, "from")
        XCTAssertEqual(settings.toLayoutID, "to")
    }

    func testConversionDirectionDefaultsToSafeAutomaticMode() {
        XCTAssertEqual(settings.conversionDirection, .automatic)
    }

    func testConversionDirectionPersists() {
        settings.conversionDirection = .toFrom

        XCTAssertEqual(settings.conversionDirection, .toFrom)
    }
}
