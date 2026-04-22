//
//  TextToSpeech.swift
//  Minimal AVSpeechSynthesizer wrapper used to speak Claude's reply
//  (with POINT tags already stripped by PointTagParser).
//
//  Design notes:
//  - Wrapping AVSpeechSynthesizer rather than importing it directly
//    at call sites lets the ViewModel await "finished speaking" via
//    a completion continuation — useful when chaining TTS to cursor
//    animations in v0.3.
//  - Voice / rate / pitch are left at AVSpeechUtterance defaults so
//    they track the user's System Settings → Accessibility → Spoken
//    Content preferences (personality + locale). Power users get to
//    pick a voice once at the OS level and every app respects it.
//

import AVFoundation
import Foundation
import os

@MainActor
final class TextToSpeech: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private let logger = Logger(subsystem: "com.proyecto26.clicky", category: "TextToSpeech")
    private var activeContinuation: CheckedContinuation<Void, Never>?

    @Published private(set) var isSpeaking: Bool = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speaks `text` and returns when AVSpeechSynthesizer finishes (or
    /// the utterance is cancelled via `stop()`). Safe to call concurrently
    /// — a new utterance replaces the in-flight one.
    func speak(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Cancel anything currently speaking so the new utterance plays
        // immediately rather than queueing.
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            resumeActiveContinuation()
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        // Leaving voice/rate/volume at defaults; macOS uses the user's
        // Spoken Content preferences. Override here if product copy
        // ever demands a specific personality.
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            activeContinuation = continuation
            isSpeaking = true
            synthesizer.speak(utterance)
        }
    }

    /// Cancels any in-flight utterance immediately.
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        resumeActiveContinuation()
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.isSpeaking = false
            self.resumeActiveContinuation()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.isSpeaking = false
            self.resumeActiveContinuation()
        }
    }

    private func resumeActiveContinuation() {
        guard let continuation = activeContinuation else { return }
        activeContinuation = nil
        continuation.resume()
    }
}
