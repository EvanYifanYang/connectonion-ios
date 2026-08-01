//
//  ChatViewModel+Output.swift
//
//  Purpose: Handles the OUTPUT frame that terminates an agent turn.
//  Collaborates with: ChatViewModel, ChatEventReducer, AgentContentSanitizer.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

extension ChatViewModel {
    /// The terminal frame of a turn. Extracted from `handle` so that dispatch stays readable and
    /// within the function-size budget.
    func handleOutput(
        result: String,
        durationMS: Int?,
        serverNewer: Bool,
        session: JSONValue?,
        chatItems: [ChatItem]
    ) {
        // Capture turn-scoped metrics before a newer canonical snapshot can omit intermediate
        // events. They are persisted on the final reply below.
        let completedTurnDurationMS = currentTurnDurationMS
        let completedContextPercent = contextPercent
        automaticReconnectAttempts = 0
        automaticReconnectTask?.cancel()
        let regenerating = isRegenerating
        let sanitizedChatItems = chatItems.isEmpty ? [] : Self.sanitizingUserPrompts(in: chatItems)
        let replacementResult = regenerating
            ? usableReplacementResult(result: result, chatItems: sanitizedChatItems)
            : result
        commitOptimisticUserPrompt()
        clearInFlightInput()
        clearOptimisticPlaceholder()
        failedTurn = nil // the turn landed; nothing left to retry

        guard !regenerating || replacementResult != nil else {
            streamTask = nil
            conversation.pendingTurnStartedAt = nil // terminal, like every other turn-ending path
            _ = restoreRegenerateBackup()
            failure = ChatFailure(
                title: "The agent returned an empty response",
                body: "The original exchange was restored.",
                action: .dismiss
            )
            sessionState = items.isEmpty ? .idle : .connected
            stopTimer()
            client.disconnect()
            liveActivity.end(
                conversationID: conversation.id,
                phase: .failed,
                headline: "Reply could not be replaced",
                detail: "The original exchange was restored"
            )
            return
        }

        regenerateBackup = nil // a usable replacement exists, so the old exchange is no longer needed
        isRegenerating = false
        let finalResult = AgentContentSanitizer.sanitize(replacementResult ?? result)
        // Only adopt a newer server snapshot, and reconcile it at a user-turn boundary so an
        // unacknowledged local turn and locally answered cards cannot be rolled back.
        if serverNewer, !regenerating {
            // Use the prompt-stripped list (as restore + the .connected path do), otherwise the
            // host-echoed personalisation/custom-instructions wrapper leaks into visible user
            // bubbles because reconcile matches user items by content and never finds the local one.
            ChatEventReducer.reconcile(with: AgentContentSanitizer.sanitize(sanitizedChatItems), items: &items)
        }
        // Ensure the fresh reply exists as the LAST item so it can be revealed. Guard on the last
        // *item* (not the last agent anywhere): on a regenerate the canonical list is skipped, so a
        // prior turn's identical reply must not be mistaken for this turn's — there the re-sent user
        // is the last item, so we still append the fresh bubble below it.
        if !finalResult.isEmpty, !(items.last?.kind == .agent && items.last?.content == finalResult) {
            // A streamed agent_image arrives before the reply text and parks in a content-less
            // agent row. Fill that row rather than appending a second bubble: otherwise the turn
            // renders two agent messages, the image-only one is not the turn's final answer, and it
            // would be folded into the collapsed trace (which draws no images) and disappear.
            if let index = items.indices.last,
               items[index].kind == .agent,
               items[index].content.isEmpty,
               !items[index].images.isEmpty {
                items[index].content = finalResult
            } else {
                let agentItem = ChatItem(kind: .agent, content: finalResult)
                append(agentItem, shouldPersist: false)
            }
        }
        finalizeRunningItems()
        // Type the reply out client-side. The host server never emits a live "assistant" event — the
        // reply only ever arrives here in OUTPUT — so point the typewriter at the just-finished reply
        // however it landed (adopted from the canonical list or appended above). This is the single
        // place the reveal is triggered for a normal turn. Skip the reveal for replies with block
        // markdown (code fences, tables, headings): the inline typewriter would show raw ``` / | and
        // then snap to a formatted card — for a coding agent that's most replies, so render formatted
        // immediately instead.
        if !finalResult.isEmpty,
           !Self.hasBlockMarkdown(finalResult),
           let index = items.lastIndex(where: { $0.kind == .agent }),
           items[index].content == finalResult {
            streamingMessageID = items[index].id
        }
        // Stamp the model onto the reply itself so the footer survives a reload — the thinking row
        // that carries it may not be present in the server's canonical list.
        if let model = lastResponseModel,
           let index = items.lastIndex(where: { $0.kind == .agent }) {
            items[index].model = model
        }
        if let index = items.lastIndex(where: { $0.kind == .agent }) {
            items[index].durationMS = durationMS
                ?? completedTurnDurationMS
                ?? currentTurnDurationMS
                ?? items[index].durationMS
            items[index].contextPercent = completedContextPercent
                ?? contextPercent
                ?? items[index].contextPercent
        }
        lastResponseModel = items.last(where: { $0.kind == .agent })?.model
        conversation.rawSession = session
        sessionState = .connected
        streamTask = nil
        latestTurnCompleted = hasCompletedLatestExchange
        conversation.pendingTurnStartedAt = nil // reply delivered — turn no longer awaiting
        stopTimer()
        persist()
        onReplyReady()
        client.disconnect()
        liveActivity.complete(
            conversationID: conversation.id,
            headline: "Reply ready",
            detail: "\(agent.displayName) finished responding"
        )
        if !finalResult.isEmpty {
            onReplyCompleted(conversation)
        }

    }
}
