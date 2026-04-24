//
//  SettingsView.swift
//  Inline settings pane — renders inside the main panel rather than a
//  separate sheet window, so macOS doesn't draw its own rounded window
//  chrome on top of ours. The parent PanelView toggles visibility via
//  its showingSettings @State; SettingsView just owns the content and
//  user interactions.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: OpenClickyViewModel
    let onClose: () -> Void

    @State private var apiKey: String = ""
    @State private var voiceId: String = ""
    @State private var saveStatus: SaveStatus = .idle

    enum SaveStatus: Equatable {
        case idle
        case saved
        case cleared
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader

            Text("Paste an ElevenLabs API key and OpenClicky will speak Claude's reply in your chosen voice. Blank falls back to the macOS system voice.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)

            apiKeyField
            voiceIdField

            Text("Find voice IDs at elevenlabs.io/app/voice-lab. Blank uses the default (Rachel).")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.4))

            actionRow

            if let tttsError = viewModel.textToSpeech.lastBackendError {
                backendErrorRow(tttsError)
            }
        }
        .onAppear(perform: loadCurrentValues)
    }

    // MARK: - Subviews

    private var sectionHeader: some View {
        HStack(spacing: 8) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)

            Text("ElevenLabs voice")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            backendBadge
        }
    }

    private var apiKeyField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("API key")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            SecureField("sk-...", text: $apiKey)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
        }
    }

    private var voiceIdField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Voice ID (optional)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            TextField(ElevenLabsConfig.defaultVoiceId, text: $voiceId)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
        }
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button(action: save) {
                Text("Save")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 6).fill(saveButtonColor))
            }
            .buttonStyle(.plain)
            .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)

            Button(action: clear) {
                Text("Clear")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)

            Spacer()

            if saveStatus == .saved {
                statusChip(text: "Saved", color: .green)
            } else if saveStatus == .cleared {
                statusChip(text: "Cleared", color: .orange)
            }
        }
    }

    private var backendBadge: some View {
        let active = viewModel.textToSpeech.elevenLabsConfig != nil
        return Text(active ? "Active" : "System voice")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(active ? .green : .white.opacity(0.5))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(active ? Color.green.opacity(0.15) : Color.white.opacity(0.06)))
    }

    private var saveButtonColor: Color {
        apiKey.trimmingCharacters(in: .whitespaces).isEmpty
            ? Color.blue.opacity(0.35)
            : Color.blue
    }

    /// Persistent chip showing the most recent ElevenLabs failure so
    /// users know when their premium voice didn't actually play. The
    /// text is the raw HTTP / network error so it's actionable (e.g.
    /// "401 Unauthorized" → wrong key; "voice_not_found" → bad voice id).
    private func backendErrorRow(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 10))
                .foregroundColor(.red.opacity(0.85))
            Text(message)
                .font(.system(size: 10))
                .foregroundColor(.red.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statusChip(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.15)))
    }

    // MARK: - Actions

    private func loadCurrentValues() {
        let existing = viewModel.textToSpeech.elevenLabsConfig
        apiKey = existing?.apiKey ?? ""
        voiceId = (existing?.voiceId == ElevenLabsConfig.defaultVoiceId) ? "" : (existing?.voiceId ?? "")
    }

    private func save() {
        viewModel.saveElevenLabsSettings(
            apiKey: apiKey,
            voiceId: voiceId.trimmingCharacters(in: .whitespaces).isEmpty ? nil : voiceId
        )
        saveStatus = .saved
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if saveStatus == .saved { saveStatus = .idle }
        }
    }

    private func clear() {
        viewModel.clearElevenLabsSettings()
        apiKey = ""
        voiceId = ""
        saveStatus = .cleared
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if saveStatus == .cleared { saveStatus = .idle }
        }
    }
}
