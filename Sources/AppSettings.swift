import Foundation

struct AppSettings {
    enum Key {
        static let fromLayoutID = "fromLayoutID"
        static let toLayoutID = "toLayoutID"
        static let triggerKeyRaw = "triggerKeyRaw"
        static let doublePressTimeout = "doublePressTimeout"
        static let cmdDoubleAEnabled = "cmdDoubleAEnabled"
        static let switchLayoutAfterConversion = "switchLayoutAfterConversion"
        static let includeOptionModifierVariants = "includeOptionModifierVariants"
        static let conversionDirection = "conversionDirection"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var fromLayoutID: String? {
        get { defaults.string(forKey: Key.fromLayoutID) }
        nonmutating set { defaults.set(newValue, forKey: Key.fromLayoutID) }
    }

    var toLayoutID: String? {
        get { defaults.string(forKey: Key.toLayoutID) }
        nonmutating set { defaults.set(newValue, forKey: Key.toLayoutID) }
    }

    var triggerKeyRaw: Int? {
        get { defaults.value(forKey: Key.triggerKeyRaw) as? Int }
        nonmutating set { defaults.set(newValue, forKey: Key.triggerKeyRaw) }
    }

    var doublePressTimeout: Double? {
        get {
            let value = defaults.double(forKey: Key.doublePressTimeout)
            return value > 0 ? value : nil
        }
        nonmutating set { defaults.set(newValue, forKey: Key.doublePressTimeout) }
    }

    var cmdDoubleAEnabled: Bool {
        get { defaults.bool(forKey: Key.cmdDoubleAEnabled) }
        nonmutating set { defaults.set(newValue, forKey: Key.cmdDoubleAEnabled) }
    }

    var switchLayoutAfterConversion: Bool {
        get { defaults.bool(forKey: Key.switchLayoutAfterConversion) }
        nonmutating set { defaults.set(newValue, forKey: Key.switchLayoutAfterConversion) }
    }

    var includeOptionModifierVariants: Bool {
        get {
            if defaults.object(forKey: Key.includeOptionModifierVariants) == nil {
                return true
            }
            return defaults.bool(forKey: Key.includeOptionModifierVariants)
        }
        nonmutating set { defaults.set(newValue, forKey: Key.includeOptionModifierVariants) }
    }

    var conversionDirection: KeyboardConverter.ConversionDirection {
        get {
            guard
                let rawValue = defaults.string(forKey: Key.conversionDirection),
                let direction = KeyboardConverter.ConversionDirection(rawValue: rawValue)
            else { return .automatic }
            return direction
        }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.conversionDirection) }
    }
}
