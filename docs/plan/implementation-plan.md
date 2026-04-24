# Implementation Plan: clicky-ai

Source spec: [clicky-ai-plugin.md](../specs/clicky-ai-plugin.md).

Two tracks, four milestones, ~22 tasks. Vertical slicing keeps each
milestone independently shippable.

## Overview

- **Track A** (plugin) ships first, adding zero risk to the native app.
- **Track B** (Swift migration) replaces the Cloudflare Worker
  LLM transport with a `claude` CLI subprocess. Ships only after Track A
  has proven the shape of the UX.
- **Track C** (distribution) publishes the Homebrew tap + signed DMG so
  the plugin's `install` subcommand has something to install.

## Architecture Decisions (locked from spec)

- Plugin runs on `#!/usr/bin/env -S npx -y bun`, zero npm deps.
- Plugin dispatcher follows notebooklm-ai-plugin layout verbatim.
- Swift `ClaudeCLIRunner` uses `Foundation.Process` + stream-json I/O.
- Session resume ships in v1 via `--resume <session_id>` + disk-persisted
  last-session.json.
- Cask is published to `jdnichollsc/tap/clicky-ai` (not upstream homebrew-cask).
- GitHub Actions release workflow is new and owned by the Swift repo.
- OpenAI transcription provider is deleted (not gated).
- VibeVoice integration is opt-in via env var only; no bootstrap scripts.

## Milestones

| Milestone | Scope | Tasks | Independently shippable? |
|---|---|---|---|
| **v0.1** Plugin MVP | Skill + subcommands ship as a standalone Claude Code plugin. Native app optional. | #1 → #10 (Track A) | Yes — works without Track B. |
| **v0.2** Swift CLI transport | Native app's `/chat` path runs on `claude` CLI. Worker still serves `/tts` and `/transcribe-token`. | #11–#14, #17 | Yes — ships the app with CLI transport, Worker partially retired. |
| **v0.3** Worker retirement | Worker deleted. OpenAI provider deleted. CI pipeline in place. No secrets in product. | #15, #18, #19 | Yes — final "zero-key" app. |
| **v0.4** Cask publish | Homebrew tap live, first signed release tagged, plugin's `install --force` succeeds end-to-end. | #20, #21 | Yes — closes the loop. |

## Dependency Graph

```
Track A (plugin)
────────────────
#1 Scaffold
  │
  ▼
#2 paths.ts + types.ts + args.ts
  │
  ├────────────┬────────────┬────────────┬────────────┬────────────┐
  ▼            ▼            ▼            ▼            ▼            ▼
#3 screenshot  #4 point    #5 speak     #6 launch    #21 installer  #22 status
  │            │            │            │            │            │
  └────────────┴────────────┴────────────┴────────────┴────────────┘
                                  │
                                  ▼
                            #7 main.ts
                                  │
                        ┌─────────┴─────────┐
                        ▼                    ▼
                   #8 SKILL.md        #9 README/LICENSE/.gitignore
                        │                    │
                        └─────────┬──────────┘
                                  ▼
                            #10 Validate

Track B (Swift)
────────────────
#11 Sandbox audit
  │
  ▼
#12 ClaudeCLIRunner.swift (probe CLI + smoke test)
  │
  ├────────────┐
  ▼            ▼
#17 --resume   #14 Missing-CLI fallback banner
  │            │
  └─────┬──────┘
        ▼
#13 Swap ClaudeAPI.swift to runner
        │
        ▼
#15 Retire Worker + migrate TTS/STT
        │
        ▼
#18 Delete OpenAI provider (can actually run in parallel with #15)

Track C (distribution)
──────────────────────
#15 Worker retirement
  │
  ▼
#19 GitHub Actions release pipeline
  │
  ▼
(first notarized DMG + SHA256 exist on Releases)
  │
  ▼
#20 Homebrew cask formula
  │
  ▼
(tap repo jdnichollsc/homebrew-tap populated, formula merged)
  │
  ▼
#21 installer.ts already points at the tap — verified end-to-end
```

## Parallelization Map

Across 1 agent, sequential. Across 2+ agents or sessions, these groups
can execute concurrently:

