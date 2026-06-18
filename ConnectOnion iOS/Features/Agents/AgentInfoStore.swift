import Factory
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AgentInfoStore {
    var infoByAddress: [String: AgentInfo] = [:]
    var isRefreshing = false

    @ObservationIgnored
    @Injected(\.agentDirectoryService) private var directory: AgentDirectoryServicing

    func refresh(addresses: [String]) {
        Task {
            await refreshNow(addresses: addresses)
        }
    }

    func refreshNow(addresses: [String]) async {
        guard !addresses.isEmpty else {
            isRefreshing = false
            return
        }
        guard !isRefreshing else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        for address in addresses {
            let info = await directory.fetchAgentInfo(address: address)
            withAnimation(AppMotion.quick) {
                infoByAddress[address] = info
            }
        }
    }
}
