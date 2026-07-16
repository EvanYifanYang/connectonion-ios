import SwiftUI

struct WelcomeView: View {
    var onAddAgent: () -> Void

    var body: some View {
        EmptyStateHero(onAddAgent: onAddAgent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
    }
}

struct ConnectOnionLogoMark: View {
    var body: some View {
        Image("logo")
            .resizable()
            .scaledToFit()
            .frame(width: 52, height: 52)
            .frame(width: 76, height: 76)
            .glassSurface(cornerRadius: 24)
    }
}

#Preview("Welcome") {
    WelcomeView(onAddAgent: {})
}
