# clicky-ai-plugin + Clicky app migration

## Problem Statement

How might we give Claude Code users Clicky's screen-aware, cursor-pointing
companion immediately — and graduate them to the full native macOS app —
without shipping an Anthropic API key (or any other third-party key)
anywhere in the product?

## Recommended Direction (two tracks, shippable independently)

### Track A — `clicky-ai-plugin` (Claude Code plugin, ships first)

A lean plugin that (a) teaches Claude the Clicky persona + POINT protocol
via a single `skills/openclicky/SKILL.md`, and (b) ships a bun/TypeScript
dispatcher (`scripts/main.ts`) with zero npm dependencies. Structure,
invocation pattern, and runtime ethos copy
`/Users/jdnichollsc/dev/ai/notebooklm-ai-plugin` verbatim:
`#!/usr/bin/env -S npx -y bun` shebang, invoked via
`npx -y bun scripts/main.ts <subcommand>`.

Subcommands:

- `install` — headline. Try `brew install --cask clicky-ai` first; fall
  back to GitHub Releases DMG (notarized, SHA256-verified) if cask
  missing; else manual URL. Mirrors `bun`/`uv`/`rustup` install ladders.
- `launch` — detect installed app at `/Applications/Clicky.app` (plus
  legacy `leanring-buddy.app` and Xcode DerivedData for dev builds), spawn
  via `open -a`. `CLICKY_APP_PATH` env override.
- `capture` — multi-display screenshot via `screencapture -x`, cap width
  1280px, emit JSON manifest `{screens: [{index, label, path, widthPx,
  heightPx, isCursorScreen}]}`. Skill instructs Claude to Read the JPEGs.
- `point` — parse `--x --y --label --screen`, print human-readable pointer
  line to stdout. Terminal only in v1 (no NSPanel overlay without the
  native app).
- `speak` — default macOS `say`; optional VibeVoice local HTTP server via
  `CLICKY_VIBEVOICE_URL`; optional ElevenLabs via
  `CLICKY_ELEVENLABS_API_KEY`. Off by default unless the user opts in.
- `status` — report Screen Recording / Accessibility permission state
  without re-prompting; list whether native app is installed, claude CLI
  is on PATH, optional voice servers are reachable.
- `help` — usage.

State lives in `~/Library/Application Support/clicky-ai/` (matches
notebooklm pattern). Single `SKILL.md`, no `references/` folder, no
`commands/` dir (skill triggers cover `/clicky` invocation). No
`ANTHROPIC_API_KEY`.

### Track B — Clicky macOS app migration

Replace the Cloudflare Worker (`worker/src/index.ts`) entirely by
spawning the user's `claude` CLI from Swift (Pencil pattern). The Worker
is retired; all three secrets (`ANTHROPIC_API_KEY`, `ELEVENLABS_API_KEY`,
`ASSEMBLYAI_API_KEY`) disappear from the product.

- **Claude (`/chat`)** → new `ClaudeCLIRunner.swift`: `Foundation.Process`
  spawns `claude --print --output-format stream-json --input-format
  stream-json --model <model> --append-system-prompt <clicky prompt>`,
  streams stdin messages (text + base64 image) and parses stdout events.
  Finds `claude` via `$PATH`, `/opt/homebrew/bin`, `/usr/local/bin`,
  `~/.claude/local`. Missing-CLI onboarding routes users to
  `claude.com/claude-code`. `ClaudeAPI.swift` keeps its public interface;
  only the transport changes.
- **ElevenLabs TTS (`/tts`)** → macOS `AVSpeechSynthesizer` default (the
  Swift app already has this as a fallback); optional VibeVoice local
  server if `CLICKY_VIBEVOICE_URL` is set; optional ElevenLabs only if
  the user enters their own key in Keychain. `ElevenLabsTTSClient.swift`
  simplified or removed.
- **AssemblyAI (`/transcribe-token`)** → Apple Speech (already a
  fallback provider in `AppleSpeechTranscriptionProvider.swift`). Default
  changes to `AppleSpeech`. `AssemblyAIStreamingTranscriptionProvider.swift`
  kept behind an opt-in setting; users supply their own key directly.
- **Delete** `worker/`, `wrangler.toml`, all related Worker deployment
  scripts and docs. Update README.

## Key Assumptions to Validate

