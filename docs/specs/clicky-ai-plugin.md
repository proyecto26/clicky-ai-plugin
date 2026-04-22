# Spec: clicky-ai (plugin + Swift app migration)

Source: [one-pager](../ideas/clicky-ai-plugin.md).

## Objective

Ship a Claude Code plugin (`clicky-ai-plugin`) that gives any Claude Code
user Clicky's screen-aware companion immediately, and migrate the native
macOS app (`/Users/jdnichollsc/dev/ai/clicky/clicky`) off its Cloudflare
Worker + Anthropic-API-Key architecture onto the user's local `claude`
CLI (Pencil pattern). The Worker is deleted; all three of its secrets
(`ANTHROPIC_API_KEY`, `ELEVENLABS_API_KEY`, `ASSEMBLYAI_API_KEY`) go with
it.

Success = a Claude Code user can `/clicky`-style ask Claude for visual
screen help without installing anything native, *and* one command
(`install`) upgrades them to the full voice+overlay native app that now
runs off their own Claude Code subscription.

## Tech Stack

| Layer | Choice | Rationale |
|---|---|---|
| Plugin runtime | `bun` via `#!/usr/bin/env -S npx -y bun` | No prerequisites, matches notebooklm-ai-plugin |
| Plugin language | TypeScript | No compile step under bun |
| Plugin deps | Zero npm packages | Node built-ins only (`node:fs`, `node:child_process`, `node:net`, `node:path`, `node:os`) |
| App language | Swift 5.9+, SwiftUI + AppKit bridging | Unchanged |
| App LLM transport | `Foundation.Process` spawning `claude` CLI | Pencil pattern |
| Model selector | `claude-sonnet-4-6` / `claude-opus-4-6` | Passed via `--model` flag |
| TTS default | macOS `AVSpeechSynthesizer` (app) / `say` (plugin) | Zero-config |
| TTS optional | VibeVoice local HTTP server, ElevenLabs | Opt-in via env / Keychain |
| STT default | Apple Speech framework | Already a fallback provider |
| STT optional | AssemblyAI streaming | Opt-in via Keychain |

## Commands

### Plugin (from `/Users/jdnichollsc/dev/ai/clicky/clicky-ai-plugin`)

```
# Install the native macOS app
npx -y bun scripts/main.ts install [--force]

# Launch already-installed app
npx -y bun scripts/main.ts launch

# Capture multi-display screenshot (emits JSON manifest)
npx -y bun scripts/main.ts capture [--max-width 1280] [--output-dir PATH]

# Print a pointer line for a Claude POINT tag
npx -y bun scripts/main.ts point --x N --y N --label STR [--screen N]

# Speak a sentence aloud
npx -y bun scripts/main.ts speak "hello there" [--voice NAME] [--rate N] [--engine say|vibevoice|elevenlabs]

# Report environment health
npx -y bun scripts/main.ts status [--json]

# Usage
npx -y bun scripts/main.ts help
```

Every subcommand accepts global `--json` (machine-readable output) and
`-h`/`--help`. Exit codes: `0` success, `1` any error.

### Swift app (from `/Users/jdnichollsc/dev/ai/clicky/clicky`)

Unchanged for users (Xcode, Cmd+R). `xcodebuild` still forbidden by
CLAUDE.md. Worker build/deploy commands (`npx wrangler deploy`) are
deleted.

## Project Structure

### Plugin

```
clicky-ai-plugin/
├── .claude-plugin/
│   ├── plugin.json           # name, version, description, keywords
│   └── marketplace.json      # marketplace entry, $schema reference
├── skills/
│   └── clicky/
│       ├── SKILL.md          # persona + POINT + when-to-call, self-contained
│       └── scripts/
│           ├── main.ts       # #!/usr/bin/env -S npx -y bun (dispatcher)
│           ├── args.ts       # hand-rolled arg parser (notebooklm style)
│           ├── paths.ts      # resolveDataDir() → ~/Library/Application Support/clicky-ai/
│           ├── types.ts      # shared TypeScript interfaces
│           ├── installer.ts  # install subcommand
│           ├── launch-app.ts # launch subcommand
│           ├── screenshot.ts # capture subcommand
│           ├── point.ts      # point subcommand
│           ├── speak.ts      # speak subcommand
│           └── status.ts     # status subcommand
├── docs/
│   ├── ideas/clicky-ai-plugin.md
│   └── specs/clicky-ai-plugin.md
├── README.md
├── LICENSE                   # MIT
└── .gitignore                # ignore screenshots/, downloads/, config.local.json
```

