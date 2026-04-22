# Swift App Port Review: Legacy Clicky → clicky-ai-plugin/native

Legacy: `/Users/jdnichollsc/dev/ai/clicky/clicky/leanring-buddy/` (22 Swift
files, ~7,636 LoC, plus assets). Reference-only — never modified.

New: `/Users/jdnichollsc/dev/ai/clicky/clicky-ai-plugin/native/Sources/Clicky/`
(6 Swift files, ~1,026 LoC).

Scope of review: classify every legacy Swift file as **port v0.1 / port
v0.2 / port v0.3 / skip** with rationale, then flag gaps worth
addressing now vs deferring.

## 1. File inventory

| # | Legacy file | LoC | New equivalent | New LoC | Decision | Rationale |
|---|---|---:|---|---:|---|---|
| 1 | `leanring_buddyApp.swift` | 89 | `App.swift` | 115 | ✅ **Already ported** | @main + AppDelegate wired; minimal vs upstream's onboarding-aware init. v0.2 may need Sparkle hook (skipping per spec). |
| 2 | `MenuBarPanelManager.swift` | 243 | `App.swift` | — | ✅ **Already ported (subset)** | Status item + panel lifecycle in-lined into `AppDelegate`. Upstream adds **click-outside-to-dismiss** global event monitor — port v0.2 for polish. |
| 3 | `CompanionPanelView.swift` | 761 | `PanelView.swift` | 203 | 🟡 **Partial — port selectively v0.2** | Upstream is bloated with onboarding, email capture, DM Farza, video player, permissions wizard. v0.2 borrows only the **model picker** (sonnet/opus) and the **permissions block**. Everything else stays retired. |
| 4 | `CompanionManager.swift` | 1,026 | `ClickyViewModel.swift` | 122 | 🟡 **Grow incrementally** | The upstream central state machine. v0.2: add push-to-talk state, conversation history (ignoring Worker paths), POINT parser. v0.3: overlay coord mapping. Do NOT bulk-port — grow ViewModel as features land. |
| 5 | `ClaudeAPI.swift` | 291 | `ClaudeCLIRunner.swift` | 421 | ❌ **Skip (superseded)** | Upstream class is URLSession→Worker. We use CLI subprocess. Functionally replaced. |
| 6 | `AppBundleConfiguration.swift` | 28 | (Info.plist direct reads) | — | 🟢 **Port v0.2 (trimmed)** | Needed if any Info.plist key becomes user-configurable (e.g., model preference). Drop Worker URL field. ~15 lines after trim. |
| 7 | `ClickyAnalytics.swift` | 121 | — | — | ❌ **Skip** | PostHog retired per spec. No telemetry in v1. |
| 8 | `DesignSystem.swift` | 880 | (inline colors in PanelView) | — | 🟢 **Port v0.2 (trimmed)** | Upstream defines ~40 color tokens + radii + type styles. v0.2 port: only the ~10 tokens our panel actually uses. Target ~120 lines. Full DS file stays for reference. |
| 9 | `GlobalPushToTalkShortcutMonitor.swift` | 132 | — (missing) | 0 | 🔵 **Port v0.2** | CGEvent tap for `⌃⌥` hotkey. Foundation for push-to-talk. ~130 lines, copy nearly as-is (logger subsystem rename only). |
| 10 | `BuddyDictationManager.swift` | 866 | — (missing) | 0 | 🔵 **Port v0.2 (lean)** | AVAudioEngine mic capture + PTT lifecycle. Strip AssemblyAI/OpenAI branches; keep AppleSpeech-only path. Expected ~350 lines after strip. |
| 11 | `BuddyTranscriptionProvider.swift` | 100 | — (missing) | 0 | 🔵 **Port v0.2 (lean)** | STT provider protocol + factory. Keep only AppleSpeech branch. ~40 lines after strip. |
| 12 | `BuddyAudioConversionSupport.swift` | 108 | — (missing) | 0 | 🔵 **Port v0.2 as-is** | PCM16 → WAV helpers for upload-based providers. Small, utility. Port unchanged. |
| 13 | `AppleSpeechTranscriptionProvider.swift` | 147 | — (missing) | 0 | 🔵 **Port v0.2 as-is** | Native Speech framework provider. Works today, no Worker dep. Port unchanged. |
| 14 | `AssemblyAIStreamingTranscriptionProvider.swift` | 478 | — | — | ❌ **Skip** | Retired per spec. User-supplied key path could be a v1.5 opt-in, but not here. |
| 15 | `OpenAIAPI.swift` | 142 | — | — | ❌ **Skip** | Retired per spec. |
| 16 | `OpenAIAudioTranscriptionProvider.swift` | 317 | — | — | ❌ **Skip** | Retired per spec. |
| 17 | `ElevenLabsTTSClient.swift` | 81 | — | — | ❌ **Skip** | Retired per spec. v0.2 TTS = `AVSpeechSynthesizer` (~30 lines to write fresh; no port needed). |
| 18 | `CompanionScreenCaptureUtility.swift` | 132 | `ScreenCapture.swift` | 92 | 🟡 **Port v0.2 (multi-display)** | Our helper does single-display. Upstream adds **multi-monitor iteration + display-frame metadata** + `isCursorScreen` detection. Port the multi-display logic when overlay arrives. |
| 19 | `CompanionResponseOverlay.swift` | 217 | — (missing) | 0 | 🔵 **Port v0.3** | Response text bubble + waveform UI rendered on the cursor overlay. Depends on #20. |
| 20 | `OverlayWindow.swift` | 881 | — (missing) | 0 | 🔵 **Port v0.3 (flagship)** | Full-screen transparent NSPanel hosting the blue triangle cursor, bezier flight arcs, POINT animation. The "magical" piece of Clicky. Largest single port — v0.3 centerpiece. |
| 21 | `ElementLocationDetector.swift` | 335 | — | — | 🟠 **Evaluate for v0.3, may skip** | Heuristic UI-element detection in screenshots. Overlaps with the user's stated OmniParser V2 interest. Re-assess once the overlay is live — may be fully replaced by OmniParser. |
| 22 | `WindowPositionManager.swift` | 262 | `App.swift::positionPanelUnderStatusItem` | — | 🟡 **Port v0.2 (selected helpers)** | Our panel positioning is 6 lines. Upstream also owns **Screen Recording permission flow** + **accessibility helpers** — port those two subroutines (~60 lines), skip the rest. |

