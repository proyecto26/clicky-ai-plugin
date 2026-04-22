# Screen Recording / TCC Permission: Live Banner Update Research

## TL;DR

`CGPreflightScreenCaptureAccess()` really does cache a `false` result for the lifetime of the process — this is long-standing, acknowledged by Apple DTS ("Quinn"), and still true on macOS 14/15/26. Apple's own ScreenCaptureKit sample code tells users to restart the app after granting permission, so the quit-and-relaunch behaviour is the documented happy path. **But** the banner can be cleared without a restart by (a) listening for the `com.apple.TCC.updated` distributed notification and, on wake / on interval, (b) doing a cheap live probe via `CGWindowListCopyWindowInfo` (which is *not* cached and reflects the current TCC state immediately). That fallback is what `karaggeorge/mac-screen-capture-permissions`, Electron, and most menu-bar apps use.

---

## 1. Is the "quit-and-relaunch" requirement Apple-documented?

**Partly.** It appears in Apple sample code, not the framework reference:

> "The first time you run this sample, the system prompts you to grant the app screen recording permission. After you grant permission, restart the app to enable capture."
> — *Capturing screen content in macOS* sample README ([link](https://developer.apple.com/documentation/ScreenCaptureKit/capturing-screen-content-in-macos), mirrored at [Fidetro/CapturingScreenContentInMacOS](https://github.com/Fidetro/CapturingScreenContentInMacOS)).

The reference pages for `CGPreflightScreenCaptureAccess()` / `CGRequestScreenCaptureAccess()` do not explicitly document the caching or restart requirement. The closest primary source is [Apple forum thread 732726](https://developer.apple.com/forums/thread/732726) where Quinn "The Eskimo!" (Apple DTS) confirms the process-lifetime caching — the OP says "the change in privileges is not reflected in the return value of `CGPreflightScreenCaptureAccess`," Quinn replies "That's right." The system alert itself states the app "may not be able to record … until it is quit." **Verdict:** semi-documented folk wisdom — affirmed by sample code + DTS, not by header or reference docs.

---

## 2. Does `CGPreflightScreenCaptureAccess()` genuinely cache for the process lifetime?

**Yes, on 14/15.** The forum thread above and field reports across 2022–2025 show cached `false` persisting until process exit. On Sequoia 15.1, Apple surfaces user nags for legacy CG\* capture APIs and steers developers to ScreenCaptureKit ([xcap #160](https://github.com/nashaofu/xcap/issues/160)); `CGPreflightScreenCaptureAccess` itself is not formally deprecated. **No primary source documents a behaviour change on macOS 26** — I could not find one and cannot confirm claims about 26.

A common failure mode mistaken for the cache bug: **ad-hoc signing**. TCC keys permissions to code-signing identity; with ad-hoc signing each build is a "new app" and `CGPreflightScreenCaptureAccess` legitimately returns `false` every build. Fix: use *Apple Development* signing for Debug (see Quinn in [forum 683860](https://developer.apple.com/forums/thread/683860)). Worth ruling out — Clicky's current config is adhoc in dev.

---

## 3. Apple's recommended pattern for a "friendly banner → granted → clear" flow with SCK

Apple's sample code just says "restart the app" — it does not solve the live-update case. WWDC22 session 10156 and the 2023 follow-up cover the capture API and the sharing picker but do not prescribe a TCC live-watch pattern. On macOS 15+, `SCContentSharingPicker` sidesteps TCC for per-window capture, but doesn't fit Clicky's silent full-display model. **There is no officially recommended live-watch pattern** — the community pattern below is what ships in practice.

---

## 4. Alternative APIs

- `SCShareableContent.excludingDesktopWindows(_:onScreenWindowsOnly:)` — throws with the "declined TCCs" error when permission is missing; safe to `try`/`catch` but invoking it after a denial costs a round-trip and, per field reports, sometimes re-enters a stale state until restart.
- `SCStream` error codes — same TCC surfacing; no extra signal.
- `CGWindowListCopyWindowInfo(_:_:)` — **not deprecated**, **not cached**, and the canonical passive probe. When screen recording is denied, returned window dictionaries omit `kCGWindowName` / `kCGWindowOwnerName` for windows outside your app. See [karaggeorge/mac-screen-capture-permissions](https://github.com/karaggeorge/mac-screen-capture-permissions/blob/master/screen-capture-permissions.m) and Ryan Thomson's writeup ([ryanthomson.net](https://www.ryanthomson.net/articles/screen-recording-permissions-catalina-mess/)). Note the caveat from the Mozilla Firefox bug ([bugzilla 1627414](https://bugzilla.mozilla.org/show_bug.cgi?id=1627414)): in full-screen mode the on-screen list can be empty.
- `CGWindowListCreateImage` / `CGDisplayStream` — deprecated/obsoleted in macOS 15 ([MacPorts 71136](https://trac.macports.org/ticket/71136)); do not use.
- `TCCAccessPreflight` (private) — SPI; App Store rejection + future-break risk. Not recommended.

---

## 5. What do other apps do?

- **karaggeorge/mac-screen-capture-permissions** (used by many Electron apps including Loom's recorder) — `CGPreflightScreenCaptureAccess()` plus a `CGWindowListCopyWindowInfo` heuristic as the live signal.
- **Electron** — `CGRequestScreenCaptureAccess()` for the prompt + proactive pre-flight before `desktopCapturer.getSources` ([PR #43080](https://github.com/electron/electron/pull/43080)). Accepts that a restart may be needed.
- **CleanShot X / AltTab / most menu-bar apps** — poll + `CGWindowList*` heuristic + a "restart if it still doesn't work" affordance. None is known to solve the cache without a relaunch for capture *itself*; they just update the UI.

No primary source shows a well-known app actually capturing successfully without restart after a fresh grant. The universal approach: clear the banner via live probe, accept that the first capture after grant may still need one restart, or push the user to `SCContentSharingPicker`.

---

## 6. Live TCC-change detection

- **`DistributedNotificationCenter` `com.apple.TCC.updated`** — posted by `tccd` when the TCC DB changes. **Undocumented** (no Apple reference page) but observed stable for years and widely used. Treat as a best-effort hint to re-probe, not a contract. It does not leak which service changed. No entitlement needed.
- **FSEvents on `~/Library/Application Support/com.apple.TCC/TCC.db`** — SIP-protected / Full Disk Access required; fragile. Not recommended.
- **`NSWorkspace.didActivateApplicationNotification`** — fires when the user tabs back from System Settings. Good UX trigger to re-probe.

Using `com.apple.TCC.updated` as a *hint* (not source of truth) is acceptable: it only triggers a re-probe via the public `CGPreflightScreenCaptureAccess` + `CGWindowListCopyWindowInfo` pair. No private APIs.

---

## 7. Recommended implementation

Combine three public signals, re-probe on any:

1. `NSWorkspace.didActivateApplicationNotification` (user returns from System Settings).
2. `com.apple.TCC.updated` distributed notification (best-effort hint).
3. 2 s timer while the banner is showing only.

Probe with **both** `CGPreflightScreenCaptureAccess()` and a `CGWindowListCopyWindowInfo` heuristic — if either reports granted, clear the banner. Keep the "quit to retry" affordance as a tooltip for when `SCShareableContent.current` still fails.

```swift
import AppKit
import CoreGraphics

@MainActor
final class ScreenRecordingPermissionWatcher: ObservableObject {
    @Published private(set) var isScreenRecordingPermissionGranted: Bool = false

    private var permissionPollingTimer: Timer?
    private var distributedTCCObserver: NSObjectProtocol?
    private var applicationDidBecomeActiveObserver: NSObjectProtocol?

    init() {
        isScreenRecordingPermissionGranted = Self.probeScreenRecordingPermission()
    }

    func startWatching() {
        stopWatching()
        distributedTCCObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.TCC.updated"), object: nil, queue: .main
        ) { [weak self] _ in self?.refreshPermissionState() }

        applicationDidBecomeActiveObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refreshPermissionState() }

        permissionPollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshPermissionState() }
        }
    }

    func stopWatching() {
        if let token = distributedTCCObserver {
            DistributedNotificationCenter.default().removeObserver(token)
        }
        if let token = applicationDidBecomeActiveObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
        distributedTCCObserver = nil
        applicationDidBecomeActiveObserver = nil
        permissionPollingTimer?.invalidate()
        permissionPollingTimer = nil
    }

    private func refreshPermissionState() {
        let granted = Self.probeScreenRecordingPermission()
        if granted != isScreenRecordingPermissionGranted {
            isScreenRecordingPermissionGranted = granted
            if granted { stopWatching() } // banner gone, no need to keep polling
        }
    }

    /// Combines the cached-but-official preflight with a live, non-cached
    /// CGWindowList heuristic. Either positive result dismisses the banner.
    private static func probeScreenRecordingPermission() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        return hasScreenRecordingPermissionViaLiveWindowListProbe()
    }

    /// If screen recording is denied, CGWindowListCopyWindowInfo returns
    /// entries without kCGWindowName for windows owned by other processes.
    /// If granted, at least one non-own, non-system window will carry a name.
    private static func hasScreenRecordingPermissionViaLiveWindowListProbe() -> Bool {
        let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        for windowDescription in windowList {
            guard let windowOwnerProcessIdentifier = windowDescription[kCGWindowOwnerPID as String] as? pid_t,
                  windowOwnerProcessIdentifier != ownProcessIdentifier else { continue }
            if let windowName = windowDescription[kCGWindowName as String] as? String, !windowName.isEmpty {
                return true
            }
        }
        return false
    }
}
```

Wire it into `WindowPositionManager.hasScreenRecordingPermission()` (replace the lone `CGPreflightScreenCaptureAccess()` call with `probeScreenRecordingPermission()`), and have the banner observe the watcher's `@Published` state. Start the watcher when the banner appears; stop it when granted.

---

## Risks / gotchas

- **First capture after a fresh grant may still fail**, even though the banner cleared — `SCShareableContent.current` in the same process can still see the cached TCC denial. Mitigation: on `SCShareableContent` error after banner dismiss, show a one-time toast "Permission just granted — please quit and reopen Clicky for capture to activate." Preserves UX *and* handles the macOS limitation.
- **`com.apple.TCC.updated` is undocumented.** Stable for years but could be renamed. Treated here as a hint only; we always re-probe via public APIs.
- **Ad-hoc signing** resets TCC per build. Use *Apple Development* for Debug, or the watcher will look broken locally.
- **`CGWindowListCopyWindowInfo` heuristic is fragile in full-screen mode** ([Firefox bug 1627414](https://bugzilla.mozilla.org/show_bug.cgi?id=1627414)); always combine with `CGPreflightScreenCaptureAccess`.
- **macOS 26**: no primary source on behaviour changes. The code uses only 14+ APIs, but verify on-device.
- **Sequoia 15+ nag** for legacy CG capture: we only use CG for *probing*, not capture. Safe.

## Sources

- [CGPreflightScreenCaptureAccess](https://developer.apple.com/documentation/coregraphics/cgpreflightscreencaptureaccess()), [CGRequestScreenCaptureAccess](https://developer.apple.com/documentation/coregraphics/3656524-cgrequestscreencaptureaccess), [CGWindowListCopyWindowInfo](https://developer.apple.com/documentation/coregraphics/1455137-cgwindowlistcopywindowinfo?language=objc), [SCShareableContent](https://developer.apple.com/documentation/screencapturekit/scshareablecontent), [DistributedNotificationCenter](https://developer.apple.com/documentation/foundation/distributednotificationcenter) — Apple reference docs
- [Capturing screen content in macOS (sample)](https://developer.apple.com/documentation/ScreenCaptureKit/capturing-screen-content-in-macos) + [mirror](https://github.com/Fidetro/CapturingScreenContentInMacOS)
- [Meet ScreenCaptureKit — WWDC22 s10156](https://developer.apple.com/videos/play/wwdc2022/10156/)
- Apple forums: [732726](https://developer.apple.com/forums/thread/732726) (Quinn on caching), [760483](https://developer.apple.com/forums/thread/760483) (TCC + SCK), [683860](https://developer.apple.com/forums/thread/683860) (TCC + signing identity)
- [karaggeorge/mac-screen-capture-permissions](https://github.com/karaggeorge/mac-screen-capture-permissions), [Electron PR #43080](https://github.com/electron/electron/pull/43080), [Mozilla bug 1627414](https://bugzilla.mozilla.org/show_bug.cgi?id=1627414), [xcap #160](https://github.com/nashaofu/xcap/issues/160), [MacPorts 71136](https://trac.macports.org/ticket/71136), [Ryan Thomson — Screen Recording Permissions in Catalina are a Mess](https://www.ryanthomson.net/articles/screen-recording-permissions-catalina-mess/)