### Swift app (diff-only view)

```
leanring-buddy/
  ClaudeCLIRunner.swift              # NEW
  ClaudeAPI.swift                    # MODIFIED — transport swap
  ElevenLabsTTSClient.swift          # MODIFIED — default off, opt-in via Keychain
  AppleSpeechTranscriptionProvider.swift  # unchanged (now default)
  AssemblyAIStreamingTranscriptionProvider.swift  # MODIFIED — opt-in via Keychain
  OpenAIAudioTranscriptionProvider.swift  # DELETED (v2 can re-add)
  AppBundleConfiguration.swift       # MODIFIED — drop Worker URL, add Keychain accessors
  Info.plist                         # MODIFIED — VoiceTranscriptionProvider default → appleSpeech
  leanring-buddy.entitlements        # POSSIBLY MODIFIED — add com.apple.security.inherit if sandboxed

worker/                              # DELETED
wrangler.toml                        # DELETED
```

## Interfaces & Data Contracts

### Plugin: `capture` subcommand output

Stdout (always JSON, regardless of `--json`):

```json
{
  "schemaVersion": 1,
  "capturedAt": "2026-04-19T14:30:00.000Z",
  "cursorScreenIndex": 1,
  "screens": [
    {
      "index": 1,
      "label": "screen1 (primary focus, 1280x831)",
      "path": "/Users/.../Library/Application Support/clicky-ai/screenshots/2026-04-19T143000-screen1.jpg",
      "widthPx": 1280,
      "heightPx": 831,
      "displayWidthPoints": 1512,
      "displayHeightPoints": 982,
      "isCursorScreen": true
    }
  ]
}
```

### Plugin: `point` subcommand output

Text mode (default):
```
→ "color inspector" at (1100, 42) on screen 1
```

JSON mode (`--json`):
```json
{"label": "color inspector", "x": 1100, "y": 42, "screen": 1}
```

### Plugin: `status` subcommand output

```json
{
  "platform": "darwin",
  "arch": "arm64",
  "permissions": {
    "screenRecording": "granted" | "denied" | "unknown",
    "accessibility": "granted" | "denied" | "unknown"
  },
  "nativeApp": {
    "installed": true,
    "path": "/Applications/Clicky.app",
    "version": "0.1.0"
  },
  "claudeCLI": {
    "installed": true,
    "path": "/opt/homebrew/bin/claude",
    "version": "1.2.3"
  },
  "voice": {
    "say": true,
    "vibevoice": {"configured": false, "url": null, "reachable": false},
    "elevenlabs": {"configured": false}
  },
  "dataDir": "/Users/.../Library/Application Support/clicky-ai"
}
```

### Plugin: `install` subcommand flow

```
Detect app → already installed? exit 0
          ↓ no
Try `brew --version` → brew available? → `brew install --cask clicky-ai` → success? exit 0
                                                                           ↓ fail
                                                      Fall back to DMG pipeline
                                                                           ↓
Fetch latest release JSON: https://api.github.com/repos/<owner>/<repo>/releases/latest
  ↓
Find asset matching `Clicky-*-arm64.dmg` + sibling `.dmg.sha256`
  ↓
Download to ~/Library/Application Support/clicky-ai/downloads/
  ↓
`shasum -a 256` → compare with .sha256 file → mismatch? abort
  ↓
`hdiutil attach -nobrowse -quiet <dmg>` → parse mount point
  ↓
`cp -R <mount>/Clicky.app /Applications/`
  ↓
`hdiutil detach -quiet <mount>` → `xattr -rd com.apple.quarantine /Applications/Clicky.app`
  ↓
exit 0
```

GitHub repo URL is stored in `scripts/installer.ts` as a constant
(`CLICKY_RELEASE_REPO = "jdnichollsc/clicky"` — placeholder; update at publish).

