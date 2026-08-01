//
//  MockNetworkReachabilityMonitor.swift
//
//  Purpose: Test/preview double for NetworkReachabilityMonitoring.
//  Collaborates with: NetworkReachabilityMonitoring, PreviewFixtures.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation
import Observation

@MainActor
@Observable
final class MockNetworkReachabilityMonitor: NetworkReachabilityMonitoring {
    var reachability: NetworkReachability

    init(reachability: NetworkReachability = .online) {
        self.reachability = reachability
    }

    func start() {}
}
