import SwiftUI

/// The top-bar brand wordmark: "Connect" + the onion logo standing in for the capital O + "nion".
struct ConnectOnionWordmark: View {
    var logoSize: CGFloat = 27

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
        // A touch larger than the other nav titles so the brand reads at the top of the agent list.
        .font(.system(.title2, design: .serif).weight(.semibold))
        .lineLimit(1)
        .accessibilityLabel("ConnectOnion")
    }
}

#Preview("Wordmark") {
    ConnectOnionWordmark()
        .padding()
}
