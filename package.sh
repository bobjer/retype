#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to a Developer ID Application certificate.}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a notarytool keychain profile.}"

VERSION="$(tr -d '[:space:]' < VERSION)"
ZIP_NAME="Retype-${VERSION}.zip"
APP_BUNDLE="build/Retype.app"
NOTARY_ZIP="build/Retype-${VERSION}-notary.zip"
FINAL_ZIP="build/${ZIP_NAME}"
CASK_OUTPUT="${CASK_OUTPUT:-build/retype.rb}"

RETYPE_RELEASE=1 ./build.sh

rm -f "$NOTARY_ZIP" "$FINAL_ZIP"
ditto -c -k --keepParent "$APP_BUNDLE" "$NOTARY_ZIP"
xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP_BUNDLE"
spctl --assess --type execute --verbose=4 "$APP_BUNDLE"

ditto -c -k --keepParent "$APP_BUNDLE" "$FINAL_ZIP"
SHA256="$(shasum -a 256 "$FINAL_ZIP" | awk '{print $1}')"
sed \
    -e "s/@VERSION@/${VERSION}/g" \
    -e "s/@SHA256@/${SHA256}/g" \
    Casks/retype.rb.template > "$CASK_OUTPUT"

echo "Notarized package: $FINAL_ZIP"
echo "Cask: $CASK_OUTPUT"
echo "SHA256: $SHA256"
