# ScreenCaptureKit TCC Probe Report

Date: 2026-04-22
Host macOS: Darwin 25.3.0 (arm64)
Goal: isolate whether SCK failures inside Clicky.app are a per-process TCC cache issue or a machine-wide adhoc-signature rejection.

## Probe source

`/tmp/sck-probe.swift` — calls `CGPreflightScreenCaptureAccess()`, counts foreign named windows via `CGWindowListCopyWindowInfo`, then awaits `SCShareableContent.current`.

Compiled with `swiftc -parse-as-library /tmp/sck-probe.swift -o /tmp/sck-probe` (required because `@main` forbids top-level code).

## Run A — Unsigned binary (`/tmp/sck-probe`)

```
== CGPreflight: true
== CGWindowList foreign-named windows: 6 of 8 total
== SCShareableContent OK: 2 displays, 64 apps
```

Exit 0. SCK returned 2 displays and 64 apps. CGWindowList exposed 6 foreign-owned named windows (live TCC probe succeeds).

## Run B — Adhoc-signed `Probe.app`

Signed with the same flags as `clicky-ai-plugin/native/Makefile` (`codesign --force --sign - --identifier com.proyecto26.clicky.probe`). `codesign -dv` confirms `flags=0x2(adhoc)` and `Signature=adhoc`, mirroring the Clicky.app signature class.

```
== CGPreflight: true
== CGWindowList foreign-named windows: 6 of 8 total
== SCShareableContent OK: 2 displays, 64 apps
```

Exit 0. Identical to Run A.

## Run C — Clicky.app itself

Clicky (PID 65630) is running. `log show --predicate 'process == "clicky"' --last 30m` shows at 00:39:28 a successful call sequence:

- `[INFO] +[SCShareableContent getShareableContentWithCompletionHandler:]:46`
- `-[RPDaemonProxy fetchShareableContentWithOption:windowID:currentProcess:transactionID:withCompletionHandler:]:989`

with no subsequent TCC denial, sandbox error, or ReplayKit failure. The only `Error` entries are unrelated `-[NSWindow makeKeyWindow] … canBecomeKeyWindow` warnings on the companion panel.

## Verdict

This is **not** a machine-wide adhoc-TCC rejection. A freshly compiled adhoc-signed app bundle with a Clicky-style identifier (`com.proyecto26.clicky.probe`) gets full SCK access on this exact machine right now, and the current `clicky` process is itself calling `SCShareableContent` successfully in the live logs.

If the user is seeing an SCK failure inside Clicky.app today, it is almost certainly the **per-process SCK / ReplayKit cache** that surfaces after TCC toggles, bundle rebuilds, or long-running sessions. The recovery is process-scoped, not system-scoped.

## Next step

Fully quit Clicky (menu quit, then `pkill -f 'Clicky.app/Contents/MacOS/clicky'` if it lingers), wait ~2 s for `replayd` to release the cached sandbox extension, and relaunch from Finder. If SCK still fails after a clean relaunch, capture `log stream --predicate 'process == "clicky" OR process == "replayd"'` during the failing call and diff against the healthy 00:39:28 trace above — that will localise which step (TCC gate, replayd proxy, or SCK wrapper) is returning the error.

## Artefacts cleaned

`/tmp/sck-probe.swift`, `/tmp/sck-probe`, `/tmp/Probe.app`, `/tmp/sck-probe-unsigned.txt`, `/tmp/sck-probe-adhoc.txt` removed after report generation.
