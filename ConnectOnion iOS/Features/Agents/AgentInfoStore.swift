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
    @ObservationIgnored private var autoRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var autoRefreshAddresses: [String] = []
    @ObservationIgnored private var autoRefreshInterval: Duration = .seconds(15)

    deinit {
        autoRefreshTask?.cancel()
    }

    func refresh(addresses: [String]) {
        Task {
            await refreshNow(addresses: addresses)
        }
    }

    func refreshNow(addresses: [String]) async {
        let addresses = Self.uniqueAddresses(addresses)
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

    func startAutoRefresh(
        addresses: [String],
        interval: Duration = .seconds(15),
        refreshImmediately: Bool = true
    ) {
        autoRefreshAddresses = Self.uniqueAddresses(addresses)
        autoRefreshInterval = interval

        guard !autoRefreshAddresses.isEmpty else {
            stopAutoRefresh()
            return
        }

        if refreshImmediately {
            refresh(addresses: autoRefreshAddresses)
        }

        guard autoRefreshTask == nil else { return }
        autoRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: self.autoRefreshInterval)
                } catch {
                    return
                }

                await self.refreshNow(addresses: self.autoRefreshAddresses)
            }
        }
    }

    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
        autoRefreshAddresses = []
    }

    private static func uniqueAddresses(_ addresses: [String]) -> [String] {
        var seen = Set<String>()
        return addresses.filter { seen.insert($0).inserted }
    }
}
