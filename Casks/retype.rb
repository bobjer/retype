cask "retype" do
  version "1.1"
  sha256 "db8c8f788082b39e0e11086fcf83c5cdc68bb4aaa3a66b78e339587129d206c2"

  url "https://github.com/bobjer/retype/releases/download/v#{version}/Retype-#{version}.zip"
  name "Retype"
  desc "Convert mistyped text between keyboard layouts with a hotkey"
  homepage "https://github.com/bobjer/retype"

  depends_on arch: :arm64
  depends_on macos: ">= :tahoe"

  app "Retype.app"

  # Remove Gatekeeper quarantine — app is ad-hoc signed (no Apple Developer ID)
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-r", "-d", "com.apple.quarantine", "#{appdir}/Retype.app"],
                   sudo: false
  end
end
