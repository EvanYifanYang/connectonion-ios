//
//  AppDependencies.swift
//
//  Purpose: Implements AppDependencies for the App module.
//  Collaborates with: ConnectOnion_iOSApp.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Factory
import Foundation

extension Container {
    var identityStore: Factory<IdentityProviding> {
        self { @MainActor in KeychainIdentityStore() }
            .scope(.singleton)
    }

    var agentDirectoryService: Factory<AgentDirectoryServicing> {
        self { AgentDirectoryService() }
            .scope(.singleton)
    }

    var connectOnionClient: Factory<ConnectOnionClientProviding> {
        // Intentionally unscoped: each app-owned chat session needs an independent transport so
        // starting another conversation cannot replace the first conversation's receive stream.
        self { @MainActor in
            ConnectOnionClient(
                directory: Container.shared.agentDirectoryService(),
                identityStore: Container.shared.identityStore()
            )
        }
    }

    var liveActivityController: Factory<AgentReplyLiveActivityController> {
        self { @MainActor in AgentReplyLiveActivityController() }
            .scope(.singleton)
    }
}
