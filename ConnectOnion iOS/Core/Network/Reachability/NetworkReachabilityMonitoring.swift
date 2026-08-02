//
//  NetworkReachabilityMonitoring.swift
//
//  Purpose: Reports whether this device has a network path at all, so the app can stop blaming the
//           agent when the phone itself is offline.
//  Collaborates with: NetworkPathMonitor, MockNetworkReachabilityMonitor, AgentInfoStore.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation
import SwiftUI

/// Device-level connectivity. `.unknown` is the launch state: until the first path update arrives we
/// must not claim the device is offline, or every cold start would flash a false "no internet".
enum NetworkReachability: Equatable, Sendable {
    case unknown
    case online
    case offline

    /// True only when we positively know there is no path — never during the launch window.
    var isKnownOffline: Bool { self == .offline }
}

@MainActor
protocol NetworkReachabilityMonitoring: AnyObject, Observable {
    var reachability: NetworkReachability { get }
    func start()
}

private struct DeviceIsOfflineKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True only when the device is positively known to have no network path. Defaults to false so the
    /// launch window (before the first path update) never shows a false "no internet".
    var deviceIsOffline: Bool {
        get { self[DeviceIsOfflineKey.self] }
        set { self[DeviceIsOfflineKey.self] = newValue }
    }
}

extension AgentConnectionPhase {
    /// An agent can't be judged offline while the phone itself has no path — say so instead of
    /// blaming the agent. This also overrides a previously-confirmed `.online`: with no network path
    /// nothing is reachable, so that badge is stale, and leaving it up invites a tap that can only
    /// fail. Status polling is paused while offline, so it would not correct itself either.
    func offlineAware(deviceIsOffline: Bool) -> AgentConnectionPhase {
        deviceIsOffline ? .noInternet : self
    }
}
