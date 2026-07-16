import SwiftUI

/// The top-bar brand wordmark: "Connect" + the onion logo standing in for the capital O + "nion".
struct ConnectOnionWordmark: View {
    var logoSize: CGFloat = 22

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("Connect")
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: logoSize, height: logoSize)
                .padding(.horizontal, 1)
            Text("nion")
        }
        .font(AppFont.wordmark)
        .lineLimit(1)
        .accessibilityLabel("ConnectOnion")
    }
}

#Preview("Wordmark") {
    ConnectOnionWordmark()
        .padding()
}
