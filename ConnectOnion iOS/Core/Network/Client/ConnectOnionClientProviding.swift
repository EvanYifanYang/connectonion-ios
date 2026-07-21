//
//  ConnectOnionClientProviding.swift
//
//  Purpose: Implements ConnectOnionClientProviding for the Core/Network/Client module.
//  Collaborates with: AgentInput, ConnectOnionClient, ConnectOnionClientEvent, MockConnectOnionClient, ProtocolCodec, ServerEvent.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

@MainActor
protocol ConnectOnionClientProviding: AnyObject {
    func send(input: AgentInput, to agent: AgentConfig, session: ConversationSession) -> AsyncThrowingStream<ConnectOnionClientEvent, Error>
    func reconnect(to agent: AgentConfig, session: ConversationSession) -> AsyncThrowingStream<ConnectOnionClientEvent, Error>
    func sendAskUserResponse(_ answer: String) async throws
    func sendApprovalResponse(approved: Bool, scope: String, mode: String?, feedback: String?) async throws
    func sendOnboardSubmit(inviteCode: String?, payment: Double?) async throws
    func sendPlanReviewResponse(_ message: String) async throws
    func disconnect()
}
