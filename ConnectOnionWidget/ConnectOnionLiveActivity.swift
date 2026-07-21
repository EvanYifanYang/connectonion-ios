//
//  ConnectOnionLiveActivity.swift
//
//  Purpose: Implements ConnectOnionLiveActivity for the ConnectOnionWidget module.
//  Collaborates with: ConnectOnionWidget, ConnectOnionWidgetBundle.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

struct ConnectOnionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AgentReplyActivityAttributes.self) { context in
            LiveActivityLockScreenView(context: context)
                .activityBackgroundTint(.connectOnionActivityBackground)
                .activitySystemActionForegroundColor(.primary)
                .widgetURL(ConnectOnionDeepLink.conversation(id: context.attributes.conversationID))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.phaseLabel, systemImage: context.state.phase.systemImageName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .padding(.leading, 4)
                        .padding(.top, 6)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.showsTimer {
                        Text(context.state.startedAt, style: .timer)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 6)
                            .padding(.top, 6)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.headline)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(context.state.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                    .padding(.bottom, 10)
                }
            } compactLeading: {
                Image(systemName: context.state.phase.systemImageName)
                    .foregroundStyle(context.state.tint)
            } compactTrailing: {
                Text(context.state.compactText)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            } minimal: {
                Image(systemName: context.state.phase.systemImageName)
                    .foregroundStyle(context.state.tint)
            }
            .widgetURL(ConnectOnionDeepLink.conversation(id: context.attributes.conversationID))
            .keylineTint(context.state.tint)
        }
    }
}

private extension Color {
    static let connectOnionActivityBackground = Color(uiColor: UIColor { traits in
        let base = UIColor.label.resolvedColor(with: traits)
        return base.withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.12 : 0.08)
    })
}

private struct LiveActivityLockScreenView: View {
    var context: ActivityViewContext<AgentReplyActivityAttributes>

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: context.state.phase.systemImageName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(context.state.tint)
                .frame(width: 34, height: 34)
                .background(context.state.tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(context.attributes.agentName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(context.state.headline)
                    .font(.headline)
                    .lineLimit(1)

                Text(context.state.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if context.state.showsTimer {
                Text(context.state.startedAt, style: .timer)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

private extension AgentReplyActivityAttributes.ContentState {
    var showsTimer: Bool {
        switch phase {
        case .connecting, .running, .tool, .waiting:
            true
        case .completed, .failed, .stopped:
            false
        }
    }

    var phaseLabel: String {
        switch phase {
        case .connecting:
            "Connecting"
        case .running:
            "Working"
        case .tool:
            toolName ?? "Tool"
        case .waiting:
            "Waiting"
        case .completed:
            "Ready"
        case .failed:
            "Failed"
        case .stopped:
            "Stopped"
        }
    }

    var compactText: String {
        switch phase {
        case .connecting:
            "..."
        case .running:
            "Run"
        case .tool:
            toolName?.prefix(3).uppercased() ?? "Tool"
        case .waiting:
            "Ask"
        case .completed:
            "Done"
        case .failed:
            "Err"
        case .stopped:
            "Stop"
        }
    }

    var tint: Color {
        switch phase {
        case .connecting, .running:
            .green
        case .tool:
            .blue
        case .waiting:
            .orange
        case .completed:
            .green
        case .failed:
            .red
        case .stopped:
            .secondary
        }
    }
}

#Preview("Live Activity", as: .content, using: AgentReplyActivityAttributes(conversationID: "preview", agentAddress: "0xagent", agentName: "OpenOnion")) {
    ConnectOnionLiveActivity()
} contentStates: {
    AgentReplyActivityAttributes.ContentState(
        phase: .tool,
        headline: "Using read_file",
        detail: "ConnectOnion iOS/Features/Chat/ChatViewModel.swift",
        toolName: "read_file",
        startedAt: .now,
        updatedAt: .now
    )
}