### Swift: `ClaudeCLIRunner` interface

```swift
enum ClaudeCLIError: Error {
    case binaryNotFound
    case sandboxBlocked(underlying: Error)
    case notLoggedIn
    case invalidStreamEvent(rawLine: String)
    case cliExitedNonZero(code: Int32, stderr: String)
    case cancelled
}

struct ClaudeCLIMessage {
    enum Role: String { case user, assistant }
    let role: Role
    let text: String
    let images: [Image]
    struct Image {
        let mediaType: String   // "image/jpeg"
        let base64: String
    }
}

struct ClaudeCLIStreamChunk {
    let textDelta: String
    let isFinal: Bool
}

@MainActor
final class ClaudeCLIRunner {
    /// Locates the `claude` binary in this order:
    /// 1. env CLICKY_CLAUDE_BIN
    /// 2. /opt/homebrew/bin/claude
    /// 3. /usr/local/bin/claude
    /// 4. ~/.claude/local/claude
    /// 5. `which claude` (via /usr/bin/env)
    static func locate() throws -> URL

    /// Probes `claude --version` and returns the version string.
    static func probeVersion(at binary: URL) async throws -> String

    /// Streams a single turn. Writes a stream-json user message to stdin,
    /// reads stream-json events from stdout, calls onChunk for text_delta
    /// events, and returns the accumulated assistant text plus the CLI's
    /// session_id (captured from the first `system/init` event) so callers
    /// can persist it and pass it as `resumeSessionId` on the next turn.
    func ask(
        messages: [ClaudeCLIMessage],
        systemPrompt: String,
        model: String,
        resumeSessionId: String?,
        onChunk: @escaping (ClaudeCLIStreamChunk) -> Void
    ) async throws -> (text: String, sessionId: String?)
}
```

### Invocation contract (validated via live experiments, 2026-04-19)

**Do NOT use `--bare`.** Per `claude --help`: *"Anthropic auth is strictly
ANTHROPIC_API_KEY or apiKeyHelper via --settings (OAuth and keychain are
never read)"* — so `--bare` would forfeit the user's subscription, which
contradicts this whole project. Instead, use the isolation flag combo
below, which preserves OAuth auth while stripping the user's CLAUDE.md,
hooks, plugins, auto-memory, MCP servers, and slash commands — delivering
~2s spawn (vs 5–6s untuned, vs 0.7s with `--bare`-but-broken-auth) and
2012 input tokens (vs 10969 untuned) on this machine.

`Process.executableURL = <claude binary>` (located per `locate()` above).

`Process.arguments` (mandatory, exact order not required but kept
consistent):

```
--print
--verbose                                   # required by stream-json + --print
--output-format stream-json
--input-format stream-json
--include-partial-messages                  # true token-level streaming
--model <user-selected-model>
--system-prompt <clicky-persona-prompt>     # replaces default claude_code prompt
--setting-sources ""                        # skip user/project/local settings
--disable-slash-commands                    # skip skill discovery
--strict-mcp-config
--mcp-config '{"mcpServers":{}}'            # empty but schema-valid
--permission-mode bypassPermissions         # unattended subprocess
--exclude-dynamic-system-prompt-sections    # prompt cache friendliness
# NOTE: --no-session-persistence is NOT used — it conflicts with --resume
# (the CLI says "sessions will not be saved to disk and cannot be resumed").
# We rely on --resume for cross-launch continuity, so we need the CLI to
# keep sessions on disk.
--disallowedTools Task Bash Edit Read Write Glob Grep NotebookEdit WebFetch WebSearch Skill
[--session-id <uuid>]                       # set on FIRST turn of a conversation
[--resume <uuid>]                           # set on subsequent turns
```

Stdin: newline-delimited stream-json user messages (text + optional
base64 images per the `{"type":"user","message":{...}}` envelope
validated in experiments).

Stdout: newline-delimited stream-json events. Parse line-by-line via
`FileHandle.readabilityHandler` + a line-buffered accumulator. Switch
on `type`:

- `"system"` + `subtype == "init"` → capture `session_id` and verify
  `apiKeySource == "none"` (proves subscription auth, not API key).
