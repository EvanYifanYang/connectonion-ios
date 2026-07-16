import ActivityKit
import Foundation

@MainActor
final class AgentReplyLiveActivityController {
    private var activityIDs: [UUID: String] = [:]
    private var latestStates: [UUID: AgentReplyActivityAttributes.ContentState] = [:]
    private var currentConversationID: UUID?

    init() {}

    func start(conversationID: UUID, agentAddress: String, agentName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        restoreTrackedActivity(for: conversationID)
        endOtherActiveActivities(except: conversationID)
        currentConversationID = conversationID

        let state = AgentReplyActivityAttributes.ContentState.connecting(agentName: agentName)
        latestStates[conversationID] = state

        if let activityID = activityIDs[conversationID] {
            Task {
                await Self.updateActivity(id: activityID, state: state)
            }
            return
        }

        Task {
            do {
                let activity = try Activity<AgentReplyActivityAttributes>.request(
                    attributes: AgentReplyActivityAttributes(
                        conversationID: conversationID.uuidString,
                        agentAddress: agentAddress,
                        agentName: agentName
                    ),
                    content: ActivityContent(state: state, staleDate: nil),
                    pushType: nil
                )
                let activityID = activity.id
                guard let latestState = latestStates[conversationID] else {
                    await Self.endActivity(id: activityID, state: state, dismissalPolicy: .immediate)
                    return
                }

                activityIDs[conversationID] = activityID
                if latestState != state {
                    await Self.updateActivity(id: activityID, state: latestState)
                }
            } catch {
                activityIDs[conversationID] = nil
            }
        }
    }

    func complete(
        conversationID: UUID,
        headline: String,
        detail: String
    ) {
        let startedAt = latestStates[conversationID]?.startedAt ?? .now
        let state = AgentReplyActivityAttributes.ContentState(
            phase: .completed,
            headline: headline,
            detail: detail,
            toolName: nil,
            startedAt: startedAt,
            updatedAt: .now
        )
        guard let activityID = activityIDs[conversationID] else { return }
        latestStates[conversationID] = nil
        activityIDs[conversationID] = nil
        if currentConversationID == conversationID {
            currentConversationID = nil
        }
        Task {
            await Self.endActivity(id: activityID, state: state, dismissalPolicy: .immediate)
        }
    }

    func update(
        conversationID: UUID,
        phase: AgentReplyActivityPhase,
        headline: String,
        detail: String,
        toolName: String? = nil
    ) {
        let startedAt = latestStates[conversationID]?.startedAt ?? .now
        let state = AgentReplyActivityAttributes.ContentState(
            phase: phase,
            headline: headline,
            detail: detail,
            toolName: toolName,
            startedAt: startedAt,
            updatedAt: .now
        )
        latestStates[conversationID] = state

        guard let activityID = activityIDs[conversationID] else { return }
        Task {
            await Self.updateActivity(id: activityID, state: state)
        }
    }

    func end(
        conversationID: UUID,
        phase: AgentReplyActivityPhase,
        headline: String,
        detail: String
    ) {
        let startedAt = latestStates[conversationID]?.startedAt ?? .now
        let state = AgentReplyActivityAttributes.ContentState(
            phase: phase,
            headline: headline,
            detail: detail,
            toolName: nil,
            startedAt: startedAt,
            updatedAt: .now
        )
        latestStates[conversationID] = nil
        let activityID = activityIDs[conversationID]
        activityIDs[conversationID] = nil

        guard let activityID else { return }
        Task {
            await Self.endActivity(id: activityID, state: state, dismissalPolicy: .after(.now + 8))
        }
    }

    private func cancelCompletionEnd(for conversationID: UUID) {
        _ = conversationID
    }

    private func restoreTrackedActivity(for conversationID: UUID) {
        guard activityIDs[conversationID] == nil else { return }
        let conversationKey = conversationID.uuidString
        guard let existingActivity = Activity<AgentReplyActivityAttributes>.activities.first(where: { activity in
            activity.attributes.conversationID == conversationKey
        }) else {
            return
        }

        activityIDs[conversationID] = existingActivity.id
    }

    private func endOtherActiveActivities(except conversationID: UUID) {
        let preservedActivityID = activityIDs[conversationID]
        let preservedConversationKey = conversationID.uuidString

        for activity in Activity<AgentReplyActivityAttributes>.activities {
            if activity.id == preservedActivityID || activity.attributes.conversationID == preservedConversationKey {
                continue
            }

            guard let otherConversationID = UUID(uuidString: activity.attributes.conversationID) else {
                Task {
                    await Self.endActivity(id: activity.id, state: fallbackEndedState(for: activity), dismissalPolicy: .immediate)
                }
                continue
            }

            latestStates[otherConversationID] = nil
            activityIDs[otherConversationID] = nil

            let state = fallbackEndedState(for: activity)
            Task {
                await Self.endActivity(id: activity.id, state: state, dismissalPolicy: .immediate)
            }
        }
    }

    private func fallbackEndedState(
        for activity: Activity<AgentReplyActivityAttributes>
    ) -> AgentReplyActivityAttributes.ContentState {
        AgentReplyActivityAttributes.ContentState(
            phase: .stopped,
            headline: activity.content.state.headline,
            detail: activity.content.state.detail,
            toolName: activity.content.state.toolName,
            startedAt: activity.content.state.startedAt,
            updatedAt: .now
        )
    }

    nonisolated private static func updateActivity(
        id: String,
        state: AgentReplyActivityAttributes.ContentState,
        staleDate: Date? = nil
    ) async {
        guard let activity = Activity<AgentReplyActivityAttributes>.activities.first(where: { $0.id == id }) else { return }
        await activity.update(ActivityContent(state: state, staleDate: staleDate))
    }

    nonisolated private static func endActivity(
        id: String,
        state: AgentReplyActivityAttributes.ContentState,
        dismissalPolicy: ActivityUIDismissalPolicy
    ) async {
        guard let activity = Activity<AgentReplyActivityAttributes>.activities.first(where: { $0.id == id }) else { return }
        await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: dismissalPolicy)
    }
}
