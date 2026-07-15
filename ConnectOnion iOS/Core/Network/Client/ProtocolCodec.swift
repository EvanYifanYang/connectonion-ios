import Foundation

@MainActor
struct ProtocolCodec {
    private let identityStore: IdentityProviding

    init(identityStore: IdentityProviding) {
        self.identityStore = identityStore
    }

    func connectMessage(agentAddress: String, route: AgentRoute, session: ConversationSession) throws -> [String: JSONValue] {
        let payload: [String: JSONValue] = [
            "timestamp": .number(Double(Int(Date.now.timeIntervalSince1970))),
            "to": .string(agentAddress)
        ]
        let signed = try identityStore.sign(payload: payload)

        var message = signed.jsonObject
        message["type"] = .string("CONNECT")
        message["session_id"] = .string(session.remoteSessionID ?? session.id.uuidString)
        message["session"] = .object(session.protocolSessionObject)

        if let lastRenderedEventID = session.lastRenderedEventID {
            message["last_msg_id"] = .string(lastRenderedEventID)
        }
        if !route.isDirect {
            message["to"] = .string(agentAddress)
        }

        return message
    }

    func inputMessage(input: AgentInput, agentAddress: String, route: AgentRoute) throws -> [String: JSONValue] {
        let timestamp = Int(Date.now.timeIntervalSince1970)
        var message: [String: JSONValue] = [
            "type": .string("INPUT"),
            "input_id": .string(UUID().uuidString),
            "prompt": .string(input.prompt),
            "timestamp": .number(Double(timestamp))
        ]

        if !input.images.isEmpty {
            message["images"] = .array(input.images.map(JSONValue.string))
        }
        if !input.files.isEmpty {
            message["files"] = .array(input.files.map { file in
                .object([
                    "name": .string(file.name),
                    "data": .string(file.dataURL)
                ])
            })
        }
        if !route.isDirect {
            message["to"] = .string(agentAddress)
        }

        var payload: [String: JSONValue] = [
            "prompt": .string(input.prompt),
            "timestamp": .number(Double(timestamp))
        ]
        if !route.isDirect {
            payload["to"] = .string(agentAddress)
        }
        let signed = try identityStore.sign(payload: payload)
        message["payload"] = .object(signed.payload)
        message["from"] = .string(signed.from)
        message["signature"] = .string(signed.signature)
        message["timestamp"] = .number(Double(signed.timestamp))

        return message
    }

    func onboardSubmit(inviteCode: String?, payment: Double?) throws -> [String: JSONValue] {
        var payload: [String: JSONValue] = [
            "timestamp": .number(Double(Int(Date.now.timeIntervalSince1970)))
        ]
        if let inviteCode, !inviteCode.isEmpty {
            payload["invite_code"] = .string(inviteCode)
        }
        if let payment {
            payload["payment"] = .number(payment)
        }

        var message = try identityStore.sign(payload: payload).jsonObject
        message["type"] = .string("ONBOARD_SUBMIT")
        return message
    }

    func askUserResponse(_ answer: String) -> [String: JSONValue] {
        ["type": .string("ASK_USER_RESPONSE"), "answer": .string(answer)]
    }

    func approvalResponse(approved: Bool, scope: String, mode: String?, feedback: String?) -> [String: JSONValue] {
        var message: [String: JSONValue] = [
            "type": .string("APPROVAL_RESPONSE"),
            "approved": .bool(approved),
            "scope": .string(scope)
        ]
        if let mode {
            message["mode"] = .string(mode)
        }
        if let feedback, !feedback.isEmpty {
            message["feedback"] = .string(feedback)
        }
        return message
    }

    func planReviewResponse(message: String) -> [String: JSONValue] {
        ["type": .string("PLAN_REVIEW_RESPONSE"), "message": .string(message)]
    }

    func decode(_ text: String) throws -> ServerEvent {
        let data = Data(text.utf8)
        let payload = try JSONDecoder().decode([String: JSONValue].self, from: data)
        return ServerEvent(payload: payload)
    }
}
