//
//  NetworkPathMonitor.swift
//
//  Purpose: NWPathMonitor-backed implementation of NetworkReachabilityMonitoring.
//  Collaborates with: NetworkReachabilityMonitoring, AppDependencies, AgentInfoStore.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation
import Network
import Observation

@MainActor
@Observable
final class NetworkPathMonitor: NetworkReachabilityMonitoring {
    private(set) var reachability: NetworkReachability = .unknown

    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private let queue = DispatchQueue(label: "com.romantcD.ConnectOnion-iOS.path")
    @ObservationIgnored private var isRunning = false

    func start() {
        guard !isRunning else { return }
        isRunning = true
        // NWPathMonitor delivers on its own queue; hop to the main actor since the published state is
        // read from SwiftUI and the @MainActor stores.
        monitor.pathUpdateHandler = { [weak self] path in
            let value: NetworkReachability = path.status == .satisfied ? .online : .offline
            Task { @MainActor [weak self] in
                self?.reachability = value
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
