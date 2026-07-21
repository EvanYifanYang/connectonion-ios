//
//  ServerEvent.swift
//
//  Purpose: Implements ServerEvent for the Core/Network/Client module.
//  Collaborates with: AgentInput, ConnectOnionClient, ConnectOnionClientEvent, ConnectOnionClientProviding, MockConnectOnionClient, ProtocolCodec.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

struct ServerEvent: Equatable, Sendable {
    var type: String
    var payload: [String: JSONValue]

    init(payload: [String: JSONValue]) {
        self.payload = payload
        type = payload[string: "type"] ?? ""
    }

    var id: String? {
        payload[string: "id"] ?? payload[string: "tool_id"]
    }
}
