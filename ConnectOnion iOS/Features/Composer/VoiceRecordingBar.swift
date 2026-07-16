import SwiftUI

/// The in-composer dictation UI: a cancel (✕), an animated waveform with the elapsed time, and a
/// confirm (✓) that commits the transcript. Shown in place of the text field while recording.
struct VoiceRecordingBar: View {
    var state: VoiceInputTranscriber.RecordingState
    var duration: TimeInterval
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
                    .background(Color(.tertiarySystemFill), in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel dictation")

            HStack(spacing: 10) {
                RecordingWaveform(active: state == .recording)
                    .frame(maxWidth: .infinity)
                Text(formattedDuration)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Button(action: onConfirm) {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
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

    private var formattedDuration: String {
        let total = max(0, Int(duration.rounded(.down)))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }
}

/// A faux audio waveform — a row of bars whose heights ride a travelling sine wave while recording,
/// and rest flat when paused. (The transcriber doesn't expose live audio levels, so this is cosmetic.)
private struct RecordingWaveform: View {
    var active: Bool

    private let barCount = 22

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05, paused: !active)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(Color.onion.opacity(active ? 0.75 : 0.3))
                        .frame(width: 3, height: height(index, t))
                }
            }
            .frame(height: 26, alignment: .center)
        }
    }

    private func height(_ index: Int, _ time: Double) -> CGFloat {
        guard active else { return 4 }
        let phase = Double(index) * 0.55
        let wave = (sin(time * 6 + phase) + 1) / 2 // 0...1
        return 5 + wave * 20
    }
}
