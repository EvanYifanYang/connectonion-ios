import ActivityKit
import Foundation

@MainActor
final class AgentReplyLiveActivityController {
    static let shared = AgentReplyLiveActivityController()

    private var activityIDs: [UUID: String] = [:]
    private var latestStates: [UUID: AgentReplyActivityAttributes.ContentState] = [:]

    private init() {}

    func start(conversationID: UUID, agentAddress: String, agentName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = AgentReplyActivityAttributes.ContentState.connecting(agentName: agentName)
        latestStates[conversationID] = state

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

    nonisolated private static func updateActivity(
        id: String,
        state: AgentReplyActivityAttributes.ContentState
    ) async {
        guard let activity = Activity<AgentReplyActivityAttributes>.activities.first(where: { $0.id == id }) else { return }
        await activity.update(ActivityContent(state: state, staleDate: nil))
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
