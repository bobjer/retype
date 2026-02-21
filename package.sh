#!/bin/bash
set -e

VERSION="1.1"
ZIP_NAME="Retype-${VERSION}.zip"
TAP_NAME="local/retype"
TAP_REPO_DIR="$(brew --repository)/Library/Taps/local/homebrew-retype"
PROJECT_DIR="$(pwd)"

./build.sh

echo ""
echo "Packaging..."

(cd build && rm -f "${ZIP_NAME}" && zip -qr "${ZIP_NAME}" "Retype.app")

SHA=$(shasum -a 256 "build/${ZIP_NAME}" | awk '{print $1}')
FULL_PATH="${PROJECT_DIR}/build/${ZIP_NAME}"

mkdir -p Casks
cat > Casks/retype.rb << CASK
cask "retype" do
  version "${VERSION}"
  sha256 "${SHA}"

  url "file://${FULL_PATH}"
  name "Retype"
  desc "Convert mistyped text between keyboard layouts with a hotkey"
  homepage "https://github.com/dmytroblankovskyi/retype"

  depends_on macos: ">= :ventura"

  app "Retype.app"

  # Remove Gatekeeper quarantine — app is ad-hoc signed (no Apple Developer ID)
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-r", "-d", "com.apple.quarantine", "#{appdir}/Retype.app"],
                   sudo: false
  end
end
CASK

if [ ! -d "${TAP_REPO_DIR}" ]; then
    echo "Creating local tap '${TAP_NAME}'..."
    brew tap-new "${TAP_NAME}"
fi

mkdir -p "${TAP_REPO_DIR}/Casks"
cp Casks/retype.rb "${TAP_REPO_DIR}/Casks/retype.rb"

BREW_CACHE="$(brew --cache)/downloads"
rm -f "${BREW_CACHE}/"*"Retype-"*".zip" 2>/dev/null || true

echo ""
echo "Package: build/${ZIP_NAME}"
echo "SHA256:  ${SHA}"
echo ""
echo "Install:   brew install --cask --no-quarantine ${TAP_NAME}/retype"
echo "Update:    ./package.sh && brew reinstall --cask --no-quarantine retype"
echo "Uninstall: brew uninstall --cask retype"
