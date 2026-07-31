//
//  ConnectOnionClientEvent.swift
//
//  Purpose: Implements ConnectOnionClientEvent for the Core/Network/Client module.
//  Collaborates with: AgentInput, ConnectOnionClient, ConnectOnionClientProviding, MockConnectOnionClient, ProtocolCodec, ServerEvent.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

enum ConnectOnionClientEvent: Equatable, Sendable {
    case connected(sessionID: String, status: String, serverNewer: Bool, session: JSONValue?, chatItems: [ChatItem])
    case profile(AgentProfile)
    case control(ServerEvent)
    case server(ServerEvent)
    case output(result: String, durationMS: Int?, serverNewer: Bool, session: JSONValue?, chatItems: [ChatItem])
    case failure(String)
}
