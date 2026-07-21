//
//  IntentRow.swift
//
//  Purpose: Implements IntentRow for the Features/Chat/Timeline module.
//  Collaborates with: AgentActivityGroup, AgentBubble, CompactRow, EvaluationRow, FilesReceivedRow, MarkdownMessageView.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
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
