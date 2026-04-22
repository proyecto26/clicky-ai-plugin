# Port Validation Tracker

State tracker for a Ralph Loop that walks every legacy Swift file in
`/Users/jdnichollsc/dev/ai/clicky/clicky/leanring-buddy/` and confirms
the feature / functionality it provides is accounted for in the new app
at `/Users/jdnichollsc/dev/ai/clicky/clicky-ai-plugin/native/Sources/Clicky/`.

**Status legend**

- `PENDING` — not yet validated.
- `OK` — functionality is present in the new app (a target file exists
  and provides equivalent behaviour).
- `GAP` — functionality is MISSING and should be ported in a future
  milestone (per the roadmap in `swift-app-port-review.md`).
- `SKIP` — retired per spec (`docs/specs/clicky-ai-plugin.md`). No port
  intended now or later.

**Ralph Loop contract**

- Each iteration validates ONE `PENDING` row.
- Iteration MUST NOT port files, MUST NOT edit `.swift` sources,
  MUST only read + classify + update this tracker.
- When the `## Rows` table has zero `PENDING` rows, the loop emits
  `<promise>ALL_FILES_VALIDATED</promise>`.

## Rows

| Legacy file | Legacy LoC | Status | Rationale | New-app target |
|---|---:|---|---|---|
| AppBundleConfiguration.swift | 28 | GAP | v0.2 port per review; new app has no Info.plist helper yet. | none |
| AppleSpeechTranscriptionProvider.swift | 147 | GAP | v0.2 push-to-talk STT port; new app has no mic/STT pipeline yet. | none |
| AssemblyAIStreamingTranscriptionProvider.swift | 478 | SKIP | Retired per spec — API-key provider replaced by Apple Speech fallback. | none |
| BuddyAudioConversionSupport.swift | 108 | GAP | v0.2 PCM16 / WAV helpers for mic capture; not needed until push-to-talk lands. | none |
| BuddyDictationManager.swift | 866 | GAP | v0.2 push-to-talk pipeline (AVAudioEngine + PTT lifecycle); needs lean port. | none |
| BuddyTranscriptionProvider.swift | 100 | GAP | v0.2 STT protocol + factory; lean port keeps only AppleSpeech branch. | none |
| ClaudeAPI.swift | 291 | OK | Legacy URLSession→Worker transport replaced by CLI subprocess (Pencil pattern). | ClaudeCLIRunner.swift |
| ClickyAnalytics.swift | 121 | SKIP | PostHog retired per spec — zero telemetry in v1 product. | none |
| CompanionManager.swift | 1026 | OK | v0.1 slice covered (CLI probe, turn runner, session load/save); grows as v0.2/v0.3 features land. | ClickyViewModel.swift |
| CompanionPanelView.swift | 761 | OK | v0.1 panel shipped (install banner + prompt + Test Claude + streaming); v0.2 adds model picker + perms block. | PanelView.swift |
| CompanionResponseOverlay.swift | 217 | GAP | v0.3 cursor-overlay response bubble + waveform; depends on OverlayWindow port. | none |
| CompanionScreenCaptureUtility.swift | 132 | OK | Single-display capture covered in v0.1; multi-display + cursor-screen metadata deferred to v0.2. | ScreenCapture.swift |
| DesignSystem.swift | 880 | OK | Visual tokens provided inline in PanelView.swift; DS consolidation is v0.2 refactor, not user-visible. | PanelView.swift |
| ElementLocationDetector.swift | 335 | GAP | v0.3 decision pending — may be superseded by OmniParser V2 local model. | none |
| ElevenLabsTTSClient.swift | 81 | SKIP | Retired per spec — v0.2 TTS will be fresh AVSpeechSynthesizer wrapper, no port. | none |
| GlobalPushToTalkShortcutMonitor.swift | 132 | GAP | v0.2 foundation — CGEvent tap for ⌃⌥ push-to-talk, needs Accessibility on Clicky.app. | none |
| MenuBarPanelManager.swift | 243 | OK | Status item + panel lifecycle in AppDelegate; click-outside-dismiss polish is v0.2. | App.swift |
| OpenAIAPI.swift | 142 | SKIP | Retired per spec — OpenAI vision fallback removed; Claude via CLI is the only LLM path. | none |
| OpenAIAudioTranscriptionProvider.swift | 317 | SKIP | Retired per spec — STT defaults to Apple Speech; no OpenAI Whisper fallback. | none |
| OverlayWindow.swift | 881 | GAP | v0.3 flagship — blue cursor overlay + POINT bezier flight animation; largest single port ahead. | none |
| WindowPositionManager.swift | 262 | OK | Panel positioning inline in AppDelegate; Screen Recording + Accessibility helpers deferred to v0.2. | App.swift |
| leanring_buddyApp.swift | 89 | OK | @main + NSApplicationDelegateAdaptor already wired in new app. | App.swift |

