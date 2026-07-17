import SwiftUI

enum AppMotion {
    static let quick = Animation.smooth(duration: 0.18)
    static let standard = Animation.smooth(duration: 0.26)
    static let expressive = Animation.spring(duration: 0.36, bounce: 0.18)

    @MainActor
    static var panelTransition: AnyTransition {
        AnyTransition.asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.98, anchor: .top)),
            removal: .opacity
                .combined(with: .scale(scale: 0.98, anchor: .top))
        )
    }
}

#Preview("Motion Transitions") {
    @Previewable @State var visible = true

    VStack(spacing: 16) {
        Button("Toggle") {
            withAnimation(AppMotion.expressive) {
                visible.toggle()
            }
        }
        .buttonStyle(.glassProminent)

        if visible {
            Text("Animated surface")
                .padding()
                .glassSurface(cornerRadius: 18)
                .transition(AppMotion.panelTransition)
        }
    }
    .padding()
}
