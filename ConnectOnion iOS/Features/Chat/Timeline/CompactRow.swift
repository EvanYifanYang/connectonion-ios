//
//  CompactRow.swift
//
//  Purpose: Implements CompactRow for the Features/Chat/Timeline module.
//  Collaborates with: AgentActivityGroup, AgentBubble, EvaluationRow, FilesReceivedRow, IntentRow, MarkdownMessageView.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

struct CompactRow: View {
    var item: ChatItem

    var body: some View {
        StatusPill(
            systemImage: item.status == .error ? "exclamationmark.triangle" : "archivebox",
            text: item.content.nilIfEmpty ?? "Compacting context",
            tint: item.status == .error ? .red : .secondary
        )
    }
}

#Preview("Compact Row") {
    CompactRow(item: PreviewFixtures.sampleCompact)
        .padding()
}