- [ ] Clicky's App Sandbox config allows `Process.run()` to spawn `claude`.
      Inspect `leanring-buddy.entitlements`; plan `com.apple.security.inherit`
      or temporary-exception entitlement if sandbox is on.
- [ ] `claude --output-format stream-json --input-format stream-json`
      accepts base64 images in user messages. One-shot verification test.
- [ ] `claude` binary is findable via standard PATHs for ≥90% of users;
      the "install Claude Code" nudge handles the rest.
- [ ] Apple Speech accuracy + latency is acceptable vs AssemblyAI for
      short push-to-talk bursts in English.
- [ ] A Homebrew cask named `clicky-ai` can be published upstream (either
      homebrew-cask directly or a personal tap).
- [ ] Native app launched by the plugin still responds to its own global
      hotkey once running — no plugin↔app IPC needed in v1.

## MVP Scope

**Track A — IN:**

- `.claude-plugin/{plugin.json, marketplace.json}`
- `skills/openclicky/SKILL.md` (persona, POINT protocol, when/how to call
  scripts, ~300–400 lines, self-contained)
- `scripts/{main.ts, paths.ts, types.ts, installer.ts, launch-app.ts,
  screenshot.ts, point.ts, speak.ts}`
- Graceful degradation when native app is absent (terminal POINT,
  `say` TTS)
- `README.md`, `LICENSE` (MIT), `.gitignore`

**Track A — OUT:**

- Non-macOS platforms
- OmniParser UI grounding (v2+, AGPL risk + 2–5s latency)
- Custom pixel-level cursor overlay without the native app (v2 Swift
  helper)
- MCP server (v2+)
- Separate `commands/` directory
- PersonaPlex / Moshi-style conversation voice (evaluated, rejected —
  no Apple Silicon GPU, overkill for short sentences)

**Track B — IN:**

- `ClaudeCLIRunner.swift` (new)
- `ClaudeAPI.swift` swap to CLI transport
- Missing-CLI UX in menu bar panel
- TTS default flip to `AVSpeechSynthesizer`
- STT default flip to Apple Speech
- Worker directory deletion, Info.plist/AppBundleConfiguration cleanup,
  README rewrite

**Track B — OUT:**

- Full IPC bridge between plugin and native app (v2)
- Voice cloning
- Session resume via `claude --resume <session_id>` (v2 nice-to-have)

## Not Doing (and Why)

- **No ANTHROPIC_API_KEY anywhere** — plugin runs inside Claude Code
  (host is the brain); native app spawns the user's Claude Code CLI.
- **No Cloudflare Worker** — retired along with all three of its secrets.
- **No OmniParser** — AGPL YOLO weights taint commercial distribution;
  2–5s latency breaks real-time streaming.
- **No A2UI** — opposite of what we need (agent-→-UI rendering, not
  UI introspection).
- **No PersonaPlex / Moshi** — no Apple Silicon GPU path, WebSocket
  full-duplex model is overkill for 1-sentence feedback.
- **No bundled `.app` inside the plugin repo** — bloats, breaks
  independent app updates, forces notarization into plugin release loop.
- **No `commands/` directory** — skill frontmatter triggers handle
  `/clicky …` invocations; avoids duplicating discovery surfaces.
- **No cross-platform in v1** — Linux/Windows screen capture + native app
  packaging is a rabbit hole.

## Open Questions (to resolve in /spec-driven-development)

- **Sandbox:** is `leanring-buddy.entitlements` currently sandboxed? If
  so, what entitlements need to be added to spawn `claude` safely? If
  Process.run() is blocked outright, fall back to a helper daemon?
- **Model selection:** does the menu bar panel's model picker
  (`selectedClaudeModel` UserDefault: `claude-sonnet-4-6` /
  `claude-opus-4-6`) still make sense when the CLI drives
  selection? Likely yes via `--model <id>` flag.
- **`claude` binary version pinning:** detect version, refuse if older
  than required for stream-json? Probe on first launch.
- **Cask namespace:** publish to `homebrew-cask` directly or a personal
  tap `jdnichollsc/tap/clicky-ai`? Tap is faster; upstream is more
  legitimate.
- **GitHub Releases naming:** `Clicky-<version>-arm64.dmg` and
  `Clicky-<version>-arm64.dmg.sha256`? Confirm.
- **Session persistence:** ship v1 without `--resume`, or include
  conversation continuity via `claude --resume <sessionId>` from day one?
