# Retype

macOS menu bar app that converts mistyped text between keyboard layouts.

Typed `ghbdtn` when you meant `привіт`? Select the text, double-press the trigger key — Retype swaps it instantly.

Works with any two keyboard layouts installed on your Mac.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Install

```bash
brew tap bobjer/retype
brew install --cask retype
```

Homebrew installs a prebuilt app bundle. Installing Retype this way does not require Xcode or Xcode Command Line Tools.

> First launch: go to **System Settings → Privacy & Security → Accessibility** and enable Retype.

## Usage

1. Type text in the wrong layout
2. Select it
3. Double-press the trigger key (default: **Left Shift**)

The text is replaced with the correct layout version automatically.

## Settings

Click the **RT** icon in the menu bar → **Settings**:

- **From / To layout** — two distinct layouts to convert between
- **Direction** — safe automatic detection, or an explicit direction for mixed text
- **Convert Option/Alt characters** — include characters typed with Option/Alt, enabled by default
- **Trigger key** — Left Shift, Right Shift, Left Control, Left Option, Left Command
- **Timeout** — how fast the double-press must be (0.2–1.0 s)
- **Cmd+A+A** — alternative trigger: hold ⌘, press A twice (selects all + converts)
- **Launch at login** — start Retype automatically

The Settings window includes a sample-text preview. Automatic mode leaves ambiguous or mixed-layout text unchanged instead of guessing.

## Requirements

- macOS 13 Ventura or later
- Accessibility permission (for receiving global keyboard events and replacing selected text)

## How it works

Retype uses global keyboard events to detect the double-press, copies the selected text via `Cmd+C`, remaps each character between the two layouts using the system's own keyboard layout data (UCKeyTranslate), then pastes the result back. Clipboard restoration uses a Retype-owned transaction marker, so a newer clipboard item from you or another app is never overwritten.

No text is sent anywhere — everything happens locally.

## Build from source

```bash
git clone https://github.com/bobjer/retype
cd retype
./build.sh
open build/Retype.app
```

Requires Xcode Command Line Tools (`xcode-select --install`).

Run unit tests with full Xcode available:

```bash
./test.sh
```

Run the optional installed-layout smoke test with:

```bash
./smoke-system-layouts.sh
```

## Packaging

`./package.sh` is the release command. It requires a Developer ID Application certificate and a `notarytool` keychain profile, then signs, notarizes, staples, and packages the app. It renders the Cask only after calculating the SHA-256 of the final notarized zip.

Packaging requirements for the developer machine:

- Xcode command-line tools
- `SIGNING_IDENTITY` with a Developer ID Application certificate
- `NOTARY_PROFILE` stored with `xcrun notarytool store-credentials`

The tag workflow publishes `v<version>` and updates `bobjer/homebrew-retype`. It requires the Apple signing/notarization secrets and `HOMEBREW_TAP_TOKEN`; the workflow fails explicitly when they are missing.

## Troubleshooting

**Hotkey does nothing after granting Accessibility permission**

macOS ties accessibility permissions to the app's code signature. After rebuilding or reinstalling, the old entry can go stale. Reset it:

```bash
tccutil reset Accessibility com.retype.app
```

Then relaunch Retype and grant permission again when prompted.

## License

Creative Commons CC0 1.0 Universal
