//
//  AgentInfoStore.swift
//
//  Purpose: Implements AgentInfoStore for the Features/Agents module.
//  Collaborates with: AgentCapabilityLine, AgentEditorView, AgentHeroView, AgentHomeView, AgentInfoPopover, AgentLandingView.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Factory
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AgentInfoStore {
    var infoByAddress: [String: AgentInfo] = [:]
    private(set) var isRefreshing = false

    @ObservationIgnored
    @Injected(\.agentDirectoryService) private var directory: AgentDirectoryServicing
    @ObservationIgnored private let directoryOverride: AgentDirectoryServicing?
    @ObservationIgnored private var allRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var focusedRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var autoRefreshAddresses: [String] = []
    @ObservationIgnored private var focusedAddress: String?
    @ObservationIgnored private var pendingRefreshAddresses = Set<String>()
    @ObservationIgnored private var endpointsByAddress: [String: URL] = [:]
    @ObservationIgnored private var generationByAddress: [String: UInt64] = [:]
    @ObservationIgnored private var inFlightGenerationByAddress: [String: UInt64] = [:]
    @ObservationIgnored private var removedAddresses = Set<String>()
    @ObservationIgnored private var authenticatedProfilesByAddress: [String: AgentProfile] = [:]
    /// Consecutive offline probes per agent. An already-online agent only flips to offline after
    /// `offlineThreshold` consecutive failed probes, so one slow/dropped poll can't flap the dot.
    @ObservationIgnored private var offlineStrikesByAddress: [String: Int] = [:]
    // 2 consecutive failures (with the widened 7s probe timeout) still absorbs a single slow/dropped
    // poll but detects a genuine shutdown within ~2 poll cycles instead of 3.
    private static let offlineThreshold = 2

    init(directory: AgentDirectoryServicing? = nil) {
        directoryOverride = directory
    }

    /// The user-configured direct endpoints, keyed by agent address, so the status probe can reach a
    /// relay-less local agent. Call this whenever the agent list changes.
    func setEndpoints(_ endpoints: [String: URL]) {
        let addresses = Set(endpointsByAddress.keys).union(endpoints.keys)
        for address in addresses where endpointsByAddress[address] != endpoints[address] {
            bumpGeneration(for: address)
        }
        endpointsByAddress = endpoints
    }

    func setEndpoint(_ endpoint: URL?, for address: String) {
        if endpointsByAddress[address] != endpoint {
            bumpGeneration(for: address)
        }
        endpointsByAddress[address] = endpoint
    }

    /// Marks an explicitly added (or re-added) record as active. Ordinary refresh and endpoint
    /// synchronization deliberately cannot resurrect a deleted address.
    func activate(address: String) {
        guard removedAddresses.remove(address) != nil else { return }
        bumpGeneration(for: address)
    }

    func remove(address: String) {
        bumpGeneration(for: address)
        removedAddresses.insert(address)
        pendingRefreshAddresses.remove(address)
        inFlightGenerationByAddress.removeValue(forKey: address)
        authenticatedProfilesByAddress.removeValue(forKey: address)
        offlineStrikesByAddress.removeValue(forKey: address)
        endpointsByAddress.removeValue(forKey: address)
        infoByAddress.removeValue(forKey: address)
        autoRefreshAddresses.removeAll { $0 == address }

        if focusedAddress == address {
            focusedAddress = nil
            focusedRefreshTask?.cancel()
            focusedRefreshTask = nil
        }
        if autoRefreshAddresses.isEmpty {
            allRefreshTask?.cancel()
            allRefreshTask = nil
        }
    }

    func connectionPhase(for address: String) -> AgentConnectionPhase {
        AgentConnectionPhase(info: infoByAddress[address])
    }

    /// Applies the full profile that connectonion 1.5.3 sends after authenticated CONNECTED.
    /// Connection itself is definitive online evidence; public `/info`/relay fields remain as
    /// fallbacks for fields the authenticated frame omits.
    @discardableResult
    func mergeAuthenticatedProfile(_ profile: AgentProfile, for address: String) -> AgentInfo? {
        guard !removedAddresses.contains(address),
              profile.address == nil || profile.address == address else { return nil }

        authenticatedProfilesByAddress[address] = profile
        var info = (infoByAddress[address] ?? AgentInfo(address: address))
            .merged(withAuthenticated: profile)
        info.online = true
        offlineStrikesByAddress[address] = 0

        withAnimation(AppMotion.quick) {
            infoByAddress[address] = info
        }
        return info
    }

    deinit {
        allRefreshTask?.cancel()
        focusedRefreshTask?.cancel()
        refreshTask?.cancel()
    }

    func refresh(addresses: [String]) {
        Task {
            await refreshNow(addresses: addresses)
        }
    }

    func refreshNow(addresses: [String]) async {
        let addresses = Self.uniqueAddresses(addresses).filter { !removedAddresses.contains($0) }
        guard !addresses.isEmpty else { return }

        for address in addresses {
            let generation = generationByAddress[address, default: 0]
            if inFlightGenerationByAddress[address] != generation {
                pendingRefreshAddresses.insert(address)
            }
        }

        if let refreshTask {
            await refreshTask.value
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await drainRefreshQueue()
        }
        refreshTask = task
        isRefreshing = true
        await task.value
    }

    private func drainRefreshQueue() async {
        defer {
            isRefreshing = false
            refreshTask = nil
        }

        while !pendingRefreshAddresses.isEmpty {
            let batch = Self.uniqueAddresses(Array(pendingRefreshAddresses))
                .filter { !removedAddresses.contains($0) }
            pendingRefreshAddresses.removeAll()
            guard !batch.isEmpty else { continue }

            let directoryService = directoryOverride ?? self.directory
            let endpoints = endpointsByAddress
            let generations = generationByAddress
            await withTaskGroup(of: (String, UInt64, AgentInfo).self) { group in
                for address in batch {
                    let generation = generations[address] ?? 0
                    inFlightGenerationByAddress[address] = generation
                    group.addTask {
                        let info = await directoryService.fetchAgentInfo(
                            address: address,
                            preferredEndpoint: endpoints[address]
                        )
                        return (address, generation, info)
                    }
                }

                // Publish each result as soon as it arrives. A slow endpoint must not leave every
                // other agent in this batch stuck in Checking.
                for await (address, generation, info) in group {
                    apply(info, to: address, generation: generation)
                }
            }
        }
    }

    private func apply(_ info: AgentInfo, to address: String, generation: UInt64) {
        defer {
            if inFlightGenerationByAddress[address] == generation {
                inFlightGenerationByAddress.removeValue(forKey: address)
            }
        }

        // Endpoint edits and deletion bump the generation, invalidating any older in-flight probe.
        guard !removedAddresses.contains(address),
              generationByAddress[address, default: 0] == generation else { return }

        // Offline hysteresis: never demote a currently-online agent on a single failed/slow probe.
        // Hold the last-known-online entry until `offlineThreshold` consecutive failures accumulate;
        // any successful probe resets the counter.
        if !info.online, infoByAddress[address]?.online == true {
            let strikes = (offlineStrikesByAddress[address] ?? 0) + 1
            offlineStrikesByAddress[address] = strikes
            if strikes < Self.offlineThreshold { return }
        }
        if info.online {
            offlineStrikesByAddress[address] = 0
        }

        var mergedInfo = info
        if let profile = authenticatedProfilesByAddress[address] {
            // `/info` deliberately exposes only published skills in connectonion 1.5.3. Once this
            // client has authenticated, keep its full profile authoritative so the next periodic
            // public probe cannot shrink the skill/tool list again.
            mergedInfo = (infoByAddress[address] ?? AgentInfo(address: address))
                .merged(with: info)
                .merged(withAuthenticated: profile)
            mergedInfo.online = info.online
        }

        withAnimation(AppMotion.quick) {
            infoByAddress[address] = mergedInfo
        }
    }

    func startAutoRefresh(
        addresses: [String],
        focusedAddress: String? = nil,
        focusedInterval: Duration = .seconds(10),
        allInterval: Duration = .seconds(30),
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
        offlineStrikesByAddress.removeAll()
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

    private func bumpGeneration(for address: String) {
        generationByAddress[address, default: 0] &+= 1
        // The agent's endpoint configuration just changed (added, edited, or removed), so any route
        // cached for it is suspect — drop it so the next send re-probes instead of dialling a stale one.
        let directory = directoryOverride ?? self.directory
        Task { await directory.invalidateRoute(for: address) }
    }

}
