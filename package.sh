#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

VERSION="$(tr -d '[:space:]' < VERSION)"
ZIP_NAME="Retype-${VERSION}.zip"
APP_BUNDLE="build/Retype.app"
FINAL_ZIP="build/${ZIP_NAME}"

./build.sh

rm -f "$FINAL_ZIP"
ditto -c -k --keepParent "$APP_BUNDLE" "$FINAL_ZIP"

echo "Local package: $FINAL_ZIP"
echo "Run it locally with: open $APP_BUNDLE"