| Group | Tasks | Why parallelizable |
|---|---|---|
| G1 | #3 screenshot, #4 point, #5 speak, #6 launch-app, #21 installer, #22 status | All build on #2's foundation; no cross-dependencies; different files. |
| G2 | #8 SKILL.md, #9 README | Both authoring tasks. SKILL.md depends on the subcommand list (already in the spec). README depends on conventions (also in the spec). |
| G3 | #11 Sandbox audit, #3–#6 plugin scripts | Cross-track: Track A plugin work does not need Track B's Swift audit. |
| G4 | #18 OpenAI delete, #13 ClaudeAPI swap | Both touch Swift but different files and concerns. |
| G5 | #19 Release pipeline scaffolding, #14 Missing-CLI banner | Different surfaces (CI vs UI); no shared state. |

**Must be sequential (no shortcut):** #1 → #2 → (scripts) → #7 → #10;
#11 → #12 → #13 → #15; #15 → #19 → #20 → #21 (verification).

## Phase-by-Phase Task List

Each task below lists acceptance criteria + verification. Task IDs match
the live task tracker.

### Phase 1 — Track A v0.1 MVP

#### Task #1 — Scaffold plugin directory + manifests

- Scope: XS
- Files:
  `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`,
  `.gitignore`, `skills/openclicky/`, `scripts/` dirs, empty `LICENSE`,
  empty `README.md`.
- Acceptance:
  - `plugin.json` includes `name=clicky-ai`, `version=0.1.0`,
    `description`, `keywords`, `author`, `license=MIT`.
  - `marketplace.json` points `$schema` at the public schema URL and
    lists this plugin.
- Verify: `ls -la .claude-plugin/` shows both files; `jq . plugin.json`
  succeeds; `test -d skills/openclicky/scripts`.

#### Task #2 — Foundation modules (paths, types, args)

- Scope: S
- Files: `scripts/paths.ts`, `scripts/types.ts`, `scripts/args.ts`.
- Acceptance:
  - `paths.resolveDataDir()` returns
    `~/Library/Application Support/clicky-ai` on macOS with env override
    `CLICKY_DATA_DIR`.
  - `types.ts` exports `CaptureManifest`, `ScreenInfo`, `PointTarget`,
    `LaunchResult`, `InstallResult`, `SpeakRequest`, `StatusReport`.
  - `args.ts` parses `--flag value`, boolean flags, `-h` shortcut, positional args.
- Verify:
  ```bash
  bun -e "import('./scripts/paths.ts').then(m => console.log(m.resolveDataDir()))"
  ```

#### Tasks #3–#6, #21, #22 — Subcommand scripts (parallel group G1)

| ID | Title | Key acceptance |
|---|---|---|
| #3 | `screenshot.ts` | Emits valid `CaptureManifest` JSON; writes JPEGs capped at `--max-width` (default 1280); respects `--output-dir`; exits 1 on no-display or no-permission with actionable stderr. |
| #4 | `point.ts` | Prints `→ "<label>" at (x, y) on screen N` in text mode; emits `{label,x,y,screen}` in `--json` mode; exits 1 if any of `--x --y --label` missing. |
| #5 | `speak.ts` | Default engine `say`; auto-promotes to VibeVoice if `CLICKY_VIBEVOICE_URL` set and reachable, else to ElevenLabs if `CLICKY_ELEVENLABS_API_KEY` set; falls back silently to `say` on upstream failure with stderr warning. |
| #6 | `launch-app.ts` | Detects `/Applications/Clicky.app`, `/Applications/leanring-buddy.app`, `~/Library/Developer/Xcode/DerivedData/**/leanring-buddy.app`, and `CLICKY_APP_PATH`; launches via `open -a`; exits 1 with "not installed — run install" when missing. |
| #21 | `installer.ts` | (Create, not update.) Flow per spec: already-installed short-circuit → brew tap install → DMG fallback → manual URL. Tap name constant `CLICKY_TAP = "jdnichollsc/tap/clicky-ai"`. `CLICKY_RELEASE_REPO = "jdnichollsc/clicky"`. |
| #22 | `status.ts` | Returns `StatusReport` JSON per spec §Interfaces. Checks screen-recording by attempting `screencapture -x /tmp/probe.png`, checks accessibility with `osascript`. |

- Scope per task: S (1–2 files + tests of shape via `bun -e`).
- Verify each with: `bun scripts/<file>.ts --help` prints usage;
  `bun scripts/<file>.ts <args>` produces expected output.

#### Task #7 — main.ts dispatcher

- Scope: M (1 file, heavy logic)
- Files: `scripts/main.ts`.
- Acceptance:
  - Shebang `#!/usr/bin/env -S npx -y bun`.
  - Parses argv via `args.ts`; dispatches by subcommand.
  - `help` / no args / `-h` prints usage with every subcommand + flags.
  - Unknown subcommand exits 1 with hint.
  - Global `--json` flag routes all text output through JSON mode.
  - Exit code 0 on success, 1 on any handler failure; stderr captures error.
