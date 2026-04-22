//
//  PanelView.swift
//  SwiftUI content for the menu-bar panel. Minimal surface for v0.1 —
//  install-CLI banner, a prompt input, a "Test Claude" button, and a
//  streaming response area.
//

import SwiftUI

struct PanelView: View {
    @ObservedObject var viewModel: ClickyViewModel
    let onDismiss: () -> Void

    @State private var prompt: String = "what's on my screen right now?"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 16)

            Group {
                if !viewModel.isClaudeCLIAvailable {
                    installBanner
                } else if !viewModel.hasScreenRecordingPermission {
                    screenRecordingBanner
                } else {
                    readyBody
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            Spacer(minLength: 0)
            footer
        }
        .frame(width: 360, height: 420)
        .background(Color(red: 0.09, green: 0.09, blue: 0.09))
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isClaudeCLIAvailable ? Color.green : Color.yellow)
                    .frame(width: 8, height: 8)
                Text("Clicky")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var installBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                Text("Install Claude Code")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
            Text("Clicky uses your Claude Code login to chat — no extra keys needed. Install the CLI, sign in once, then come back here.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                viewModel.openClaudeCodeInstallPage()
            } label: {
                Text("Open install page")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.blue))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.yellow.opacity(0.4), lineWidth: 1))
        )
    }

    private var screenRecordingBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "camera.metering.unknown")
                    .foregroundColor(.orange)
                Text("Grant Screen Recording")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
            Text("Clicky needs Screen Recording to capture your display before asking Claude. After granting, quit and relaunch Clicky so macOS picks up the change.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button {
                    viewModel.requestScreenRecordingPermission()
                } label: {
                    Text("Ask macOS")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.blue))
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.openScreenRecordingSettings()
                } label: {
                    Text("Open settings")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.4), lineWidth: 1))
        )
    }

    private var readyBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ready. Ask clicky about anything on your screen.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.75))

            TextField("", text: $prompt, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
                .lineLimit(2...4)

            HStack(spacing: 8) {
                Button {
                    viewModel.runTestTurn(userPrompt: prompt)
                } label: {
                    Text(viewModel.isRunningTurn ? "Running…" : "Test Claude")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.blue))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isRunningTurn || prompt.trimmingCharacters(in: .whitespaces).isEmpty)

                if viewModel.isRunningTurn {
                    Button {
                        viewModel.cancelCurrentTurn()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button(action: viewModel.clearConversation) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.55))
                        .padding(6)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help("Clear conversation history")
            }

            if !viewModel.streamingText.isEmpty {
                ScrollView {
                    Text(viewModel.streamingText)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 160)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
            }

            if let error = viewModel.lastError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if let version = viewModel.claudeVersion {
                Text("claude \(version)")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.35))
            } else {
                Text("claude CLI: probing…")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.35))
            }
            Spacer()
            if let sessionId = viewModel.lastSessionId {
                Text("session \(sessionId.prefix(8))")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.35))
            }
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.25))
    }
}
