import ActivityKit
import Foundation

@MainActor
final class AgentReplyLiveActivityController {
    static let shared = AgentReplyLiveActivityController()

    private var activityIDs: [UUID: String] = [:]
    private var latestStates: [UUID: AgentReplyActivityAttributes.ContentState] = [:]
    private var completionEndTasks: [UUID: Task<Void, Never>] = [:]

    private init() {}

    func start(conversationID: UUID, agentAddress: String, agentName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        cancelCompletionEnd(for: conversationID)

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
        detail: String,
        retention: TimeInterval = 5 * 60
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
        latestStates[conversationID] = state
        cancelCompletionEnd(for: conversationID)

        guard let activityID = activityIDs[conversationID] else { return }
        let staleDate = Date.now.addingTimeInterval(retention)

        Task {
            await Self.updateActivity(id: activityID, state: state, staleDate: staleDate)
        }

        let nanoseconds = UInt64(max(0, retention) * 1_000_000_000)
        completionEndTasks[conversationID] = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self?.finishCompletedActivity(conversationID: conversationID, state: state)
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
        cancelCompletionEnd(for: conversationID)
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
        completionEndTasks[conversationID]?.cancel()
        completionEndTasks[conversationID] = nil
    }

    private func finishCompletedActivity(
        conversationID: UUID,
        state: AgentReplyActivityAttributes.ContentState
    ) async {
        latestStates[conversationID] = nil
        let activityID = activityIDs[conversationID]
        activityIDs[conversationID] = nil
        completionEndTasks[conversationID] = nil

        guard let activityID else { return }
        await Self.endActivity(id: activityID, state: state, dismissalPolicy: .immediate)
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
