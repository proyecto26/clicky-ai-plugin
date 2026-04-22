//
//  ClickyViewModel.swift
//  Observable state for the panel. Probes the `claude` CLI on launch,
//  exposes turn-running state, and persists session IDs across launches.
//

import Combine
import Foundation
import SwiftUI
import os

@MainActor
final class ClickyViewModel: ObservableObject {
    @Published var isClaudeCLIAvailable: Bool = true
    @Published var claudeBinaryPath: String?
    @Published var claudeVersion: String?
    @Published var isRunningTurn: Bool = false
    @Published var streamingText: String = ""
    @Published var lastError: String?
    @Published var lastSessionId: String?
    @Published var hasScreenRecordingPermission: Bool = true

    private let logger = Logger(subsystem: "com.proyecto26.clicky", category: "ClickyViewModel")
    private var currentTask: Task<Void, Never>?

    /// System prompt derived from the upstream Clicky persona. Kept tight so
    /// the CLI's input tokens stay low and the reply matches the text-surface
    /// of this v0.1 panel (no TTS yet).
    static let systemPrompt: String = """
    you're clicky, a friendly screen-aware companion. the user is looking at their mac screen. \
    reply in one or two sentences, lowercase, warm, conversational. no emojis, no bullet lists, \
    no markdown. reference specific things on screen when relevant. if you want to flag a ui \
    element, append a tag `[POINT:x,y:label]` at the end where x,y are pixel coordinates in the \
    screenshot's pixel space and label is 1-3 words. if pointing wouldn't help, omit the tag.
    """

    /// Refreshes the CLI probe so the panel shows an accurate install banner.
    func refreshClaudeCLIStatus() async {
        do {
            let binary = try ClaudeCLIRunner.locate()
            let version = await ClaudeCLIRunner.probeVersion(at: binary)
            isClaudeCLIAvailable = true
            claudeBinaryPath = binary.path
            claudeVersion = version
        } catch {
            isClaudeCLIAvailable = false
            claudeBinaryPath = nil
            claudeVersion = nil
        }
        hasScreenRecordingPermission = ScreenRecordingPermission.isGranted()
    }

    /// Triggers the macOS Screen Recording TCC prompt. Users often need to
    /// quit and relaunch Clicky after granting — that behaviour is surfaced
    /// in the panel copy, not silently handled here.
    func requestScreenRecordingPermission() {
        ScreenRecordingPermission.request()
        // Re-probe so the banner updates if the user grants immediately.
        hasScreenRecordingPermission = ScreenRecordingPermission.isGranted()
    }

    func openScreenRecordingSettings() {
        ScreenRecordingPermission.openSystemSettings()
    }

    /// Captures the primary display and runs a single turn through the CLI.
    /// The "what's on my screen?" prompt exercises the full image + stream
    /// pipeline without requiring voice input yet.
    func runTestTurn(userPrompt: String) {
        guard !isRunningTurn else { return }
        currentTask?.cancel()
        isRunningTurn = true
        streamingText = ""
        lastError = nil

        currentTask = Task { @MainActor in
            defer { isRunningTurn = false }
            do {
                let frame = try await ScreenCapture.capturePrimaryDisplay()
                let binary = try ClaudeCLIRunner.locate()
                let runner = ClaudeCLIRunner(binaryURL: binary)
                let resume = SessionPersistence.shared.load()

                let message = ClaudeCLIMessage(
                    role: .user,
                    text: "\(frame.label) (image dimensions: \(frame.widthPx)x\(frame.heightPx) pixels)\n\(userPrompt)",
                    images: [
                        ClaudeCLIMessage.Image(
                            mediaType: "image/jpeg",
                            base64: frame.jpegData.base64EncodedString()
                        ),
                    ]
                )

                let result = try await runner.ask(
                    messages: [message],
                    systemPrompt: Self.systemPrompt,
                    model: "claude-sonnet-4-6",
                    resumeSessionId: resume
                ) { [weak self] chunk in
                    Task { @MainActor [weak self] in
                        self?.streamingText = chunk.accumulatedText
                    }
                }

                if let sessionId = result.sessionId {
                    lastSessionId = sessionId
                    SessionPersistence.shared.save(sessionId: sessionId)
                }
            } catch is CancellationError {
                lastError = "Cancelled."
            } catch let error as ClaudeCLIError {
                lastError = error.description
            } catch let error as ScreenCaptureError {
                lastError = error.description
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func cancelCurrentTurn() {
        currentTask?.cancel()
    }

    func clearConversation() {
        SessionPersistence.shared.clear()
        lastSessionId = nil
        streamingText = ""
        lastError = nil
    }

    func openClaudeCodeInstallPage() {
        guard let url = URL(string: "https://claude.com/claude-code") else { return }
        NSWorkspace.shared.open(url)
    }
}