- Verify: `bun scripts/main.ts help`; `bun scripts/main.ts unknown`
  should exit 1; `bun scripts/main.ts status --json | jq .` parses.

#### Task #8 — SKILL.md

- Scope: M (single large markdown file)
- Files: `skills/openclicky/SKILL.md`.
- Acceptance:
  - Frontmatter with `name=clicky` and a 3rd-person description
    containing the trigger phrases "clicky", "show me where",
    "point at", "what's on my screen", "macOS visual assistant".
  - Body (lean, ~300–400 lines): persona rules from
    `CompanionManager.swift:544–577` verbatim, POINT tag protocol with
    examples from `CompanionManager.swift:786`, when-to-call-each-subcommand
    recipe, a concrete end-to-end example.
- Verify: `head -20 SKILL.md` shows frontmatter; grep for key phrases;
  manually load in Claude Code and trigger with "clicky, what's on my screen?".

#### Task #9 — README.md + LICENSE + .gitignore

- Scope: S
- Files: `README.md`, `LICENSE`, `.gitignore`.
- Acceptance:
  - README covers: what it is, install (plugin marketplace snippet),
    subcommands table, env vars (including VibeVoice + ElevenLabs),
    permissions section pointing at System Settings, troubleshooting
    paragraph for missing `claude` CLI.
  - LICENSE is MIT with user's copyright.
  - `.gitignore` ignores `screenshots/`, `downloads/`, `config.local.*`,
    `.DS_Store`.
- Verify: `grep -c "clicky-ai" README.md` ≥ 5; `cat LICENSE | head -1`
  matches "MIT License".

### Checkpoint A1 — after #1–#9 (Phase 1 build-out)

- [ ] `bun scripts/main.ts status --json | jq .` parses.
- [ ] `bun scripts/main.ts capture` produces a manifest + actual JPEGs.
- [ ] `bun scripts/main.ts point --x 100 --y 200 --label test` prints the
      canonical line.
- [ ] `bun scripts/main.ts speak "hello"` plays audio.
- [ ] `bun scripts/main.ts launch` exits 1 with the right message when
      app isn't installed (or succeeds if it is).

#### Task #10 — Validate plugin + dry-run

- Scope: S
- Acceptance:
  - Run plugin-validator agent → 0 critical issues.
  - Run skill-reviewer agent on SKILL.md → addresses high-priority notes.
  - Manual install into Claude Code, verify skill triggers on
    "clicky, what's on my screen?".
- Verify: validator report saved under `docs/plan/validation-report.md`.

### Checkpoint A-ship — Plugin v0.1 ready

- [ ] All of A1 checkpoint + validator green + skill triggers observed.
- [ ] Commit + tag `plugin-v0.1.0`.

### Phase 2 — Track B v0.2 Swift CLI transport

#### Task #11 — Sandbox audit

- Scope: XS (investigation, not code)
- Files: read `leanring-buddy.entitlements`, `project.pbxproj`.
- Acceptance:
  - Record whether App Sandbox is enabled.
  - If yes, document which entitlements are set and which are needed to
    allow `Process.run()` spawning an external binary.
  - Produce a 1-paragraph finding in `docs/plan/sandbox-audit.md`.
- Verify: `docs/plan/sandbox-audit.md` exists, references the
  entitlements file by line.

#### Task #12 — ClaudeCLIRunner.swift

- Scope: M (1 file, ~250 lines)
- Files: `leanring-buddy/ClaudeCLIRunner.swift` (new).
- Acceptance:
  - `locate()` iterates `CLICKY_CLAUDE_BIN` → `/opt/homebrew/bin/claude` →
    `/usr/local/bin/claude` → `~/.claude/local/claude` and returns first
    executable match, throws `.binaryNotFound` otherwise.
  - `probeVersion(at:)` returns the version string.
  - `ask(...)` spawns `claude --print --output-format stream-json
    --input-format stream-json --model <model> --append-system-prompt <prompt>`
    (plus `--resume <id>` when `resumeSessionId != nil`).
  - Stdin receives newline-delimited stream-json user messages
    (text + optional base64 images).
  - Stdout parser emits `text_delta` chunks via `onChunk` and captures
    `session_id` from `system/init`.
  - Returns `(text, sessionId)` or throws typed error.
  - Early-exit smoke test: a `#if DEBUG` method `smokeTest()` asks
    `"what is 2+2?"` and logs the result.
