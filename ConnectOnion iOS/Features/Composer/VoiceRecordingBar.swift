//
//  VoiceRecordingBar.swift
//
//  Purpose: Implements VoiceRecordingBar for the Features/Composer module.
//  Collaborates with: AttachmentSheet, AttachmentStrip, CameraPicker, ChatInputBar, ComposerAttachmentPreviews, RecentPhotos.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

/// The in-composer dictation control row: a cancel (✕), a live mic-level waveform, and a confirm (✓).
/// Sits below the text field (which keeps showing the streaming transcript) while recording.
struct VoiceRecordingBar: View {
    // Held (not just `levels`) so only this small view re-renders at the ~20 Hz level cadence, rather
    // than the whole composer body.
    var voice: VoiceInputTranscriber
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .appFont(.body, weight: .semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
                    .background(Color(.tertiarySystemFill), in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel dictation")

            RecordingWaveform(levels: voice.levels)
                .frame(maxWidth: .infinity)

            Button(action: onConfirm) {
                Image(systemName: "checkmark")
                    .appFont(.body, weight: .semibold)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.onion, in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Use dictation")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }
}

/// A live waveform driven by real mic levels. Fills the available width; the newest samples sit on the
/// right and scroll left, with quiet stretches rendered as small dots — like the system dictation bar.
private struct RecordingWaveform: View {
    var levels: [CGFloat]

    private let barWidth: CGFloat = 3
    private let spacing: CGFloat = 3
    private let maxHeight: CGFloat = 28
    private let minHeight: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            let unit = barWidth + spacing
            let count = max(1, Int(geometry.size.width / unit))
            HStack(spacing: spacing) {
                ForEach(0..<count, id: \.self) { index in
                    Capsule()
                        .fill(Color.primary.opacity(0.8))
                        .frame(width: barWidth, height: height(at: index, total: count))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .trailing)
        }
        .frame(height: maxHeight)
        .animation(.linear(duration: 0.06), value: levels)
    }

    private func height(at index: Int, total: Int) -> CGFloat {
        let leadingPad = total - levels.count
        let levelIndex = index - leadingPad
        guard levelIndex >= 0, levelIndex < levels.count else { return minHeight }
        return minHeight + levels[levelIndex] * (maxHeight - minHeight)
    }
}
