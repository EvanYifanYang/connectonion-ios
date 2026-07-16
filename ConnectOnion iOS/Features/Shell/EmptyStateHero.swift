import SwiftUI

/// The no-agent state doubles as the new-user welcome: the onion grows itself from the core outward
/// (8→1) to the finished logo, then the glass tile, its violet halo, the wordmark, the subtitle and
/// the Add-Agent button float up around it — settling into the resting hero (which then breathes).
/// Honors Reduce Motion by presenting everything at rest.
struct EmptyStateHero: View {
    var onAddAgent: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var built = false    // onion assembled (core → peel)
    @State private var chrome = false   // tile + halo + text + button floated in
    @State private var breathe = false
    @State private var tapTrigger = 0

    var body: some View {
        VStack(spacing: 22) {
            WelcomeOnionMark(built: built, chrome: chrome, breathe: breathe)

            VStack(spacing: 6) {
                Text("ConnectOnion")
                    .font(AppFont.hero)
                Text("Add your first agent")
                    .font(AppFont.heroSubtitle)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .offset(y: chrome ? 0 : 16)
            .opacity(chrome ? 1 : 0)

            Button("Add Agent", systemImage: "plus") {
                tapTrigger += 1
                onAddAgent()
            }
            .buttonStyle(.glassProminent)
            .accessibilityIdentifier(AccessibilityID.addAgentButton)
            .padding(.top, 6)
            .offset(y: chrome ? 0 : 16)
            .opacity(chrome ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .sensoryFeedback(.selection, trigger: tapTrigger)
        .onAppear { runEntrance() }
        .onChange(of: reduceMotion) { _, nowReduced in
            if nowReduced { withAnimation(.smooth(duration: 0.3)) { breathe = false } }
            else { startBreathing() }
        }
    }

    private func runEntrance() {
        guard !reduceMotion else { built = true; chrome = true; return }
        // Onion grows core→peel (per-layer spring below), then the chrome floats up.
        built = true
        withAnimation(.smooth(duration: 0.55).delay(1.15)) { chrome = true }
        startBreathing()
    }

    private func startBreathing() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true).delay(2.0)) {
            breathe = true
        }
    }
}

/// The onion mark for the welcome: 8 real logo layers assembling core→peel, wrapped by a glass tile
/// and a violet halo that only appear (and then breathe) once the onion is whole.
private struct WelcomeOnionMark: View {
    var built: Bool
    var chrome: Bool
    var breathe: Bool

    // OUTER → INNER; built from the core outward, so the delay is largest for the black peel.
    private let layers = [
        "onion_1_black", "onion_2_purple", "onion_3_white", "onion_4_purple",
        "onion_5_white", "onion_6_purple", "onion_7_white", "onion_8_core"
    ]

    var body: some View {
        ZStack {
            // Violet halo — appears with the chrome, breathes.
            RoundedRectangle(cornerRadius: 52, style: .continuous)
                .fill(Color.onion)
                .frame(width: 164, height: 164)
                .blur(radius: 44)
                .opacity(chrome ? (breathe ? 0.40 : 0.16) : 0)
                .scaleEffect(chrome ? (breathe ? 1.12 : 0.9) : 0.6)

            // Glass tile — fades/scales in around the finished onion.
            Color.clear
                .frame(width: 120, height: 120)
                .glassSurface(cornerRadius: 32)
                .opacity(chrome ? 1 : 0)
                .scaleEffect(chrome ? 1 : 0.88)
                .shadow(color: .onion.opacity(chrome ? (breathe ? 0.30 : 0.12) : 0), radius: 18, y: 7)

            // The onion itself — grows core→peel.
            ZStack {
                ForEach(Array(layers.enumerated()), id: \.offset) { index, name in
                    Image(name)
                        .resizable()
                        .scaledToFit()
                        .opacity(built ? 1 : 0)
                        .scaleEffect(built ? 1 : 0.84)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.64)
                                .delay(Double(layers.count - 1 - index) * 0.085),
                            value: built
                        )
                }
            }
            .frame(width: 80, height: 80)
            .scaleEffect(breathe ? 1.04 : 1.0)
        }
        .frame(height: 164)
        .accessibilityHidden(true)
    }
}

#Preview("Welcome / Empty State") {
    EmptyStateHero(onAddAgent: {})
        .background(Color.appCanvas)
}
