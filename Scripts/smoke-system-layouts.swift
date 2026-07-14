import Foundation

@main
struct SystemLayoutSmokeTest {
    static func main() {
        let converter = KeyboardConverter()
        let layouts = converter.installedLayouts

        guard let ukrainian = layouts.first(where: {
            $0.id.localizedCaseInsensitiveContains("Ukrainian") ||
            $0.name.localizedCaseInsensitiveContains("Ukrainian")
        }) else {
            print("Skipped: Ukrainian layout is not installed")
            exit(0)
        }

        // Pin to US/ABC: ß æ -> Option+s / Option+' is only stable on this layout.
        // Other latin layouts (e.g. German) place these on different keys.
        guard let latin = layouts.first(where: {
            $0.id.localizedCaseInsensitiveContains("ABC") ||
            $0.id.localizedCaseInsensitiveContains("US")
        }) else {
            print("Skipped: US/ABC layout is not installed")
            exit(0)
        }

        converter.fromLayout = latin
        converter.toLayout = ukrainian

        converter.includeOptionModifierVariants = true
        let enabled = converter.convert("ß æ")
        guard enabled == "ы э" else {
            fputs("Failed: enabled Option/Alt conversion expected 'ы э', got '\(enabled)'\n", stderr)
            exit(1)
        }

        converter.includeOptionModifierVariants = false
        let disabled = converter.convert("ß æ")
        guard disabled == "ß æ" else {
            fputs("Failed: disabled Option/Alt conversion expected 'ß æ', got '\(disabled)'\n", stderr)
            exit(1)
        }

        print("System layout smoke test passed with \(latin.name) -> \(ukrainian.name)")
    }
}
