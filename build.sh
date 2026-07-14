#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

APP_NAME="Retype"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
VERSION="$(tr -d '[:space:]' < VERSION)"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

echo "Building ${APP_NAME} ${VERSION} (${BUILD_NUMBER})..."
swift build --configuration release --product "$APP_NAME"

BIN_DIR="$(swift build --configuration release --show-bin-path)"
rm -rf "$BUILD_DIR"
mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources"
cp "${BIN_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp Resources/Info.plist "${APP_BUNDLE}/Contents/"
cp Resources/Retype.icns "${APP_BUNDLE}/Contents/Resources/"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${APP_BUNDLE}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" "${APP_BUNDLE}/Contents/Info.plist"

codesign --force --sign - "$APP_BUNDLE"

echo "Build successful: ${APP_BUNDLE}"