- `"stream_event"` + `event.type == "content_block_delta"` + 
  `delta.type == "text_delta"` → emit `ClaudeCLIStreamChunk` with
  `text_delta.text`.
- `"result"` + `subtype == "success"` → mark `isFinal = true`, capture
  `duration_ms`, `total_cost_usd`, final `session_id`.
- Any other event type → log at `.debug` and continue.

**Pipe-buffer drain protocol (R8 fix):** the kernel pipe buffer (~16–64
KB) deadlocks if stdin is written while stdout isn't being drained
(guaranteed to happen with base64 images). Attach
`FileHandle.readabilityHandler` to *both* stdout and stderr *before*
writing anything to stdin. Drain both continuously on a background
queue; never `waitForDataInBackgroundAndNotify` synchronously while
holding the stdin write thread. Close stdin (`Pipe.fileHandleForWriting.closeFile()`)
as soon as the turn's JSON payload is flushed to signal EOF.

Stderr: collected into a buffer; surfaced in `cliExitedNonZero` with
the full stderr for debugging. If stderr contains `"Not logged in"`, 
`"/login"`, or exit code 401/403-ish patterns, throw `.notLoggedIn`
so the UI can prompt the user to run `claude` once in Terminal.

**Cancellation sequence (R10 fix):**
1. `Task.cancel` on the caller → runner observes via
   `Task.isCancelled` in its stdout-read loop.
2. Runner calls `process.terminate()` (sends SIGTERM).
3. Runner closes stdin, stops draining stdout/stderr.
4. Runner throws `.cancelled`; any partial text accumulated so far is
   discarded by ClaudeAPI (not delivered via `onChunk`).
5. On a subsequent turn, a fresh process is spawned; no daemon reuse.

### Swift: `ClaudeAPI` public surface (unchanged)

Keep the existing async API in `ClaudeAPI.swift` intact so
`CompanionManager.swift` (594–760 region) sees no breakage. Internal
implementation delegates to `ClaudeCLIRunner.ask(...)`.

```swift
// Pseudocode outline of modified ClaudeAPI
final class ClaudeAPI {
    private let runner: ClaudeCLIRunner
    
    func streamChat(
        messages: [ChatMessage],
        systemPrompt: String,
        model: String,
        onTextChunk: @escaping (String) -> Void
    ) async throws -> String {
        let cliMessages = messages.map(Self.toCLIMessage)
        return try await runner.ask(
            messages: cliMessages,
            systemPrompt: systemPrompt,
            model: model,
            onChunk: { chunk in onTextChunk(chunk.textDelta) }
        )
    }
}
```

TLS warmup (ClaudeAPI.swift:36/66–96) is removed — no more network call.

## Code Style

### TypeScript (plugin)

Functional, exported free functions. No classes unless state is
genuinely needed. Notebooklm's hand-rolled arg parser copied.

```typescript
// scripts/screenshot.ts
import { spawn } from 'node:child_process';
import { mkdir } from 'node:fs/promises';
import { join } from 'node:path';
import { resolveScreenshotsDir } from './paths.ts';
import type { CaptureManifest, ScreenInfo } from './types.ts';

export async function capture(options: { maxWidth?: number; outputDir?: string }): Promise<CaptureManifest> {
  const dir = options.outputDir ?? resolveScreenshotsDir();
  await mkdir(dir, { recursive: true });
  const displays = await enumerateDisplays();
  const screens: ScreenInfo[] = [];
  for (const d of displays) {
    const path = join(dir, `${timestamp()}-screen${d.index}.jpg`);
    await shell('screencapture', ['-x', '-D', String(d.displayId), '-t', 'jpg', path]);
    if (options.maxWidth) {
      await shell('sips', ['-Z', String(options.maxWidth), path]);
    }
    const dims = await readJpegDimensions(path);
    screens.push({ index: d.index, path, widthPx: dims.w, heightPx: dims.h, ... });
  }
  return { schemaVersion: 1, capturedAt: new Date().toISOString(), screens, cursorScreenIndex: findCursorScreen(screens) };
}
```

### Swift

Match CLAUDE.md: long, explicit names; no docstrings/comments added to
unmodified code; no fix-ups to the known Swift 6 concurrency warnings.

