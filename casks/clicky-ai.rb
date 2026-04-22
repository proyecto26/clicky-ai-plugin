# Dormant until the project is enrolled in the Apple Developer Program.
# Without a Developer ID Application certificate and notarization, a
# cask install would leave Clicky.app Gatekeeper-quarantined — users
# would hit "Clicky can't be opened" on first launch, which is worse UX
# than the source-install path (git clone + make install) this formula
# is intended to replace.
#
# To activate this formula, complete steps 1-4 in docs/plan/release-setup.md
# (Apple Developer Program enrolment → Developer ID cert → 5 GH secrets →
# seed the tap repo). The release workflow will then populate version and
# sha256 automatically on each tag push.

cask "clicky-ai" do
  version "0.1.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/proyecto26/clicky-ai-plugin/releases/download/v#{version}/Clicky-#{version}-arm64.dmg"
  name "Clicky"
  desc "Friendly, screen-aware Claude Code companion for macOS"
  homepage "https://github.com/proyecto26/clicky-ai-plugin"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  app "Clicky.app"

  zap trash: [
    "~/Library/Application Support/Clicky",
    "~/Library/Application Support/clicky-ai",
    "~/Library/Preferences/com.proyecto26.clicky.plist",
    "~/Library/Caches/com.proyecto26.clicky",
    "~/Library/Logs/com.proyecto26.clicky",
  ]
end
