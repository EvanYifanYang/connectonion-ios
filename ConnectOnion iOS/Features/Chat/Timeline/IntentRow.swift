import SwiftUI

struct IntentRow: View {
    var item: ChatItem

    var body: some View {
        StatusPill(
            systemImage: item.status == .understood ? "checkmark.circle" : "scope",
            text: item.ack ?? (item.status == .understood ? "Understood" : "Understanding"),
            tint: .blue
        )
    }
}

#Preview("Intent Understood") {
    IntentRow(item: PreviewFixtures.sampleIntent)
        .padding()
}

#Preview("Intent Analyzing") {
    IntentRow(item: PreviewFixtures.sampleIntentAnalyzing)
        .padding()
}
