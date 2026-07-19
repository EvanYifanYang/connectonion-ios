import ActivityKit
import Foundation
import OSLog

@MainActor
final class AgentReplyLiveActivityController {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ConnectOnion",
        category: "LiveActivity"
    )
    private var activityIDs: [UUID: String] = [:]
    private var latestStates: [UUID: AgentReplyActivityAttributes.ContentState] = [:]
    private var completionEndTasks: [UUID: Task<Void, Never>] = [:]
    private var currentConversationID: UUID?

    init() {}

    func start(conversationID: UUID, agentAddress: String, agentName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.notice("Live Activities are disabled; skipping conversation \(conversationID.uuidString, privacy: .public)")
            return
        }
        cancelCompletionEnd(for: conversationID)
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

        do {
            // `request` is synchronous. Requesting inline ensures a fast reply can't complete before
            // the Activity ID is recorded, which previously left an orphaned "Connecting" activity.
            let activity = try Activity<AgentReplyActivityAttributes>.request(
                attributes: AgentReplyActivityAttributes(
                    conversationID: conversationID.uuidString,
                    agentAddress: agentAddress,
                    agentName: agentName
                ),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            activityIDs[conversationID] = activity.id
            logger.info("Started Live Activity \(activity.id, privacy: .public) for conversation \(conversationID.uuidString, privacy: .public)")
        } catch {
            latestStates[conversationID] = nil
            activityIDs[conversationID] = nil
            if currentConversationID == conversationID {
                currentConversationID = nil
            }
            logger.error("Failed to start Live Activity for conversation \(conversationID.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
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

        guard let activityID = activityIDs[conversationID] else {
            latestStates[conversationID] = nil
            return
        }

        Task {
            await Self.updateActivity(id: activityID, state: state)
        }

        // Ending an activity removes it from the Dynamic Island immediately, regardless of the Lock
        // Screen dismissal policy. Keep the terminal state active briefly so "Reply ready" is visible.
        completionEndTasks[conversationID] = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(max(0, retention)))
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
        if currentConversationID == conversationID {
            currentConversationID = nil
        }

        guard let activityID else { return }
        Task {
            await Self.endActivity(id: activityID, state: state, dismissalPolicy: .after(.now + 8))
        }
    }

    private func cancelCompletionEnd(for conversationID: UUID) {
        completionEndTasks[conversationID]?.cancel()
        completionEndTasks[conversationID] = nil
    }

    private func restoreTrackedActivity(for conversationID: UUID) {
        let activities = Activity<AgentReplyActivityAttributes>.activities
        if let trackedActivityID = activityIDs[conversationID] {
            guard activities.contains(where: { $0.id == trackedActivityID }) else {
                activityIDs[conversationID] = nil
                return restoreTrackedActivity(for: conversationID)
            }
            return
        }

        let conversationKey = conversationID.uuidString
        guard let existingActivity = activities.first(where: { activity in
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

            cancelCompletionEnd(for: otherConversationID)
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

    private func finishCompletedActivity(
        conversationID: UUID,
        state: AgentReplyActivityAttributes.ContentState
    ) async {
        latestStates[conversationID] = nil
        let activityID = activityIDs[conversationID]
        activityIDs[conversationID] = nil
        completionEndTasks[conversationID] = nil
        if currentConversationID == conversationID {
            currentConversationID = nil
        }

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
