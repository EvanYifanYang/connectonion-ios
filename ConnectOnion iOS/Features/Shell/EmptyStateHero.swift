import SwiftUI

/// The empty-state hero shown when no agents exist: the onion logo, the brand name in serif, a
/// smaller serif subtitle, and the primary Add-Agent action — with a gentle breathing entrance so
/// opening the app feels alive (restrained: a soft fade/scale-in plus a slow onion "breath" that
/// reads even on a light background). Honors Reduce Motion by staying still.
struct EmptyStateHero: View {
    var onAddAgent: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var breathe = false
    @State private var tapTrigger = 0

    var body: some View {
        VStack(spacing: 22) {
            BreathingLogoMark(breathe: breathe)

            VStack(spacing: 6) {
                Text("ConnectOnion")
                    .font(AppFont.hero)
                Text("Add your first agent")
                    .font(AppFont.heroSubtitle)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            Button("Add Agent", systemImage: "plus") {
                tapTrigger += 1
                onAddAgent()
            }
            .buttonStyle(.glassProminent)
            .accessibilityIdentifier(AccessibilityID.addAgentButton)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.96)
        .blur(radius: appeared ? 0 : 6)
        .sensoryFeedback(.selection, trigger: tapTrigger)
        .onAppear { startBreathing() }
        .onChange(of: reduceMotion) { _, nowReduced in
            // Honor a *mid-session* Reduce Motion toggle, not just the first appearance: settle the
            // pulse the moment it's enabled, and resume it if the user turns it back off while here.
            if nowReduced {
                withAnimation(.smooth(duration: 0.3)) { breathe = false }
            } else {
                startBreathing()
            }
        }
    }

    private func startBreathing() {
        if !appeared {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.7)) { appeared = true }
        }
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true).delay(0.4)) {
            breathe = true
        }
    }
}

/// The onion logo mark that "breathes": a soft violet halo behind a glass tile, both of which expand
/// and brighten on the inhale. The halo (not just the tile's scale) is what makes the pulse visible
/// against any background.
private struct BreathingLogoMark: View {
    var breathe: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(Color.onion)
                .frame(width: 128, height: 128)
                .blur(radius: 36)
                .opacity(breathe ? 0.40 : 0.16)
                .scaleEffect(breathe ? 1.12 : 0.9)

            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .frame(width: 92, height: 92)
                .glassSurface(cornerRadius: 26)
                .scaleEffect(breathe ? 1.04 : 1.0)
                // Keep the shadow radius fixed (animate only its opacity) so the breath doesn't force
                // a per-frame shadow re-rasterization; the halo + scale carry the depth cue.
                .shadow(color: .onion.opacity(breathe ? 0.30 : 0.12), radius: 16, y: 6)
        }
        .frame(height: 128)
        .accessibilityHidden(true)
    }
}

#Preview("Empty State Hero") {
    EmptyStateHero(onAddAgent: {})
        .background(Color.appCanvas)
}
