# Clicky — native macOS companion

The native macOS app that backs `clicky-ai-plugin`'s `install` /
`launch` subcommands. Built from pure SwiftPM + `codesign` with no
Xcode GUI required — just `make build` and go.

## Status: v0.1 (minimal)

This first cut verifies the end-to-end Claude CLI transport. It ships:

- A menu-bar status item (⌘-click to toggle the panel).
- A floating panel that captures your primary display and asks Claude.
- Streaming text answers via `claude` CLI (Pencil pattern — no API key
  required, uses your Claude Code subscription).
- Session persistence across app launches via `--resume`.
- An "Install Claude Code" banner when the CLI is missing.

Coming in v0.2+: push-to-talk hotkey, multi-display capture, blue
cursor overlay with `[POINT:x,y:label]` animation, TTS (`say` / optional
VibeVoice).

## Prerequisites

- macOS 14.2+
- Xcode Command Line Tools: `xcode-select --install`
- `claude` CLI — install from <https://claude.com/claude-code> and
  sign in once (`claude` in a Terminal).

No Xcode GUI, no `xcodebuild`, no `.xcodeproj`. SwiftPM + standard
macOS tools only.

## Build & run

```bash
# inside clicky-ai-plugin/native/
make build   # release build, wrap into Clicky.app, adhoc-sign
make run     # build + launch
make clean   # remove .build, Clicky.app, DMGs

# produce a distributable DMG (adhoc-signed; notarization is CI-only)
make dmg
```

On first launch the app will ask for **Screen Recording** permission.
Grant it, reopen the panel, type a question, hit **Test Claude**.

## Layout

```
native/
├── Package.swift                 # SwiftPM manifest (macOS 14+, single exe)
├── Info.plist                    # LSUIElement, usage descriptions, bundle id
├── Clicky.entitlements           # sandbox=off (needs Process.run), mic + screencap
├── Makefile                      # build / run / bundle / dmg / clean
├── README.md
└── Sources/Clicky/
    ├── App.swift                 # @main + AppDelegate + NSStatusItem + NSPanel
    ├── ClickyViewModel.swift     # panel state, CLI probe, turn runner
    ├── PanelView.swift           # SwiftUI panel content + install banner
    ├── ScreenCapture.swift       # ScreenCaptureKit → JPEG + dims
    ├── ClaudeCLIRunner.swift     # spawn `claude` + stream-json I/O
    └── SessionPersistence.swift  # ~/Library/Application Support/Clicky/last-session.json
```

## How the Claude call works

Flag combo (validated via live experiments):

```
claude --print --verbose
  --output-format stream-json --input-format stream-json
  --include-partial-messages
  --model claude-sonnet-4-6
  --system-prompt "<clicky persona>"
  --setting-sources ""
  --disable-slash-commands
  --strict-mcp-config --mcp-config '{"mcpServers":{}}'
  --permission-mode bypassPermissions
  --exclude-dynamic-system-prompt-sections
  --disallowedTools Task Bash Edit Read Write Glob Grep NotebookEdit WebFetch WebSearch Skill
  [--resume <sessionId>]
```

`--bare` is explicitly NOT used — it forbids OAuth/keychain reads and
would force an `ANTHROPIC_API_KEY`. Together the isolation flags trim
the user's CLAUDE.md, MCP servers, hooks, skills, and auto-memory so
spawn time is ~2 s and input tokens stay around 2 k.

On success, the app reads `session_id` from the init event and saves
it to `~/Library/Application Support/Clicky/last-session.json`. Next
launch resumes that session via `--resume`.

## Troubleshooting

- **"Install Claude Code" banner even though I have it.** The app looks
  in `$CLICKY_CLAUDE_BIN`, then `/opt/homebrew/bin/claude`,
  `/usr/local/bin/claude`, `~/.claude/local/claude`, `~/.local/bin/claude`,
  then `which claude`. If `claude` lives somewhere else, set
  `CLICKY_CLAUDE_BIN` before launching.
- **"Not logged in".** Run `claude` once in a terminal to sign in, then
  relaunch the app.
- **Screen Recording permission denied.** Open `System Settings →
  Privacy & Security → Screen Recording`, enable Clicky, restart the app.

## License

MIT. See ../LICENSE.
