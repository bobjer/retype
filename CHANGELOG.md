# Changelog

## Unreleased

### Added
- Configurable Option/Alt character conversion, enabled by default
- SwiftPM package metadata, XCTest unit tests, and macOS CI
- Optional system-layout smoke test for installed keyboard layouts

### Changed
- Centralized app settings in one `UserDefaults` wrapper
- Build/package scripts now read app version from `VERSION`

## [1.1] — 2026-02-21

### Added
- **Switch layout after conversion** — optional setting to automatically switch the system keyboard layout to match the converted text
- Bottom padding in Settings window

## [1.0] — 2026-02-21

Initial release.

- Menu bar app, no Dock icon
- Converts selected text between any two installed keyboard layouts
- Auto-detects conversion direction
- Configurable trigger key: Left Shift, Right Shift, Left Control, Left Option, Left Command
- Configurable double-press timeout
- ⌘A+A trigger — hold ⌘, press A twice to select all and convert
- Launch at login
- Installs via Homebrew: `brew tap bobjer/retype && brew install --cask retype`