### Non-code legacy assets

| Asset | Decision | Note |
|---|---|---|
| `Assets.xcassets/AppIcon.appiconset/` | 🔵 **Port v0.2 → convert to .icns** | SwiftPM doesn't consume `.xcassets`; we need a `Clicky.icns` in `native/Resources/` + CFBundleIconFile in Info.plist. |
| `enter.mp3`, `eshop.mp3`, `ff.mp3` | ❌ **Skip** | Onboarding music (retired with onboarding flow). |
| `steve.jpg`, `codex-add-project.png` | ❌ **Skip** | Personality assets + a stray screenshot. Not product-critical. |
| `Info.plist`, `leanring-buddy.entitlements` | ✅ **Already rewritten** | New versions in `native/` are slimmer + correct for v0.1. |

## 2. Gaps in new app worth addressing

Scope contract for v0.1: "test Claude CLI transport works in a real app
bundle". By that bar, **there are no critical gaps** — v0.1 is shippable.

Nice-to-haves you could fold into v0.1 without blowing scope:

| Gap | Effort | Why it matters | Recommendation |
|---|---|---|---|
| App icon (`.icns`) | 30 min | Unbranded bundle looks like a toy. | Add — port from legacy `AppIcon.appiconset/`. |
| Click-outside-to-dismiss panel | 10 min | Panel sticks around after clicking elsewhere; minor UX drag. | Add — one NSEvent global monitor. |
| Screen Recording permission pre-flight | 30 min | First "Test Claude" click silently fails until user grants permission. Better to prompt + guide. | Add — ported subroutine from `WindowPositionManager`. |
| Model picker (sonnet/opus) | 20 min | Currently hard-coded to `claude-sonnet-4-6`. Upstream lets users flip. | Defer to v0.2 — minor QoL. |
| "Clear conversation" UX | — | Already have the button, wired to `viewModel.clearConversation()`. | No gap. |

