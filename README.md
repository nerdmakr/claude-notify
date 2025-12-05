# CNotify 🔔

A beautiful macOS notification app for Claude Code completion alerts.

![CNotify](https://img.shields.io/badge/platform-macOS-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## Features

- 🎨 **Beautiful UI** - Modern design with Soft Peach color theme
- ⏱️ **Session Tracking** - Records task start/end times and duration
- 🤖 **Model Info** - Shows which Claude model was used (Opus/Sonnet/Haiku)
- 🔔 **Smart Notifications** - Auto-dismiss after 10 seconds
- 📂 **Quick Access** - Click to open project in Finder, VSCode, or Cursor
- 🔊 **Sound Options** - Multiple notification sounds (Pop, Purr, Tink, Glass, etc.)
- 💾 **Persistent History** - All notifications saved to local storage
- ✨ **Read Status** - Track which notifications you've reviewed

## Installation

### Homebrew (Recommended)

```bash
brew tap nerdmakr/tap
brew install --cask cnotify
```

### Manual Installation

1. Download the latest release from [Releases](https://github.com/nerdmakr/cnotify/releases)
2. Unzip and move `CNotify.app` to `/Applications`
3. Run the app

## Usage

### 1. Start CNotify

Launch the app - it runs in your menu bar.

### 2. Configure Claude Code Hook

Add this to your Claude Code configuration to send notifications:

```bash
# ~/.claude/notify-hook.sh
#!/bin/bash
input=$(cat)
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')

user_message="Task completed"
start_time=""
end_time=""
model=""

if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    user_message=$(grep '"type":"user"' "$transcript_path" | \
        jq -r 'select(.message.content | type == "string") | .message.content' 2>/dev/null | \
        tail -1 | cut -c1-100)

    start_time=$(grep '"type":"user"' "$transcript_path" | tail -1 | jq -r '.timestamp // empty' 2>/dev/null)
    end_time=$(grep '"type":"assistant"' "$transcript_path" | tail -1 | jq -r '.timestamp // empty' 2>/dev/null)
    model=$(grep '"type":"assistant"' "$transcript_path" | tail -1 | jq -r '.message.model // empty' 2>/dev/null)
fi

if [ -z "$user_message" ]; then
    user_message="Task completed"
fi

user_message=$(echo "$user_message" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ')

curl -s -X POST http://127.0.0.1:19280/notify \
    -H 'Content-Type: application/json' \
    -d "{\"project\": \"$PWD\", \"message\": \"$user_message\", \"startTime\": \"$start_time\", \"endTime\": \"$end_time\", \"model\": \"$model\"}"
```

Make it executable:
```bash
chmod +x ~/.claude/notify-hook.sh
```

### 3. Test

Run the test notification from the menu bar:
```
Menu Bar Icon → Test Notification
```

## Menu Bar Options

- **Show History** - View all notification history
- **Test Notification** - Send a test notification
- **Open With** - Choose default tool (Finder, VSCode, Cursor)
- **Sound** - Choose notification sound or disable
- **Quit** - Close the app

## Configuration

### Default Tool

Choose which app opens when you click a notification:
- **Finder** - Opens project folder in Finder
- **VSCode** - Opens project in Visual Studio Code
- **Cursor** - Opens project in Cursor editor
- **Antigravity** - Easter egg 😉

### Notification Sounds

- Pop (default)
- Purr
- Tink
- Glass
- Ping
- Submarine
- Funk
- Hero
- None

## Development

### Requirements

- macOS 13.0+
- Swift 5.9+
- Xcode 15.0+

### Build

```bash
swift build -c release
```

### Run

```bash
swift run
```

## API

CNotify runs a local HTTP server on `http://127.0.0.1:19280`

### POST /notify

Send a notification:

```json
{
  "project": "/path/to/project",
  "message": "Task completed",
  "startTime": "2025-12-04T12:00:00.000Z",
  "endTime": "2025-12-04T12:05:00.000Z",
  "model": "claude-sonnet-4-5-20250929"
}
```

### GET /health

Health check endpoint - returns `ok`

## License

MIT License - see [LICENSE](LICENSE) file for details

## Credits

Created by [nerdmakr](https://github.com/nerdmakr)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
