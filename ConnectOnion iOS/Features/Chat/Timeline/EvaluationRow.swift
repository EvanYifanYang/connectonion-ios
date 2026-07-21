//
//  EvaluationRow.swift
//
//  Purpose: Implements EvaluationRow for the Features/Chat/Timeline module.
//  Collaborates with: AgentActivityGroup, AgentBubble, CompactRow, FilesReceivedRow, IntentRow, MarkdownMessageView.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

struct EvaluationRow: View {
    var item: ChatItem

    var body: some View {
        StatusPill(
            systemImage: item.status == .done ? (item.passed == true ? "checkmark.seal" : "xmark.seal") : "checklist",
            text: item.content.nilIfEmpty ?? item.expected ?? "Evaluating",
            tint: item.passed == false ? .red : .green
        )
    }
}

#Preview("Evaluation Passed") {
    EvaluationRow(item: PreviewFixtures.sampleEvaluation)
        .padding()
}

#Preview("Evaluation Failed") {
    EvaluationRow(item: PreviewFixtures.sampleEvaluationFailed)
        .padding()
}
