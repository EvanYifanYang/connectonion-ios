import SwiftUI

/// The shared "card" look for sidebar rows: a surface-colored rounded card that sits on the grouped
/// background, lifted by a soft shadow and defined by a hairline edge. A selected row swaps the
/// neutral edge for an onion-violet border and a gentle onion lift — an *active* accent that reads
/// clearly without the heavy filled highlight it replaces.
private struct SidebarCardModifier: ViewModifier {
    var isSelected: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.horizontalSizeClass) private var sizeClass

    private let radius: Double = 20

    /// Persistent selection only makes sense in a split view (iPad / regular width), where the
    /// selected row mirrors the detail pane. In compact width the sidebar is push-navigation — tapping
    /// a row *enters* it — so a highlight left behind on return would read as a stuck state. There we
    /// rely on the momentary press feedback instead and never paint a resting selection.
    private var showSelected: Bool {
        isSelected && sizeClass == .regular
    }

    func body(content: Content) -> some View {
        content
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(borderColor, lineWidth: showSelected ? 1.5 : 1)
            }
            .shadow(color: shadowColor, radius: showSelected ? 12 : 7, x: 0, y: showSelected ? 4 : 3)
    }

    private var borderColor: Color {
        if showSelected { return .onion.opacity(0.55) }
        return .primary.opacity(scheme == .dark ? 0.12 : 0.05)
    }

    private var shadowColor: Color {
        // Shadows don't read on a near-black grouped background, so selection leans on an onion glow
        // in dark mode and a soft neutral drop in light mode.
        if showSelected { return .onion.opacity(scheme == .dark ? 0.30 : 0.20) }
        return .black.opacity(scheme == .dark ? 0 : 0.06)
    }
}

extension View {
    /// Wrap a sidebar row's content in the shared card surface (see `SidebarCardModifier`).
    func sidebarCard(isSelected: Bool = false) -> some View {
        modifier(SidebarCardModifier(isSelected: isSelected))
    }
}

#Preview("Sidebar Card") {
    VStack(spacing: 16) {
        Text("Unselected row")
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(14)
            .sidebarCard()

        Text("Selected row")
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(14)
            .sidebarCard(isSelected: true)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
