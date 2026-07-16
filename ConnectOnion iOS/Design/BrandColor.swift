import SwiftUI

/// The ConnectOnion brand palette. The app is monochrome + a single onion-violet accent;
/// purple should appear only on primary actions, the onion mark/avatar, and selection/active states.
extension Color {
    /// The onion-violet accent (single source of truth = the `AccentColor` asset, light/dark aware).
    static let onion = Color.accentColor

    /// A soft ~12% onion tint for selection backgrounds and quiet fills.
    static let onionSoft = Color.accentColor.opacity(0.12)
}

/// Concentric onion-ring gradient stops (light rim → deep center), for the `OnionRingMark` (Phase 5).
enum BrandGradient {
    static let ring = Gradient(stops: [
        .init(color: .onion.opacity(0.18), location: 0.0),
        .init(color: .onion.opacity(0.45), location: 0.55),
        .init(color: .onion.opacity(0.85), location: 1.0),
    ])
}
