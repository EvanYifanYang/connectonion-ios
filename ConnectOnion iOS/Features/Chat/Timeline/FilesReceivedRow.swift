//
//  FilesReceivedRow.swift
//
//  Purpose: Implements FilesReceivedRow for the Features/Chat/Timeline module.
//  Collaborates with: AgentActivityGroup, AgentBubble, CompactRow, EvaluationRow, IntentRow, MarkdownMessageView.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

struct FilesReceivedRow: View {
    var item: ChatItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Files received", systemImage: "tray.and.arrow.down")
                .appFont(.footnote)
                .foregroundStyle(.secondary)

            ForEach(item.receivedFiles) { file in
                Text(file.name)
                    .appFont(.footnote)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .glassSurface(cornerRadius: 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 42)
        .padding(.vertical, 4)
    }
}

#Preview("Files Received") {
    FilesReceivedRow(item: PreviewFixtures.sampleFilesReceived)
        .padding()
}
