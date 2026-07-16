import SwiftUI

/// The onion mark from the logo: concentric tilted layers, darkest onion-purple on the outside and
/// lightening to a near-white centre, separated by thin white lines. When active it gently breathes
/// while a soft highlight peels inward through the rings.
struct OnionThinkingMark: View {
    var active: Bool = true
    var diameter: CGFloat = 26

    private let layerCount = 5
    private let tilt = Angle.degrees(-24)

    private var size: CGSize { CGSize(width: diameter, height: diameter * 0.8) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !active)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                // Outer layer first (back) → inner layer last (front), so the light centre reads on top.
                ForEach(0..<layerCount, id: \.self) { index in
                    layer(index, time)
                }
            }
            .rotationEffect(tilt)
            .frame(width: diameter, height: diameter)
            .scaleEffect(breathScale(time))
        }
    }

    private func layer(_ index: Int, _ time: Double) -> some View {
        // 1.0 for the outermost ring, shrinking toward the centre.
        let fraction = CGFloat(layerCount - index) / CGFloat(layerCount)
        // Opaque fill that lightens from onion-purple (outer) toward near-white (centre).
        let fill = Color.onion.mix(with: .white, by: (1 - Double(fraction)) * 0.85)

        return Ellipse()
            .fill(fill)
            .overlay(
                Ellipse()
                    .stroke(.white, lineWidth: 1.2)
                    .opacity(strokeOpacity(index, time))
            )
            .frame(width: size.width * fraction, height: size.height * fraction)
    }

    /// A calm whole-mark breath while active.
    private func breathScale(_ time: Double) -> CGFloat {
        guard active else { return 1 }
        return 1 + 0.045 * CGFloat((sin(time * 1.7) + 1) / 2)
    }

    /// A soft highlight that travels inward through the rings — the "peel".
    private func strokeOpacity(_ index: Int, _ time: Double) -> Double {
        guard active else { return 0.9 }
        let phase = time * 2.1 - Double(index) * 0.6
        return 0.45 + 0.55 * ((sin(phase) + 1) / 2)
    }
}

#Preview("Onion Mark") {
    HStack(spacing: 28) {
        OnionThinkingMark(active: true, diameter: 26)
        OnionThinkingMark(active: false, diameter: 40)
        OnionThinkingMark(active: false, diameter: 64)
    }
    .padding()
}
