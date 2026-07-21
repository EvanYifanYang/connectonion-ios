//
//  OnionRevealView.swift
//
//  Purpose: Implements OnionRevealView for the Features/Shell module.
//  Collaborates with: AgentAvatar, AgentListView, AgentSidebarRow, AppShellView, ConnectOnionWordmark, ConversationSidebarRow.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

/// The ConnectOnion onion logo assembling itself on appear: the five colour layers of the real
/// `Onion.png` — split pixel-exactly (black peel → outer flesh → white rings → inner flesh → core) —
/// spring in one after another from the outside toward the centre. Because every layer is a real
/// slice of the asset and together they reconstruct it byte-for-byte, the finished frame IS the app
/// icon (no cross-fade, no approximation).
struct OnionRevealView: View {
    /// Change this to replay the assemble animation (e.g. a fresh value per landing appearance).
    var trigger: AnyHashable = 0

    @State private var assembled = false

    // OUTER → INNER; each is a transparent 1024² slice of the logo (black peel → 3 flesh bands with
    // their white rings → pale core), aligned to the same canvas.
    private let layers = [
        "onion_1_black",
        "onion_2_purple",
        "onion_3_white",
        "onion_4_purple",
        "onion_5_white",
        "onion_6_purple",
        "onion_7_white",
        "onion_8_core"
    ]

    private let perLayerDelay = 0.09

    var body: some View {
        ZStack {
            ForEach(Array(layers.enumerated()), id: \.offset) { index, name in
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(assembled ? 1 : 0.82)
                    .opacity(assembled ? 1 : 0)
                    // Outer peel first, each inner ring a beat later — a springy build inward.
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.62).delay(Double(index) * perLayerDelay),
                        value: assembled
                    )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("ConnectOnion")
        .onAppear { assembled = true }
        .onChange(of: trigger) { _, _ in
            assembled = false
            DispatchQueue.main.async { assembled = true }
        }
    }
}

#Preview("Onion Reveal") {
    OnionRevealView()
        .frame(width: 160, height: 160)
        .padding()
}
