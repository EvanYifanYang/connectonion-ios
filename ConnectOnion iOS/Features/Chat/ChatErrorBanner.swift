//
//  ChatErrorBanner.swift
//
//  Purpose: Implements ChatErrorBanner for the Features/Chat module.
//  Collaborates with: ChatFailure, ChatItemView, ChatMessageList, ChatScreen, ChatTimeline, ChatViewModel.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

/// Shows what went wrong, what to do about it, and — only when one exists — the action that helps.
/// Technical text (server messages, endpoint lists) hides behind a disclosure so the headline stays
/// readable above the composer.
struct ChatErrorBanner: View {
    var failure: ChatFailure
    var onRetry: () -> Void

    @State private var feedbackTrigger = 0
    @State private var showsDetail = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 4) {
                // Combined for VoiceOver, but only the text — the disclosure below stays reachable.
                VStack(alignment: .leading, spacing: 2) {
                    Text(failure.title)
                        .appFont(.footnote, weight: .semibold)
                    Text(failure.body)
                        .appFont(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)

                if let detail = failure.detail {
                    Button {
                        withAnimation(.smooth(duration: 0.2)) { showsDetail.toggle() }
                    } label: {
                        Label(
                            showsDetail ? "Hide details" : "Show details",
                            systemImage: showsDetail ? "chevron.down" : "chevron.right"
                        )
                        .appFont(.caption2)
                        .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)

                    if showsDetail {
                        Text(detail)
                            .appFont(.caption2)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            if let actionTitle {
                Button(actionTitle, systemImage: "arrow.clockwise") {
                    feedbackTrigger += 1
                    onRetry()
                }
                .buttonStyle(.glass)
                .accessibilityIdentifier(AccessibilityID.reconnectButton)
            }
        }
        .padding(10)
        .glassSurface(cornerRadius: 16, tint: .red.opacity(0.08), isInteractive: false)
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
    }

    /// No button at all when nothing the app can do would help — the user has to change something.
    private var actionTitle: String? {
        switch failure.action {
        case .resend, .reconnect: "Retry"
        case .dismiss: nil
        }
    }
}

#Preview("Retryable") {
    ChatErrorBanner(
        failure: ChatFailure(
            title: "Could not connect to this agent",
            body: "Check that it's running and reachable from this iPhone. Tap Retry to send it again.",
            action: .resend
        ),
        onRetry: {}
    )
    .padding()
}

#Preview("Terminal, with detail") {
    ChatErrorBanner(
        failure: ChatFailure(
            title: "The agent refused the connection",
            body: "It rejected this device. Check the agent's trust settings, then try again.",
            action: .dismiss,
            detail: "Invalid signature"
        ),
        onRetry: {}
    )
    .padding()
}
