import SwiftUI

/// The "thinking" onion, built from the real logo layers. The black peel stays put (so the silhouette
/// reads at any size) while the inner rings accumulate outward→inward and then peel back off, looping
/// — a little onion breathing itself together while the agent works. Paused (and shown whole) when
/// inactive, so it settles and the app can reach idle (XCUITest-safe); also reused, static, as the
/// small mark under the model footer.
struct OnionThinkingMark: View {
    var active: Bool = true
    var diameter: CGFloat = 26

    // OUTER → INNER, matching OnionRevealView / the launch splash.
    private let layers = [
        "onion_1_black", "onion_2_purple", "onion_3_white", "onion_4_purple",
        "onion_5_white", "onion_6_purple", "onion_7_white", "onion_8_core"
    ]
    private let period: Double = 2.2 // one build + peel cycle

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !active)) { timeline in
            content(builtRings: builtRings(at: timeline.date))
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }

    /// How many inner rings (0…7) are currently built. Ping-pongs 0→7→0 while active; all 7 when paused.
    private func builtRings(at date: Date) -> Double {
        guard active else { return Double(layers.count - 1) }
        let t = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: period) / period // 0..1
        let p = t * 2
        return (p <= 1 ? p : 2 - p) * Double(layers.count - 1) // 0→7→0
    }

    private func content(builtRings: Double) -> some View {
        ZStack {
            Image(layers[0]) // black peel — always present
                .resizable()
                .scaledToFit()
            ForEach(1..<layers.count, id: \.self) { index in
                Image(layers[index])
                    .resizable()
                    .scaledToFit()
                    // Ring `index` fades in as the build count passes it (and back out on the peel).
                    .opacity(min(1, max(0, builtRings - Double(index - 1))))
            }
        }
    }
}

#Preview("Onion Thinking Mark") {
    HStack(spacing: 24) {
        OnionThinkingMark(active: true, diameter: 48)
        OnionThinkingMark(active: false, diameter: 40)
    }
    .padding()
}