- Verify: run `smokeTest()` from a temporary debug button; observe
  4 in logs. Remove the debug button after verification.

#### Task #17 — --resume session persistence

- Scope: S
- Files: `CompanionManager.swift` (history + session load/save),
  new `SessionPersistence.swift` or inline helper.
- Acceptance:
  - First turn after app launch: reads
    `~/Library/Application Support/Clicky/last-session.json`, passes
    `resumeSessionId` if present.
  - After each successful turn: writes the returned `session_id` to that
    file.
  - "Clear conversation" action deletes the file and clears in-memory
    history.
  - Missing or malformed JSON is treated as "no session" and logged
    at `.info`.
- Verify: launch app, take a turn, kill app, relaunch, take another
  turn — second turn should see the first turn's context according to
  Claude's reply.

#### Task #13 — Swap ClaudeAPI.swift to ClaudeCLIRunner

- Scope: M (modify 1 file, cascading call-sites)
- Files: `leanring-buddy/ClaudeAPI.swift` (modified);
  callers in `CompanionManager.swift` unchanged.
- Acceptance:
  - `ClaudeAPI.streamChat(...)` public signature unchanged.
  - Internally delegates to `ClaudeCLIRunner`.
  - TLS warmup, URLSession, Cloudflare Worker base URL code deleted.
  - Worker `/chat` call path unreachable.
- Verify: grep `worker.dev` and `URLSession` in `ClaudeAPI.swift` ⇒ 0
  hits. Build app in Xcode (Cmd+B) ⇒ succeeds. Push-to-talk end-to-end
  works.

#### Task #14 — Missing-CLI fallback / onboarding

- Scope: S
- Files: `CompanionPanelView.swift` (modify); `CompanionManager.swift`
  (new `claudeCLIStatus` @Published).
- Acceptance:
  - On app launch, `CompanionManager` calls `ClaudeCLIRunner.locate()`
    and stores status.
  - If `.binaryNotFound`, panel shows banner "Install Claude Code" with
    a button that opens `https://claude.com/claude-code` and a subtitle
    "Clicky uses your Claude Code login to chat — no extra keys needed."
  - Banner hides once CLI becomes available (recheck on next opening of
    panel).
- Verify: move `claude` out of PATH; relaunch app; banner appears.
  Restore PATH; reopen panel; banner disappears after recheck.

### Checkpoint B1 — after #11–#14, #17 (Phase 2 build-out)

- [ ] Push-to-talk → CLI → streaming text → TTS → POINT → cursor animates.
- [ ] Killing + relaunching app preserves conversation via --resume.
- [ ] Missing-CLI state produces the install banner.
- [ ] Commit + tag `app-v0.2.0`.

### Phase 3 — Track B v0.3 Worker retirement

#### Task #18 — Delete OpenAIAudioTranscriptionProvider

- Scope: XS
- Files: delete `OpenAIAudioTranscriptionProvider.swift`; edit
  `BuddyTranscriptionProvider.swift` factory; edit `Info.plist` if it
  references the provider string.
- Acceptance:
  - File deleted.
  - Factory falls through to `appleSpeech` on unknown provider string.
  - Grep repo for "OpenAI" ⇒ 0 hits in Swift sources.
- Verify: `git ls-files | xargs grep -l OpenAIAudioTranscription` ⇒ empty.
  Build in Xcode ⇒ succeeds.

#### Task #15 — Migrate TTS/STT + delete Worker

- Scope: M
- Files: `Info.plist` (VoiceTranscriptionProvider default →
  `appleSpeech`); `AssemblyAIStreamingTranscriptionProvider.swift`
  (read key from Keychain, no-op if missing);
  `ElevenLabsTTSClient.swift` (AVSpeechSynthesizer default + Keychain
  opt-in); `AppBundleConfiguration.swift` (remove Worker URL + secret
  accessors); delete `worker/`; delete `wrangler.toml`; update
  `CLAUDE.md`, `AGENTS.md`, `README.md`.
- Acceptance:
  - `git ls-files | grep -E '^worker/|wrangler.toml'` ⇒ empty.
  - `grep -r ANTHROPIC_API_KEY .` ⇒ 0 hits.
  - `grep -r ELEVENLABS_API_KEY .` ⇒ 0 hits.
  - `grep -r ASSEMBLYAI_API_KEY .` ⇒ 0 hits.
  - Default push-to-talk → transcribes via Apple Speech, TTS via
    AVSpeechSynthesizer.
- Verify: app runs end-to-end with zero env vars + zero Keychain keys.

