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
    @ObservationIgnored private var allRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var focusedRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var autoRefreshAddresses: [String] = []
    @ObservationIgnored private var focusedAddress: String?
    @ObservationIgnored private var pendingRefreshAddresses = Set<String>()

    deinit {
        allRefreshTask?.cancel()
        focusedRefreshTask?.cancel()
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
        pendingRefreshAddresses.formUnion(addresses)
        guard !isRefreshing else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        while !pendingRefreshAddresses.isEmpty {
            let batch = Self.uniqueAddresses(Array(pendingRefreshAddresses))
            pendingRefreshAddresses.removeAll()

            for address in batch {
                let info = await directory.fetchAgentInfo(address: address)
                withAnimation(AppMotion.quick) {
                    infoByAddress[address] = info
                }
            }
        }
    }

    func startAutoRefresh(
        addresses: [String],
        focusedAddress: String? = nil,
        focusedInterval: Duration = .seconds(10),
        allInterval: Duration = .seconds(60),
        refreshImmediately: Bool = true
    ) {
        autoRefreshAddresses = Self.uniqueAddresses(addresses)
        self.focusedAddress = focusedAddress

        guard !autoRefreshAddresses.isEmpty else {
            stopAutoRefresh()
            return
        }

        if refreshImmediately {
            refresh(addresses: immediateRefreshAddresses)
        }

        allRefreshTask?.cancel()
        focusedRefreshTask?.cancel()

        allRefreshTask = repeatingRefreshTask(interval: allInterval) { [weak self] in
            self?.autoRefreshAddresses ?? []
        }

        if focusedAddress != nil {
            focusedRefreshTask = repeatingRefreshTask(interval: focusedInterval) { [weak self] in
                self?.focusedRefreshAddresses ?? []
            }
        } else {
            focusedRefreshTask = nil
        }
    }

    func stopAutoRefresh() {
        allRefreshTask?.cancel()
        focusedRefreshTask?.cancel()
        allRefreshTask = nil
        focusedRefreshTask = nil
        autoRefreshAddresses = []
        focusedAddress = nil
    }

    private var immediateRefreshAddresses: [String] {
        let focused = focusedRefreshAddresses
        return focused.isEmpty ? autoRefreshAddresses : focused
    }

    private var focusedRefreshAddresses: [String] {
        guard let focusedAddress, autoRefreshAddresses.contains(focusedAddress) else { return [] }
        return [focusedAddress]
    }

    private func repeatingRefreshTask(
        interval: Duration,
        addresses: @escaping @MainActor () -> [String]
    ) -> Task<Void, Never> {
        Task { @MainActor [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    return
                }

                await self.refreshNow(addresses: addresses())
            }
        }
    }

    private static func uniqueAddresses(_ addresses: [String]) -> [String] {
        var seen = Set<String>()
        return addresses.filter { seen.insert($0).inserted }
    }
}
