//
//  ChatErrorBanner.swift
//
//  Purpose: Implements ChatErrorBanner for the Features/Chat module.
//  Collaborates with: ChatHeaderView, ChatItemView, ChatMessageList, ChatScreen, ChatTimeline, ChatViewModel.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

struct ChatErrorBanner: View {
    var message: String
    var onReconnect: () -> Void

    @State private var feedbackTrigger = 0

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.red)

            Text(message)
                .appFont(.footnote)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            // "Retry", not "Reconnect": when the prompt never reached the host this re-sends it.
            Button("Retry", systemImage: "arrow.clockwise") {
                feedbackTrigger += 1
                onReconnect()
            }
                .buttonStyle(.glass)
                .accessibilityIdentifier(AccessibilityID.reconnectButton)
        }
        .padding(10)
        .glassSurface(cornerRadius: 16, tint: .red.opacity(0.08), isInteractive: false)
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
    }
}

#Preview("Chat Error Banner") {
    ChatErrorBanner(message: "The WebSocket disconnected while the agent was streaming.", onReconnect: {})
        .padding()
}
