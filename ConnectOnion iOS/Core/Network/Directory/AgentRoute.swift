//
//  AgentRoute.swift
//
//  Purpose: Implements AgentRoute for the Core/Network/Directory module.
//  Collaborates with: AgentDirectoryService, AgentDirectoryServicing, AgentProfile, DirectAgentInfo, MockAgentDirectoryService, RelayAgentRecord.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

enum AgentRoute: Equatable, Sendable {
    case direct(httpURL: URL, webSocketURL: URL)
    case relay(webSocketURL: URL)

    var webSocketURL: URL {
        switch self {
        case .direct(_, let webSocketURL), .relay(let webSocketURL):
            webSocketURL
        }
    }

    var isDirect: Bool {
        if case .direct = self { true } else { false }
    }
}
