cask "claude-notify" do
  version "0.1.0"
  sha256 "3bd6a954baa0958063de7f8e71c0f0a062894bfe0d1e52ce419ed055ce55a004"

  url "https://github.com/nerdmakr/claude-notify/releases/download/v#{version}/ClaudeNotify.zip"
  name "Claude Notify"
  desc "macOS notification app for Claude Code completion alerts"
  homepage "https://github.com/nerdmakr/claude-notify"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "ClaudeNotify.app"

  zap trash: [
    "~/Library/Application Support/ClaudeNotify",
    "~/Library/Preferences/com.claude.notify.plist",
  ]
end
