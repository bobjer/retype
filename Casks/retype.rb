cask "retype" do
  version "1.0"
  sha256 "fe00e262a91dae5b23368749efc1cd91863c461e1b436105f7ff14dcdfcd31f4"

  url "https://github.com/bobjer/retype/releases/download/v#{version}/Retype-#{version}.zip"
  name "Retype"
  desc "Convert mistyped text between keyboard layouts with a hotkey"
  homepage "https://github.com/bobjer/retype"

  depends_on macos: ">= :ventura"

  app "Retype.app"

  # Remove Gatekeeper quarantine — app is ad-hoc signed (no Apple Developer ID)
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-r", "-d", "com.apple.quarantine", "#{appdir}/Retype.app"],
                   sudo: false
  end
end
