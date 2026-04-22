# TCC Identity Audit — Clicky.app Screen Recording

## Verdict

**Unverifiable from shell, but strongly suspected MISMATCH** — the running binary and on-disk bundle are byte-identical (same path, same cdhash), but the binary is **adhoc-signed with no stable Team/Designated Requirement**. Any rebuild of `native/Clicky.app` will produce a new cdhash, and TCC's stored `csreq` (locked to the prior cdhash) will no longer match. This matches the observed symptom: toggle appears ON in System Settings but `SCShareableContent.current` throws "user declined TCCs."

## Bundle identity (on-disk)

```
CFBundleExecutable  => "clicky"
CFBundleIdentifier  => "com.proyecto26.clicky"
CFBundleVersion     => "1"

Identifier       = com.proyecto26.clicky
Format           = app bundle with Mach-O thin (arm64)
CodeDirectory    = flags=0x10002(adhoc,runtime)
Signature        = adhoc
TeamIdentifier   = not set
CDHash (sha256)  = d302e40a331246ab2ac3a6a38d2203b82a0aa800
Internal requirements count = 0
```

Entitlements include `com.apple.security.device.audio-input=true`, `app-sandbox=false`, and mach-lookup for `com.apple.screencapturekit.picker`. **No `com.apple.security.temporary-exception` for screen capture** — ScreenCaptureKit does not require one, TCC gates it directly.

## Spotlight / macOS view

```
mdfind -name "Clicky.app"                                 → (empty, Spotlight hasn't indexed this path)
mdfind "kMDItemCFBundleIdentifier == com.proyecto26.clicky" → /Users/jdnichollsc/dev/ai/clicky/clicky-ai-plugin/native/Clicky.app
```

Only one bundle with that identifier exists. No stale copy elsewhere.

## TCC DB

```
Error: unable to open database ".../com.apple.TCC/TCC.db": unable to open database file
```

Expected — the shell lacks Full Disk Access. Cannot directly inspect stored `csreq` / cdhash anchor.

## Running instance

```
PID   65630
exe   /Users/jdnichollsc/dev/ai/clicky/clicky-ai-plugin/native/Clicky.app/Contents/MacOS/clicky
```

Same path as on-disk bundle → running cdhash = `d302e40a331246ab2ac3a6a38d2203b82a0aa800`. If TCC was granted against a *previous* build at this path, the cdhash has since changed and TCC silently refuses despite the UI toggle showing ON.

## Root cause hypothesis

Adhoc signing produces **cdhash-locked** TCC entries (since there is no Team ID / Developer ID anchor to pin against). Every rebuild invalidates the grant. The toggle in System Settings still references the stale cdhash; macOS doesn't auto-reconcile, so the user sees "ON" while the kernel denies access.

## Fix options (in order of robustness)

1. **Reset + regrant per build** (dev-loop fix):
   ```
   tccutil reset ScreenCapture com.proyecto26.clicky
   ```
   Then toggle ON again. Do this after every rebuild until stably signed.

2. **Stable codesign identity** (real fix): sign with a Developer ID Application cert and a designated requirement. Team-anchored TCC entries survive rebuilds because `csreq` matches on `anchor apple generic and certificate leaf[subject.OU]=TEAMID`, not cdhash.

3. **Ship to `/Applications`**: not strictly required, but TCC heuristics are more forgiving for apps in standard locations; combined with stable signing it eliminates path-based edge cases.

4. Verify post-fix with `codesign -dr - <app>` — the designated requirement should reference the Team ID, not `cdhash H"..."`.