```swift
@MainActor
final class ClaudeCLIRunner {
    private let binaryURL: URL
    private let logger = Logger(subsystem: "com.clicky", category: "ClaudeCLIRunner")

    init(binaryURL: URL) {
        self.binaryURL = binaryURL
    }

    static func locate() throws -> URL {
        let candidates: [String] = [
            ProcessInfo.processInfo.environment["CLICKY_CLAUDE_BIN"],
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            NSHomeDirectory() + "/.claude/local/claude",
        ].compactMap { $0 }

        for candidate in candidates {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }
        throw ClaudeCLIError.binaryNotFound
    }
}
```

## Testing Strategy

- **No new test framework.** Mirrors notebooklm-ai-plugin's zero-tooling
  approach and the current Swift app (the user is already removing its
  test targets).
- **Plugin smoke checklist** in `docs/specs/verification.md`:
  - `npx -y bun scripts/main.ts status` returns valid JSON
  - `capture` emits a parseable manifest with at least one screen
  - `point --x 100 --y 200 --label test` prints the exact expected line
  - `speak "hi"` plays audible output
  - `install --force` with no brew and no release produces a clear error
- **Swift manual smoke**:
  - Launch app, grant permissions, hold Ctrl+Option, say "what's on my
    screen" — verify Claude replies via CLI, TTS speaks the answer,
    POINT tag (if emitted) drives the cursor overlay.
  - Remove `claude` from PATH, relaunch → banner shows
    "Install Claude Code" with working link.

## Boundaries

### Always do

- Preserve the Clicky persona system prompt text verbatim from
  `CompanionManager.swift:544–577` when porting it to `SKILL.md`.
- Preserve the POINT tag format `[POINT:x,y:label:screenN]` and the
  "screenshot pixel space" coordinate contract.
- Use only macOS-built-in CLIs in plugin scripts: `screencapture`, `sips`,
  `say`, `afplay`, `open`, `hdiutil`, `shasum`, `system_profiler`, plus
  user-installed `brew` and `claude`.
- Write all plugin state under `~/Library/Application Support/clicky-ai/`.
- Keep Swift public APIs (`ClaudeAPI`, `CompanionManager`) stable across
  the transport swap.

### Ask first

- Modifying the persona/system prompt wording.
- Deleting `worker/` (deletion is planned but gated on verifying the
  Swift CLI path works end-to-end).
- Adding any npm dependency to the plugin (goal: zero).
- Changing `leanring-buddy.entitlements`.
- Publishing the Homebrew cask or cutting a GitHub release.

### Never do

- Ship `ANTHROPIC_API_KEY`, `ELEVENLABS_API_KEY`, or `ASSEMBLYAI_API_KEY`
  in bundled code, Info.plist, or plugin config.
- Use `--bare` mode when spawning `claude` — it forbids OAuth/keychain
  reads and would force an API key, breaking the whole subscription
  premise. Use the isolation flag combo in §Interfaces instead.
- Require `bun` to be pre-installed (must bootstrap via `npx -y bun`).
- Break the global push-to-talk hotkey.
- Touch `leanring-buddy.xcodeproj/project.pbxproj` without reason.
- Run `xcodebuild` from the terminal (invalidates TCC).
- Silently migrate user settings without visible onboarding.
- Add tests to the Swift target (the user is removing them; do not re-add).

## Migration Steps (Track B)

1. Audit `leanring-buddy.entitlements` + `project.pbxproj`. Record
   whether App Sandbox is on. If yes, add `com.apple.security.inherit`
   and/or a temporary-exception entitlement for `Process.run`.
2. Add `ClaudeCLIRunner.swift`. Implement `locate()`,
   `probeVersion(at:)`, and a minimal `ask` with text-only input to
   smoke-test stream-json parsing.
3. One-shot integration test: add a debug button in the panel that
   calls `runner.ask(messages: [.user("what is 2+2?")], systemPrompt: "",
   model: "claude-sonnet-4-6")` and logs the result. Remove the button
   before ship.
4. Extend `ask` to accept base64 images; verify end-to-end with a real
   screenshot and the Clicky system prompt.