#### Task #19 — GitHub Actions release pipeline

- Scope: M
- Files: `.github/workflows/release.yml`, `RELEASE.md`.
- Acceptance:
  - Tag push `v*` triggers: xcodebuild archive → codesign (runtime hardening)
    → notarytool submit --wait → stapler → DMG via hdiutil → shasum -a 256
    sidecar → `gh release create` attaches both.
  - Documented secrets: `APPLE_ID`, `APPLE_APP_PASSWORD`, `TEAM_ID`,
    `CERTIFICATE_P12_BASE64`, `CERTIFICATE_P12_PASSWORD`.
  - `RELEASE.md` explains how to bump version + cut a tag.
- Verify: tag a throwaway `v0.0.0-test` → workflow runs green →
  release appears with `.dmg` and `.dmg.sha256`.

### Checkpoint C1 — Worker retired, CI green

- [ ] Worker directory gone, Wrangler gone, secrets gone.
- [ ] One signed+notarized DMG exists on Releases.
- [ ] Commit + tag `app-v0.3.0`.

### Phase 4 — Track C v0.4 Cask publish

#### Task #20 — Homebrew cask formula

- Scope: S
- Files: `casks/clicky-ai.rb` (in this plugin repo, copied into the tap
  repo by the user).
- Acceptance:
  - Points at `https://github.com/jdnichollsc/clicky/releases/download/<version>/Clicky-<version>-arm64.dmg`.
  - Includes `sha256 :no_check` or a real SHA (preferred, auto-updated
    by the release workflow).
  - `app "Clicky.app"`.
  - `zap trash: ["~/Library/Application Support/Clicky",
    "~/Library/Preferences/<bundle-id>.plist"]`.
- Verify: copy file into the tap repo, run
  `brew install jdnichollsc/tap/clicky-ai` on a clean machine → installs
  and launches.

#### Task #21 — installer.ts points at tap

- Scope: XS — this was already included in the spec at write-time;
  remaining work is verifying the tap name is correct once the tap
  exists.
- Acceptance:
  - `CLICKY_TAP === "jdnichollsc/tap/clicky-ai"` at top of
    `scripts/installer.ts`.
  - `npx -y bun scripts/main.ts install --force` on a clean Mac installs
    via `brew install jdnichollsc/tap/clicky-ai`.
- Verify: run the command on a throwaway user account.

### Checkpoint Final — v1.0 ready

- [ ] Plugin ships via Claude Code marketplace.
- [ ] Native app ships via `brew install jdnichollsc/tap/clicky-ai`.
- [ ] Zero product secrets. Zero Cloudflare Worker. Zero OpenAI
      dependency.
- [ ] README, CLAUDE.md, AGENTS.md all reference the new architecture.

## Risk Register (top 3)

| # | Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|---|
| 1 | **Clicky app is sandboxed and `Process.run()` is blocked outright** — would derail Track B entirely. | High (blocks v0.2+) | Medium (current entitlements unknown) | Task #11 audits first. If blocked, three fallbacks: (a) add `com.apple.security.inherit` entitlement, (b) ship an unsigned "helper" LaunchAgent outside the sandbox, (c) fall back to keeping the Worker for Claude. Do not start #12 until #11 is complete. |
| 2 | **`claude --output-format stream-json --input-format stream-json` does not accept base64 images in user messages** — would invalidate the Pencil pattern. | High (rewrites vision pipeline) | Low (Pencil uses it, SDK accepts) | First 30 minutes of Task #12 is a one-off test: pipe a minimal user message with a base64 image to the CLI, verify response. If it fails, pivot to saving images to `/tmp` and referencing by path (which the CLI does accept), or reintroduce Worker for vision. |
| 3 | **Apple notarization rejects the Swift app bundle** — blocks Task #19 → #20 → #21. | Medium (delay, not permanent) | Medium (first notarization always surprises) | Sanity-run notarization on a throwaway tag before the real v1 tag. Keep the DMG-by-hand fallback alive until CI is proven. |

## Cross-track Notes

- Track A ships **before** Track B completes: a plugin user without the
  native app still has a useful Clicky (short replies + capture + POINT
  text). The `install` subcommand fails gracefully until Tracks B/C
  produce something to install.
- Track B's #15 (Worker retirement) can begin **after** #13 (swap
  ClaudeAPI) proves the CLI path works end-to-end. Do not delete the
  Worker before that proof point.
- Track C's #19 (CI) can start in parallel with Track B if a different
  person/session is available — the workflow YAML can be drafted without
  the final build succeeding.
