#!/bin/bash
set -e

APP_NAME="Retype"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
MODULE_CACHE="/tmp/retype-module-cache"

echo "Building ${APP_NAME}..."

rm -rf "${BUILD_DIR}"

mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

swiftc \
    -swift-version 5 \
    -module-cache-path "${MODULE_CACHE}" \
    -target "arm64-apple-macosx26.0" \
    Sources/main.swift \
    Sources/KeyboardConverter.swift \
    Sources/ShortcutManager.swift \
    Sources/AppDelegate.swift \
    Sources/SettingsWindowController.swift \
    -o "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" \
    -framework Cocoa \
    -framework Carbon \
    -framework ServiceManagement \
    -suppress-warnings

cp Resources/Info.plist "${APP_BUNDLE}/Contents/"
cp Resources/Retype.icns "${APP_BUNDLE}/Contents/Resources/"

codesign --force --sign - "${APP_BUNDLE}"

echo ""
echo "Build successful: ${APP_BUNDLE}"
echo ""
echo "To run:     open ${APP_BUNDLE}"
echo "To install: cp -r ${APP_BUNDLE} /Applications/"
