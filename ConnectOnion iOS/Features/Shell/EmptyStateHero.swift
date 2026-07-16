import SwiftUI

/// The empty-state hero shown when no agents exist: the onion logo, the brand name in serif, a
/// smaller serif subtitle, and the primary Add-Agent action — with a gentle breathing entrance so
/// opening the app feels alive (restrained: a soft fade/scale-in plus a slow logo "breath").
struct EmptyStateHero: View {
    var onAddAgent: () -> Void

    @State private var appeared = false
    @State private var breathe = false
    @State private var tapTrigger = 0

    var body: some View {
        VStack(spacing: 20) {
            ConnectOnionLogoMark()
                .scaleEffect(breathe ? 1.03 : 1.0)

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
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.96)
        .blur(radius: appeared ? 0 : 6)
        .sensoryFeedback(.selection, trigger: tapTrigger)
        .onAppear {
            withAnimation(.smooth(duration: 0.7)) { appeared = true }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true).delay(0.4)) {
                breathe = true
            }
        }
    }
}

#Preview("Empty State Hero") {
    EmptyStateHero(onAddAgent: {})
}
