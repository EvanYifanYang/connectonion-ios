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
