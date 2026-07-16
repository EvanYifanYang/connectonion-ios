import SwiftUI

/// A small "peeling onion" loading mark for the thinking row, built from the logo: concentric tilted
/// onion-layer rings (purple, lighter toward the centre) with white separators. A wave of scale +
/// opacity travels from the outer layer inward so the layers look like they're peeling one by one.
struct OnionThinkingMark: View {
    var active: Bool = true

    private let layerCount = 4
    private let size = CGSize(width: 26, height: 20)
    private let tilt = Angle.degrees(-25)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !active)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                // Outer layer first (back) → inner layer last (front).
                ForEach(0..<layerCount, id: \.self) { index in
                    layer(index, time)
                }
            }
            .rotationEffect(tilt)
            .frame(width: size.width, height: size.width)
        }
    }

    private func layer(_ index: Int, _ time: Double) -> some View {
        // 1.0 for the outermost ring, shrinking toward the centre.
        let fraction = CGFloat(layerCount - index) / CGFloat(layerCount)
        // Peel wave travels outer → inner; when paused it rests calmly lit.
        let phase = active ? time * 2.6 - Double(index) * 0.7 : 0
        let pulse = active ? (sin(phase) + 1) / 2 : 0.6
        let scale = 0.92 + 0.12 * pulse
        let isInnermost = index == layerCount - 1

        return Ellipse()
            .fill(Color.onion.opacity(0.2 + 0.6 * Double(fraction)))
            .overlay {
                if !isInnermost {
                    Ellipse().stroke(.white, lineWidth: 1.1)
                }
            }
            .frame(width: size.width * fraction, height: size.height * fraction)
            .scaleEffect(scale)
            .opacity(0.55 + 0.45 * pulse)
    }
}

#Preview("Onion Thinking Mark") {
    HStack(spacing: 24) {
        OnionThinkingMark(active: true)
        OnionThinkingMark(active: false)
    }
    .padding()
}
