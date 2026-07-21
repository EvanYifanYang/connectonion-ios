//
//  VoiceInputStatusPill.swift
//
//  Purpose: Implements VoiceInputStatusPill for the Features/Composer module.
//  Collaborates with: AttachmentSheet, AttachmentStrip, CameraPicker, ChatInputBar, ComposerAttachmentPreviews, RecentPhotos.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

struct VoiceInputStatusPill: View {
    var state: VoiceInputTranscriber.RecordingState
    var duration: TimeInterval
    var transcript: String

    var body: some View {
        HStack(spacing: 10) {
            voiceGlyph

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .appFont(.caption, weight: .semibold)
                if transcript.isEmpty {
                    Text(subtitle)
                        .appFont(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(transcript)
                        .appFont(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .glassSurface(cornerRadius: 18, tint: state == .recording ? .red.opacity(0.08) : nil)
        .accessibilityIdentifier(AccessibilityID.chatVoiceStatus)
    }

    @ViewBuilder
    private var voiceGlyph: some View {
        switch state {
        case .recording:
            ZStack {
                Circle()
                    .fill(.red.opacity(0.18))
                    .frame(width: 24, height: 24)
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
            }
        case .requestingPermission, .transcribing:
            ProgressView()
                .controlSize(.small)
                .frame(width: 24, height: 24)
        case .idle:
            Image(systemName: "mic.fill")
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
        }
    }

    private var title: String {
        switch state {
        case .requestingPermission:
            "Preparing voice input"
        case .recording:
            "Listening \(formatVoiceDuration(duration))"
        case .transcribing:
            "Finishing transcript"
        case .idle:
            "Voice input"
        }
    }

    private var subtitle: String {
        switch state {
        case .requestingPermission:
            "Speech and microphone access may be requested."
        case .recording:
            "Speak naturally. Tap stop when you are done."
        case .transcribing:
            "Adding your words to the message."
        case .idle:
            ""
        }
    }
}

private func formatVoiceDuration(_ duration: TimeInterval) -> String {
    let totalSeconds = max(0, Int(duration.rounded(.down)))
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return "\(minutes):\(String(format: "%02d", seconds))"
}
