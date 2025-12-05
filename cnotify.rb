cask "cnotify" do
  version "0.1.0"
  sha256 "5ebe84be78983c2b026e2bb02d420ccf00110338826460b9d61ec8f891f2e37f"

  url "https://github.com/nerdmakr/claude-notify/releases/download/v#{version}/CNotify.zip"
  name "CNotify"
  desc "macOS notification app for Claude Code completion alerts"
  homepage "https://github.com/nerdmakr/claude-notify"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "CNotify.app"

  zap trash: [
    "~/Library/Application Support/CNotify",
    "~/Library/Preferences/com.cnotify.app.plist",
  ]
end