5. Modify `ClaudeAPI.swift` so its public `streamChat(...)` method
   delegates to `ClaudeCLIRunner`. Delete the `URLSession` + TLS warmup
   code paths. Keep behind a `ClaudeTransport.cli` vs `.worker` enum for
   one commit, then remove the worker case.
6. Flip `Info.plist` → `VoiceTranscriptionProvider = "appleSpeech"`.
7. Move AssemblyAI key loading from Worker proxy to a Keychain-stored
   optional user key; provider becomes opt-in. Same for ElevenLabs.
8. Replace `ElevenLabsTTSClient.speak(...)` default path with
   `AVSpeechSynthesizer`. Preserve the class but gate real network use
   behind `hasUserProvidedElevenLabsKey()`.
9. Add "Install Claude Code" banner in `CompanionPanelView.swift` that
   appears when `ClaudeCLIRunner.locate()` throws. Link:
   `https://claude.com/claude-code`.
10. Delete `worker/` and `wrangler.toml`. Update `CLAUDE.md`,
    `AGENTS.md`, `README.md` — remove Worker section, add Claude Code CLI
    prerequisite.

## Edge Cases & Error Handling

### Plugin

| Scenario | Behaviour |
|---|---|
| `process.platform !== 'darwin'` | All subcommands except `help` exit 1 with "clicky-ai requires macOS". |
| Screen Recording permission missing | `capture` prints a message pointing to System Settings → Privacy & Security, exits 1. |
| `brew` missing AND no internet | `install` falls straight through to manual URL message, exits 1. |
| `brew install --cask clicky-ai` fails because cask isn't published yet | Fallback to DMG pipeline automatically; log the brew failure reason. |
| DMG SHA256 mismatch | Abort, keep downloaded file for inspection, exit 1. |
| `/Applications/Clicky.app` exists with different version | `install --force` replaces it; without `--force`, exit 0 with "already installed, use --force to replace". |
| `CLICKY_VIBEVOICE_URL` set but unreachable | `speak` logs warning to stderr, falls back to `say`. |
| Empty text string to `speak` | No-op, exit 0. |
| `point` missing `--x` or `--y` | Exit 1 with usage hint. |
| `capture` on headless session (no displays) | Exit 1 with clear message. |

### Swift

| Scenario | Behaviour |
|---|---|
| `claude` binary missing | Menu-bar banner: "Install Claude Code" linking to claude.com. Recording disabled. |
| Sandbox blocks `Process.run()` | Show dedicated help panel: "Grant command-execution permission" with re-run steps. |
| `claude` session not logged in (stderr contains "login" or "unauthenticated") | Panel prompts user to run `claude` once in Terminal to sign in. |
| CLI exits mid-stream | Deliver partial text to overlay, mark turn as incomplete in history, show toast. |
| Stream-json parse error | Log raw line to os_log with `error` level, show generic "Claude had trouble responding" message. |
| User cancels via panel button | `Task.cancel` on runner → `process.terminate()` → discard partial text. |
| User switches model mid-turn | Kill current process, start new one on next hotkey. |
| VibeVoice URL set but unreachable | TTS falls back to AVSpeechSynthesizer with one-time warning toast. |
| User entered invalid ElevenLabs key | TTS falls back to AVSpeechSynthesizer, key cleared from Keychain on consistent 401. |

## Success Criteria

### Plugin v1

- [ ] `npx -y bun scripts/main.ts install` installs `/Applications/Clicky.app` on a clean macOS box (either via cask once published, or via DMG fallback).
- [ ] `npx -y bun scripts/main.ts launch` launches the native app.
- [ ] `npx -y bun scripts/main.ts capture` produces a manifest + JPEGs that Claude can Read.
- [ ] `npx -y bun scripts/main.ts point --x 100 --y 200 --label test` prints the canonical line.
- [ ] `npx -y bun scripts/main.ts speak "hello"` plays audio through macOS `say`.
- [ ] `npx -y bun scripts/main.ts status` accurately reflects environment.
- [ ] Skill-triggered invocation works when user types "clicky, what's on my screen?" in Claude Code.
- [ ] No network calls to api.anthropic.com from the plugin.
- [ ] Zero npm deps (verified by `git grep '"dependencies"' package.json` returning nothing; there is no `package.json`).

### Swift v1 (migration)

