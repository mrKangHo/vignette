cask "vignette" do
  version "0.1.1"
  sha256 "2b048e18523da4209232f1d2a9e8afc175863ab629f321d25751003973566da5"

  url "https://github.com/mrKangHo/vignette/releases/download/v#{version}/Vignette-#{version}.dmg"
  name "Vignette"
  desc "Menu bar app for per-display brightness and Movie Mode screen dimming"
  homepage "https://github.com/mrKangHo/vignette"

  depends_on macos: :ventura

  app "Vignette.app"

  zap trash: "~/Library/Preferences/com.mrkangho.Vignette.plist"

  caveats <<~EOS
    Vignette isn't signed with an Apple Developer ID, so Gatekeeper will
    block it on first launch.

    If macOS says Vignette.app "is damaged and can't be opened", clear the
    quarantine flag instead of trusting that message:

      xattr -cr /Applications/Vignette.app

    Then open it normally (or right-click/Control-click it in Finder and
    choose "Open" to accept the "unidentified developer" warning).
  EOS
end