**My recommendation:** add the first three (icon + dismiss + permission
pre-flight) to v0.1 before committing. ~70 minutes total. Bumps polish
from "demo" to "ready to ship".

## 3. v0.2 roadmap ordering

Load-bearing dependency chain for the next major milestone:

```
  DesignSystem-lean    (port first, enables Panel v2 refactor)
        ↓
  Panel v2             (model picker row, permission block — borrowed
                        from CompanionPanelView, minus onboarding)
        ↓
  GlobalPushToTalkShortcutMonitor  (CGEvent tap, no deps beyond Foundation)
        ↓
  AppleSpeechTranscriptionProvider + BuddyTranscriptionProvider
  + BuddyAudioConversionSupport     (STT pipeline foundation)
        ↓
  BuddyDictationManager (lean)      (mic capture + PTT lifecycle)
        ↓
  AVSpeechSynthesizer wrapper (~30 lines, NEW)   (TTS default)
        ↓
  End-to-end: hotkey → mic → STT → Claude → TTS
```

Estimated v0.2 LoC delta: +1,200 lines (after legacy trimming).

v0.3 roadmap:

```
  CompanionScreenCaptureUtility (multi-display + cursor screen)
        ↓
  OverlayWindow + CompanionResponseOverlay  (blue cursor, POINT flight)
        ↓
  POINT tag parser in ClickyViewModel       (parse [POINT:x,y:label:screenN])
        ↓
  Coordinate mapping (screenshot px → display points → AppKit global)
```

Estimated v0.3 LoC delta: +1,400 lines (mostly OverlayWindow, the
flagship feature).

## 4. Risks / scope creep notes

- **Overlay port (#20) is the single biggest file** at 881 lines and
  the hardest to get right (bezier math, multi-screen coord flip,
  60fps animation). Budget a dedicated session for it.
- **DesignSystem temptation**: it's easy to port the whole 880-line
  DS file "just in case" and add 800 LoC of unused tokens. Port
  strictly what the current view needs; grow from there.
- **ElementLocationDetector overlap with OmniParser V2**: if we port
  it and then also add OmniParser, we pay twice. Gate this file behind
  an explicit "do we want heuristic detection?" decision after seeing
  OmniParser's latency in practice.
- **Panel refactor blast radius**: CompanionPanelView at 761 lines
  touches permissions, onboarding, model picker, email capture, dm
  button, footer. Surgical port only — don't bring over state we
  deleted (hasSubmittedEmail, onboarding video opacity, etc.).
- **Audio stack Swift-6 concurrency**: AVAudioEngine + PTT state
  transitions have known concurrency warnings in Clicky. Do not try to
  fix them during the port (spec explicitly says "do NOT fix the known
  Swift 6 concurrency warnings").

## 5. Concrete action list

Pick one to execute next:

- **A. Polish v0.1 and ship it** — add app icon + click-outside-dismiss
  + screen-recording permission pre-flight (~70 min), then commit and
  push. Leaves Track B at a shippable v0.1.0 tag.
- **B. Jump to v0.2 push-to-talk** — port DesignSystem-lean +
  GlobalPushToTalkShortcutMonitor + BuddyTranscriptionProvider +
  AppleSpeechTranscriptionProvider + BuddyAudioConversionSupport +
  BuddyDictationManager (lean). Big session (~4 h of Swift).
- **C. Jump to v0.3 overlay** — port CompanionScreenCaptureUtility
  (multi-display) + OverlayWindow + CompanionResponseOverlay + POINT
  parser. Biggest session (~6 h), most rewarding output (the
  user-visible "magical" feature).
- **D. Distribution path** — #19 (GitHub Actions release) + #20 (cask
  formula) + #23 (create `proyecto26/homebrew-tap` repo). Finishes
  v0.4 milestone, unlocks `brew install`.

My recommendation: **A, then D, then B, then C**. Ship something
working before adding features; get distribution in place early so
every subsequent release is just a tag push; then voice; then overlay.
