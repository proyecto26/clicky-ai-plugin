//
//  ScreenRecordingPermission.swift
//  macOS 11+ ships CGPreflightScreenCaptureAccess / CGRequestScreenCaptureAccess
//  in CoreGraphics. These let us check TCC without actually calling
//  ScreenCaptureKit — so the panel can show a clear "grant permission"
//  state before the first turn instead of surfacing a cryptic capture
//  error after the user clicks Test Claude.
//

import AppKit
import CoreGraphics
import Foundation

enum ScreenRecordingPermission {
    /// True if Clicky currently has Screen Recording permission.
    /// Non-blocking, safe to call any time.
    static func isGranted() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }

    /// Triggers the system TCC prompt. Returns immediately with a boolean
    /// reflecting current state — the actual grant happens out-of-process
    /// when the user toggles the Clicky entry in System Settings.
    ///
    /// After the user toggles, macOS may require a full app relaunch for
    /// the new permission to take effect. Callers should surface that
    /// expectation to the user.
    @discardableResult
    static func request() -> Bool {
        return CGRequestScreenCaptureAccess()
    }

    /// Opens System Settings directly to the Screen Recording pane so the
    /// user doesn't have to hunt for it.
    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
}
