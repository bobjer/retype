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

> First launch: go to **System Settings → Privacy & Security → Accessibility** and enable Retype.

## Usage

1. Type text in the wrong layout
2. Select it
3. Double-press the trigger key (default: **Left Shift**)

The text is replaced with the correct layout version automatically.

## Settings

Click the **RT** icon in the menu bar → **Settings**:

- **From / To layout** — which layouts to convert between
- **Trigger key** — Left Shift, Right Shift, Left Control, Left Option, Left Command
- **Timeout** — how fast the double-press must be (0.2–1.0 s)
- **Cmd+A+A** — alternative trigger: hold ⌘, press A twice (selects all + converts)
- **Launch at login** — start Retype automatically

## Requirements

- macOS 13 Ventura or later
- Accessibility permission (for reading keyboard input and clipboard)

## How it works

Retype uses macOS accessibility APIs to detect the double-press, copies the selected text via `Cmd+C`, remaps each character between the two layouts using the system's own keyboard layout data (UCKeyTranslate), then pastes the result back.

No text is sent anywhere — everything happens locally.

## Build from source

```bash
git clone https://github.com/bobjer/retype
cd retype
./build.sh
open build/Retype.app
```

Requires Xcode Command Line Tools (`xcode-select --install`).

## Troubleshooting

**Hotkey does nothing after granting Accessibility permission**

macOS ties accessibility permissions to the app's code signature. After rebuilding or reinstalling, the old entry can go stale. Reset it:

```bash
tccutil reset Accessibility com.retype.app
```

Then relaunch Retype and grant permission again when prompted.

## License

Creative Commons CC0 1.0 Universal
