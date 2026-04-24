//
//  OverlayManager.swift
//  Owns the per-display OverlayWindow pool and publishes the current
//  POINT target so BlueCursorView instances can animate. Created once
//  in ClickyViewModel.init and kept for the app lifetime.
//
//  Key behaviours:
//    - Creates / destroys overlay windows as displays connect and
//      disconnect (NSApplication.didChangeScreenParameters).
//    - Only one target at a time — activeTarget is @Published so every
//      BlueCursorView can observe changes reactively.
//    - clearTargetIfMatches avoids race conditions when a second POINT
//      lands while the previous cursor is still flying back.
//

import AppKit
import Combine
import Foundation
import SwiftUI
import os

@MainActor
final class OverlayManager: ObservableObject {
    /// Current POINT target being visualised. Nil when no animation
    /// in progress. Published so every BlueCursorView can observe and
    /// decide whether to show/hide based on screenFrame match.
    @Published private(set) var activeTarget: BlueCursorTarget?

    /// Mirror of ClickyViewModel.state so each BlueCursorView can render
    /// the right shape at the cursor (triangle / waveform / spinner).
    /// Wired by ClickyViewModel via Combine to keep OverlayManager free
    /// of a back-reference to the view model.
    @Published var voiceState: CompanionState = .idle

    /// Mirror of ClickyViewModel.currentAudioLevel for the listening
    /// waveform. 0…1 normalised mic power.
    @Published var audioLevel: CGFloat = 0

    /// Mirror of ClickyViewModel.streamingText (the POINT-stripped reply
    /// text). Empty string means no bubble; otherwise each BlueCursorView
    /// on the cursor's / target's display renders a floating bubble
    /// beside the buddy. ClickyViewModel is responsible for clearing
    /// this after the auto-hide window so stale replies don't linger.
    @Published var streamingResponseText: String = ""

    private let logger = Logger(subsystem: "com.proyecto26.clicky", category: "OverlayManager")
    private var windows: [OverlayWindow] = []
    private var screenParameterObserver: NSObjectProtocol?

    init() {
        installScreenParameterObserver()
        rebuildWindowsForCurrentScreens()
    }

    deinit {
        if let observer = screenParameterObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Drive the blue cursor to `target`. Replaces any in-flight
    /// animation. The BlueCursorView for the matching display picks
    /// it up via Combine and starts the flight.
    func flyTo(_ target: BlueCursorTarget) {
        let frames = windows.map { $0.frame }
        logger.info("flyTo target=\(String(describing: target.globalLocation), privacy: .public) displayFrame=\(String(describing: target.displayFrame), privacy: .public) label=\(target.label ?? "nil", privacy: .public) windows=\(self.windows.count, privacy: .public) windowFrames=\(String(describing: frames), privacy: .public)")
        ensureWindowsVisible()
        activeTarget = target
    }

    /// Unconditionally drops the current POINT target + clears the
    /// response bubble. Used by ClickyViewModel.cancelCurrentTurn so
    /// an interrupted turn leaves zero residue on screen.
    func reset() {
        activeTarget = nil
        streamingResponseText = ""
    }

    /// Called by a BlueCursorView when it finishes its fly-back-to-
    /// cursor animation. We only clear if the current activeTarget
    /// is the one that just finished, so a newly-dispatched target
    /// doesn't get overwritten.
    func clearTargetIfMatches(target screenFrame: CGRect) {
        guard let active = activeTarget,
              active.displayFrame.origin == screenFrame.origin,
              active.displayFrame.size == screenFrame.size else { return }
        activeTarget = nil
        // Leave windows on screen; they're transparent and cheap to
        // keep mounted. They hide visually when opacity drops to 0.
    }

    // MARK: - Private

    private func installScreenParameterObserver() {
        screenParameterObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.rebuildWindowsForCurrentScreens()
            }
        }
    }

    private func rebuildWindowsForCurrentScreens() {
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows = NSScreen.screens.map { screen in
            let view = BlueCursorView(screenFrame: screen.frame, manager: self)
            let window = OverlayWindow(screen: screen, rootView: AnyView(view))
            // Order front immediately so the NSHostingView activates its
            // SwiftUI subscriptions now — otherwise the first @Published
            // activeTarget can arrive before .onReceive is wired up.
            window.orderFrontRegardless()
            return window
        }
        let screenFrames = NSScreen.screens.map(\.frame)
        logger.info("Rebuilt \(self.windows.count, privacy: .public) overlay window(s) for \(NSScreen.screens.count, privacy: .public) display(s); frames=\(String(describing: screenFrames), privacy: .public)")
    }

    private func ensureWindowsVisible() {
        for window in windows where !window.isVisible {
            window.orderFrontRegardless()
        }
    }
}
