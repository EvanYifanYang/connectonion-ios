//
//  AgentDirectoryServicing.swift
//
//  Purpose: Implements AgentDirectoryServicing for the Core/Network/Directory module.
//  Collaborates with: AgentDirectoryService, AgentProfile, AgentRoute, DirectAgentInfo, MockAgentDirectoryService, RelayAgentRecord.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

protocol AgentDirectoryServicing: Sendable {
    func fetchAgentInfo(address: String, preferredEndpoint: URL?) async -> AgentInfo
    func resolveRoute(for address: String, preferredEndpoint: URL?) async throws -> AgentRoute
    /// Drop any cached route for this agent — its endpoint changed, or a connection just failed.
    func invalidateRoute(for address: String) async
}

extension AgentDirectoryServicing {
    /// Caching is an implementation detail of the live service; mocks and test doubles need no-op.
    func invalidateRoute(for address: String) async {}
}
