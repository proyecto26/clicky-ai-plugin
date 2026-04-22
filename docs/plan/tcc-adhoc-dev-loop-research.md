# TCC + Ad-hoc Dev-Loop Research

## TL;DR

Every rebuild with `codesign -s -` mints a new cdhash, which macOS treats as a new principal for TCC, so Screen Recording grants don't survive. **Apple DTS's explicit recommendation is to use a stable signing identity — "Apple Developer for day-to-day work and Developer ID for final distribution"** ([forum 730043](https://developer.apple.com/forums/thread/730043)). The community-accepted dev-loop fix used by AltTab (self-signed local cert with the Apple code-signing OID) and OBS (`-DOBS_CODESIGN_TEAM`) avoids ad-hoc entirely for day-to-day work; `tccutil reset` is a last resort, not a strategy.

---

## Root cause, restated

TCC keys grants on the app's designated requirement (DR). Apple-issued identities produce a stable DR (`anchor apple generic and certificate leaf[subject.OU] = TEAMID and identifier BUNDLE`). Ad-hoc has no leaf cert, so the DR collapses to `cdhash H"..."` — which changes every build. OBS's build wiki states it bluntly: "macOS stores application permissions … based on code signatures … permissions not being applied to updated binaries (the underlying hashes will not match the entry in macOS' database)" ([OBS wiki](https://github.com/obsproject/obs-studio/wiki/build-instructions-for-mac)). See Apple's [TN3127](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements) for the DR mechanism.

---

## Per-project findings

**1. OBS Studio — stable Team ID via CMake.** Two flags: `-DOBS_CODESIGN_TEAM=<TEAMID>` for local Xcode auto-signing, `-DOBS_CODESIGN_IDENTITY="Developer ID Application: …"` for CI. Ad-hoc is acceptable only for "local execution without CI distribution" and explicitly flagged as the cause of permission churn ([build wiki](https://github.com/obsproject/obs-studio/wiki/build-instructions-for-mac), [permissions guide](https://obsproject.com/kb/macos-permissions-guide)). No `tccutil reset` escape hatch — they steer to a stable identity.

**2. AltTab — self-signed cert with the Apple code-signing OID.** Closest match to Clicky's constraints. [`setup_local.sh`](https://github.com/lwouis/alt-tab-macos/blob/master/scripts/codesign/setup_local.sh) calls [`generate_selfsigned_certificate.sh`](https://github.com/lwouis/alt-tab-macos/blob/master/scripts/codesign/generate_selfsigned_certificate.sh) to mint a 2048-bit RSA cert with:

```
basicConstraints     = critical,CA:false
keyUsage             = critical,digitalSignature
extendedKeyUsage     = critical,1.3.6.1.5.5.7.3.3   # id-kp-codeSigning
1.2.840.113635.100.6.1.14 = critical,DER:0500       # Apple "code signing" OID
```

The Apple OID `1.2.840.113635.100.6.1.14` is what makes `codesign` accept the cert as a code-signing identity. Imported into login keychain with a random password; xcodebuild signs against a fixed CN; DR stable across rebuilds without Apple's CA. [Contributing guide](https://alt-tab.app/contributing) spells out the motivation: "to avoid having to re-check the System Preferences > Security & Privacy permissions on every build." **This is the pattern to copy when a real Apple ID isn't available.**

**3. Rectangle** ([rxhanson/Rectangle](https://github.com/rxhanson/Rectangle)): no public docs on dev-loop signing. **Unknown.**

**4. Stats** ([exelban/stats](https://github.com/exelban/stats)): has a Makefile but README doesn't discuss dev signing or TCC resets. **Unknown.**

**5. LuLu / BlockBlock (Objective-See):** ship with Developer ID from day one; I found no primary source discussing ad-hoc dev churn. **Doesn't apply.**

**6. Ice** ([jordanbaird/Ice](https://github.com/jordanbaird/Ice)): README doesn't document a dev-loop signing script. Users run `tccutil reset All com.jordanbaird.Ice` after reinstalls. **Unknown.**

**7. Loom / CleanShot X:** commercial, no primary-source blog post on their ad-hoc dev loop. They ship Developer ID.

**8. karaggeorge/mac-screen-capture-permissions:** the [README](https://github.com/karaggeorge/mac-screen-capture-permissions) documents only runtime APIs; `resetPermissions()` wraps `tccutil reset ScreenCapture <bundleId>`. **Doesn't address the build-loop problem.**

**9. Electron:** runtime-only solution — [PR #43080](https://github.com/electron/electron/pull/43080) preflights via `CGRequestScreenCaptureAccess()`. [desktopCapturer docs](https://www.electronjs.org/docs/latest/api/desktop-capturer) don't address cdhash churn. App devs inherit the `electron` binary's Developer ID, masking the issue.

**10. Apple's ScreenCaptureKit sample code** ([Capturing screen content in macOS](https://developer.apple.com/documentation/ScreenCaptureKit/capturing-screen-content-in-macos)): says "After you grant permission, restart the app to enable capture." Does **not** address fresh-ad-hoc-every-build. Apple's only primary-source guidance is on forums — [thread 730043](https://developer.apple.com/forums/thread/730043), Quinn:

> "when dealing with TCC it's best to sign your code with a stable signing identity, typically, Apple Developer for day-to-day work and Developer ID for final distribution. Doing this will radically cut down on the amount of TCC thrash."

---

## Answers to the specific questions

**Q1. Any well-known OSS app with a Makefile/script for the ad-hoc cdhash loop?** Yes — **AltTab**. Not via `tccutil reset` but by avoiding ad-hoc: `scripts/codesign/setup_local.sh` generates a local self-signed cert (with the Apple code-signing OID) once, so every `xcodebuild` produces a stable DR. OBS uses the same idea via a real Apple Team ID (`-DOBS_CODESIGN_TEAM`). I found no project that uses `tccutil reset` between builds as its primary strategy — the community treats it as a symptom fix.

**Q2. Community best practice**, in priority order:
1. **Stable identity.** Free Apple Development cert via Xcode Personal Team ([Certificates overview](https://developer.apple.com/help/account/certificates/certificates-overview/)) or AltTab-style self-signed cert. Apple DTS explicitly recommends option 1.
2. **Install to `/Applications/`.** TCC's DR check is identity-based, not path-based, but running from `DerivedData` interacts poorly with quarantine and some TCC heuristics. `/Applications/` is the cleanest location.
3. **`tccutil reset ScreenCapture <bundle-id>`** as a nuclear option when identity changes (e.g. switching ad-hoc → Apple Development). Not a per-build fix.
4. **`codesign --preserve-metadata`** is for re-signing; doesn't anchor TCC across cdhash changes.

**Q3. Re-prompt vs first-time denial.** No public API distinguishes. Practical heuristic: persist a `UserDefaults` flag `didPreviouslyGrantScreenRecording`. If preflight is false but the flag is true, show a "you may have rebuilt — run `tccutil reset ScreenCapture <id>` or sign stably" hint. Cross-check with the `CGWindowListCopyWindowInfo` live probe already shipped in Clicky's `screen-recording-tcc-research.md`.

**Q4. `--preserve-metadata` / custom DR.** `--preserve-metadata=entitlements,requirements,flags` preserves whatever's in the source signature — doesn't synthesise a stable DR. A custom `codesign -r='...'` DR can pin TCC but still needs a stable cert to anchor to. No well-known OSS project uses a hand-rolled DR to persist TCC across ad-hoc rebuilds.

**Q5. Apple's guidance on the ad-hoc dev loop.** **Not in reference docs, not in the ScreenCaptureKit sample README.** Only on Apple forums via DTS "Quinn" ([thread 730043](https://developer.apple.com/forums/thread/730043), quoted above). The sample just says "restart the app to enable capture."

**Q6. Free Apple Development cert via Personal Team.** Confirmed. Any Apple ID → Xcode → Signing & Capabilities → Team → Personal Team issues a free Apple Development cert sufficient for local runs ([Apple Certificates overview](https://developer.apple.com/help/account/certificates/certificates-overview/)). **Not** enough for notarization, Mac App Store, or Gatekeeper-friendly distribution — those need paid Developer ID ($99/yr, [Developer ID page](https://developer.apple.com/developer-id/)). For a dev loop: enough. Personal Teams get a stable 10-char team ID, which pins TCC.

**Q7. Recommendation for Clicky.** **Free Personal Team Apple Development cert in Debug**, ad-hoc only as a fallback when no Apple ID is configured. CI/release uses the real Developer ID. Rationale: (a) matches Apple DTS's explicit primary-source recommendation; (b) zero runtime friction — no `tccutil reset` loop; (c) aligns Debug and Release DR shapes, so TCC behaviour in dev matches production; (d) free; (e) survives `make clean`, cache wipes, and Xcode upgrades. AltTab's self-signed approach is the right fallback for contributors without an Apple ID.

---

## Concrete drop-in additions

### Xcode Debug signing (primary fix)
In `leanring-buddy.xcodeproj` → target `leanring-buddy` → Signing & Capabilities → **Debug**:
- Team: *your* Personal Team (sign into Xcode with your Apple ID once).
- Signing Certificate: `Apple Development`
- `CODE_SIGN_STYLE = Automatic`
- Leave Release as-is (Developer ID via GitHub Actions).

### Makefile additions
```make
BUNDLE_ID := com.leanring.buddy          # match your actual Info.plist
DERIVED    := $(HOME)/Library/Developer/Xcode/DerivedData
APP        := /Applications/leanring-buddy.app

.PHONY: dev install reset-tcc doctor

dev:
	xcodebuild -project leanring-buddy.xcodeproj \
	           -scheme leanring-buddy \
	           -configuration Debug \
	           CODE_SIGN_STYLE=Automatic \
	           build

# Install to /Applications/ so TCC + Gatekeeper see a stable location.
install: dev
	rm -rf "$(APP)"
	cp -R "$$(xcodebuild -project leanring-buddy.xcodeproj -scheme leanring-buddy -configuration Debug -showBuildSettings | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $$2}')/leanring-buddy.app" /Applications/
	codesign --verify --deep --strict "$(APP)"
	spctl --assess --type execute --verbose=4 "$(APP)" || true
	open "$(APP)"

# Nuclear option: only when you knowingly changed signing identity.
reset-tcc:
	tccutil reset ScreenCapture $(BUNDLE_ID)
	tccutil reset Accessibility $(BUNDLE_ID)
	tccutil reset Microphone    $(BUNDLE_ID)

# Diagnose what DR the current binary carries — verifies stability.
doctor:
	@codesign -d --requirements - "$(APP)" 2>&1 | sed -n 's/^designated =>/DR:/p' || true
	@codesign -dv --verbose=4 "$(APP)" 2>&1 | grep -E 'Authority|TeamIdentifier|Identifier'
```

Run `make doctor` before and after a rebuild — the `DR:` line should be **identical** across rebuilds when you're on a stable identity, and contain `cdhash H"..."` (different every build) when you're on ad-hoc. That's your canary.

### Contributor fallback (no Apple ID)
Port AltTab's [generate_selfsigned_certificate.sh](https://github.com/lwouis/alt-tab-macos/blob/master/scripts/codesign/generate_selfsigned_certificate.sh) verbatim — the OID list above is the load-bearing part — and point `CODE_SIGN_IDENTITY` to the imported cert's CN.

---

## Known unknowns (stated honestly)

- Rectangle, Stats, Ice, Loom, CleanShot X: I could not find primary sources describing their dev-loop signing strategy. Do not cite this report as evidence they do X.
- macOS 26 behaviour for ad-hoc TCC: no primary source on changes. Verify on-device.
- Whether `/Applications/` path itself influences TCC: commonly claimed, not documented by Apple. TCC keys on DR; path affects Gatekeeper + quarantine, which indirectly affect first-launch UX.

## Sources

- [Apple forum 730043 — DTS "Quinn" on TCC + stable signing identity](https://developer.apple.com/forums/thread/730043)
- [Apple TN3127 — Inside Code Signing: Requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)
- [Apple — Capturing screen content in macOS sample](https://developer.apple.com/documentation/ScreenCaptureKit/capturing-screen-content-in-macos)
- [Apple — Signing Mac Software with Developer ID](https://developer.apple.com/developer-id/)
- [Apple — Certificates overview (Personal Team, free Apple Development)](https://developer.apple.com/help/account/certificates/certificates-overview/)
- [OBS wiki — Build Instructions For Mac](https://github.com/obsproject/obs-studio/wiki/build-instructions-for-mac)
- [OBS — macOS Permissions Guide](https://obsproject.com/kb/macos-permissions-guide)
- [AltTab — setup_local.sh](https://github.com/lwouis/alt-tab-macos/blob/master/scripts/codesign/setup_local.sh)
- [AltTab — generate_selfsigned_certificate.sh](https://github.com/lwouis/alt-tab-macos/blob/master/scripts/codesign/generate_selfsigned_certificate.sh)
- [AltTab — Contributing](https://alt-tab.app/contributing)
- [Electron PR #43080 — CGRequestScreenCaptureAccess preflight](https://github.com/electron/electron/pull/43080)
- [Electron desktopCapturer docs](https://www.electronjs.org/docs/latest/api/desktop-capturer)
- [karaggeorge/mac-screen-capture-permissions](https://github.com/karaggeorge/mac-screen-capture-permissions)
- [tccutil(1) reference](https://ss64.com/mac/tccutil.html)