## Iteration log

_Ralph appends a brief note here per iteration (file name + verdict) so
progress is auditable even if the Rows table is truncated._

- AppBundleConfiguration.swift → GAP | 2026-04-21
- AppleSpeechTranscriptionProvider.swift → GAP | 2026-04-21
- AssemblyAIStreamingTranscriptionProvider.swift → SKIP | 2026-04-21
- BuddyAudioConversionSupport.swift → GAP | 2026-04-21
- BuddyDictationManager.swift → GAP | 2026-04-21
- BuddyTranscriptionProvider.swift → GAP | 2026-04-21
- ClaudeAPI.swift → OK | 2026-04-21
- ClickyAnalytics.swift → SKIP | 2026-04-21
- CompanionManager.swift → OK (partial, grows) | 2026-04-21
- CompanionPanelView.swift → OK (partial, grows) | 2026-04-21
- CompanionResponseOverlay.swift → GAP | 2026-04-21
- CompanionScreenCaptureUtility.swift → OK (partial, grows) | 2026-04-21
- DesignSystem.swift → OK (inline colors) | 2026-04-21
- ElementLocationDetector.swift → GAP (v0.3 TBD) | 2026-04-21
- ElevenLabsTTSClient.swift → SKIP | 2026-04-21
- GlobalPushToTalkShortcutMonitor.swift → GAP | 2026-04-21
- MenuBarPanelManager.swift → OK (dismiss-polish pending) | 2026-04-21
- OpenAIAPI.swift → SKIP | 2026-04-21
- OpenAIAudioTranscriptionProvider.swift → SKIP | 2026-04-21
- OverlayWindow.swift → GAP (v0.3 flagship) | 2026-04-21
- WindowPositionManager.swift → OK (perm helpers pending) | 2026-04-21
- leanring_buddyApp.swift → OK | 2026-04-21

**Completed 2026-04-21.** All 22 legacy Swift files validated against the new app.
Tally: OK = 8, GAP = 9, SKIP = 5 (total 22).

- **OK (8)** — ClaudeAPI, CompanionManager, CompanionPanelView, CompanionScreenCaptureUtility, DesignSystem, MenuBarPanelManager, WindowPositionManager, leanring_buddyApp. Functionality present in new app today (some partial, growing with v0.2/v0.3).
- **GAP (9)** — AppBundleConfiguration, AppleSpeechTranscriptionProvider, BuddyAudioConversionSupport, BuddyDictationManager, BuddyTranscriptionProvider, CompanionResponseOverlay, ElementLocationDetector, GlobalPushToTalkShortcutMonitor, OverlayWindow. Awaiting v0.2 (push-to-talk stack) or v0.3 (overlay flagship) port.
- **SKIP (5)** — AssemblyAIStreamingTranscriptionProvider, ClickyAnalytics, ElevenLabsTTSClient, OpenAIAPI, OpenAIAudioTranscriptionProvider. Retired per spec — not ported, now or later.

Zero contradictions with `swift-app-port-review.md`. Ready for /seldon consolidated sweep when user requests it.
- NOTE: per-iteration /seldon invocation is skipped — seldon's own prior review called this loop the wrong use of that tool (one-shot plan review, not per-file verifier). A single consolidated /seldon sweep will run after the final PENDING row is resolved. 2026-04-21