- [ ] Push-to-talk → screenshot → Claude response → TTS → POINT → cursor overlay all work with `worker/` deleted.
- [ ] No `ANTHROPIC_API_KEY`/`ELEVENLABS_API_KEY`/`ASSEMBLYAI_API_KEY` in any bundled config or source.
- [ ] `worker/` and `wrangler.toml` no longer exist in the repo.
- [ ] Missing `claude` binary produces the "Install Claude Code" banner and does not crash.
- [ ] Conversation history across turns within a single app session still works.
- [ ] **Latency budget:** time from end-of-transcription to first audible
      TTS word ≤ 3.5s on Apple Silicon (M-series), accounting for
      ~2s CLI spawn + ~0.8s time-to-first-token + TTS synthesis. Regression
      over Worker path (~1.5s) acknowledged and documented.
- [ ] **Auth verification:** first turn's `system/init` event logs
      `apiKeySource == "none"`, confirming subscription auth is used
      (not an API key).

### Combined

- [ ] README (plugin) and README (app) each reference the new
      architecture and the `claude` CLI prerequisite.
- [ ] Homebrew cask formula drafted in `casks/clicky-ai.rb` ready to PR
      to `homebrew-cask` (or user's tap).

## Resolved Decisions (replaces Open Questions)

**Q1 — Session resume: V1 ships with `--resume` support.**

`ClaudeCLIRunner.ask(...)` is extended to return `(finalText, sessionId:
String?)`. Its signature gains an optional `resumeSessionId: String?`
argument; when non-nil, the CLI invocation adds `--resume <id>`. The
app persists the most recent `session_id` to
`~/Library/Application Support/Clicky/last-session.json` and reads it on
next launch. Clearing history in the panel deletes this file.

`session_id` is extracted from the first stream-json event of type
`system` with `subtype == "init"`. If the CLI exits before that event,
the runner returns `sessionId: nil` and no persistence happens.

**Q2 — Cask tap: ship to `jdnichollsc/tap/clicky-ai` first.**

Plugin's `install` subcommand runs
`brew install jdnichollsc/tap/clicky-ai` (not the short
`--cask clicky-ai`). Migration to `homebrew-cask` upstream is deferred
until v1.x is validated. The tap repo is separate from this repo; its
creation is outside this spec's scope but tracked as a release-readiness
item.

**Q3 — Release automation: GitHub Actions is part of Track B.**

New workflow `.github/workflows/release.yml` in the Swift app repo.
Triggered by tag push matching `v*`. Steps: checkout, `xcodebuild archive`,
`codesign --deep --force --options=runtime`, `xcrun notarytool submit
--wait`, `xcrun stapler staple`, `create-dmg` or `hdiutil create`,
`shasum -a 256` sidecar, GitHub CLI `gh release create` with both files
attached. Secrets needed: `APPLE_ID`, `APPLE_APP_PASSWORD`, `TEAM_ID`,
`CERTIFICATE_P12_BASE64`, `CERTIFICATE_P12_PASSWORD`. Documented in the
repo's SECURITY or RELEASE.md.

**Q4 — Version pinning: probe-only, no enforcement.**

`ClaudeCLIRunner.probeVersion(at:)` runs on first use, logs via os_log,
exposes the string in the `status` plugin subcommand output. No minimum
version check. If future incompatibilities appear, a floor will be added
then, not speculatively now.

**Q5 — `OpenAIAudioTranscriptionProvider.swift`: deleted.**

Removed from the project along with any Info.plist reference and
`VoiceTranscriptionProvider == "openai"` branch in
`BuddyTranscriptionProvider.swift`. STT providers that remain:
`appleSpeech` (default) and `assemblyai` (opt-in with user key). v2 can
revisit if there's demand; local Whisper/MLX is out of scope.

**Q6 — VibeVoice bootstrap: env var only, no walkthrough.**

Plugin README's Voice section reads: *"Set `CLICKY_VIBEVOICE_URL=http://
localhost:3000` to route TTS through a local VibeVoice server. See the
[VibeVoice repo](https://github.com/microsoft/VibeVoice-Realtime) for
setup."* No helper subcommand, no copy-pasted install steps, no
maintained compatibility matrix.
