//
//  MockConnectOnionClient.swift
//
//  Purpose: Implements MockConnectOnionClient for the Core/Network/Client module.
//  Collaborates with: AgentInput, ConnectOnionClient, ConnectOnionClientEvent, ConnectOnionClientProviding, ProtocolCodec, ServerEvent.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

@MainActor
final class MockConnectOnionClient: ConnectOnionClientProviding {
    enum Mode {
        case standard
        case onboardFirstMessage
    }

    private let mode: Mode
    private var continuation: AsyncThrowingStream<ConnectOnionClientEvent, Error>.Continuation?
    private var onboardAccepted = false
    private(set) var sentControlMessages: [String] = []

    init(mode: Mode = .standard) {
        self.mode = mode
    }

    func send(input: AgentInput, to agent: AgentConfig, session: ConversationSession) -> AsyncThrowingStream<ConnectOnionClientEvent, Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation
            continuation.yield(.connected(sessionID: session.id.uuidString, status: "connected", serverNewer: false, session: nil, chatItems: []))

            if mode == .onboardFirstMessage && !onboardAccepted {
                continuation.yield(.server(ServerEvent(payload: [
                    "type": .string("RUNTIME_INPUT_ACK"),
                    "id": .string("mock-input-ack")
                ])))
                continuation.yield(.server(ServerEvent(payload: [
                    "type": .string("ONBOARD_REQUIRED"),
                    "id": .string("mock-onboard"),
                    "methods": .array([.string("invite_code")])
                ])))
                return
            }

            continuation.yield(.server(ServerEvent(payload: [
                "type": .string("llm_call"),
                "id": .string("mock-thinking"),
                "model": .string("co/mock")
            ])))
            continuation.yield(.server(ServerEvent(payload: [
                "type": .string("assistant"),
                "id": .string("mock-agent"),
                "content": .string("Connected. Streaming mock response for: \(input.prompt)")
            ])))
            continuation.yield(.output(
                result: "Connected. Streaming mock response for: \(input.prompt)",
                durationMS: nil,
                serverNewer: false,
                session: nil,
                chatItems: []
            ))
            continuation.finish()
        }
    }

    func reconnect(to agent: AgentConfig, session: ConversationSession) -> AsyncThrowingStream<ConnectOnionClientEvent, Error> {
        send(input: AgentInput(prompt: "Reconnect"), to: agent, session: session)
    }

    func sendAskUserResponse(_ answer: String) async throws {
        sentControlMessages.append("ask_user:\(answer)")
    }

    func sendApprovalResponse(approved: Bool, scope: String, mode: String?, feedback: String?) async throws {
        sentControlMessages.append("approval:\(approved):\(scope)")
    }

    func sendOnboardSubmit(inviteCode: String?, payment: Double?) async throws {
        sentControlMessages.append("onboard:\(inviteCode ?? "")")
        guard mode == .onboardFirstMessage else { return }
        onboardAccepted = true
        continuation?.yield(.server(ServerEvent(payload: [
            "type": .string("ONBOARD_SUCCESS"),
            "id": .string("mock-onboard-success"),
            "message": .string("Invite accepted")
        ])))
        continuation?.finish()
    }

    func sendPlanReviewResponse(_ message: String) async throws {
        sentControlMessages.append("plan:\(message)")
    }

    func disconnect() {
        continuation?.finish()
    }
}
