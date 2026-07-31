//
//  AgentRoutingTests.swift
//
//  Purpose: Implements AgentRoutingTests for the ConnectOnion iOSTests module.
//  Collaborates with: AgentQRCodePayloadTests, ChatSessionStoreTests, CustomInstructionsTests, PersonalisationPreferencesTests, Sprint1Tests, Sprint2Tests.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation
import Testing
import os
@testable import ConnectOnion_iOS

// MARK: - Routing — preferred endpoint vs relay fallback
//
// `AgentDirectoryService.resolveRoute` used to treat a configured endpoint as make-or-break: if the
// direct `/info` probe failed it threw immediately and never tried the relay. On a campus / NAT'd LAN
// the advertised LAN address *looks* usable (it's not localhost) but the iPhone can't route to it, so
// a perfectly relay-reachable agent surfaced as "connection failed". These tests pin the fixed
// behaviour: an unreachable preferred endpoint falls back to the relay, while a reachable one still
// wins directly.
//
// The service is exercised for real (not the mock) against a stubbed `URLSession`, so the routing
// decision itself is under test rather than a hand-written double.

@Suite("Agent routing — preferred endpoint vs relay", .serialized)
struct AgentRoutingTests {
    /// A campus-style LAN endpoint: passes `isUsableFromCurrentDevice` (not localhost) yet is not
    /// actually reachable from this device.
    private let campusEndpoint = URL(string: "http://10.83.12.7:8000")!

    @Test("An unreachable preferred endpoint falls back to the relay instead of failing")
    func unreachablePreferredEndpointFallsBackToRelay() async throws {
        StubURLProtocol.install { url in
            let target = url.absoluteString
            if target.contains("10.83.12.7") {
                // The LAN `/info` probe can't connect — exactly the campus-network case.
                return .failure(URLError(.cannotConnectToHost))
            }
            if target.contains("/api/relay/agents/") {
                // The relay knows this agent and offers a relay route (no direct endpoints).
                return .ok(#"{"relay":"oo","endpoints":[]}"#)
            }
            return .failure(URLError(.unsupportedURL))
        }
        defer { StubURLProtocol.removeAll() }

        let service = AgentDirectoryService(session: .stubbedRouting())
        let route = try await service.resolveRoute(for: testAgentAddress, preferredEndpoint: campusEndpoint)

        #expect(route.isDirect == false)
        guard case .relay = route else {
            Issue.record("Expected a relay fallback, got \(route)")
            return
        }
    }

    @Test("A reachable preferred endpoint is still used directly and never consults the relay")
    func reachablePreferredEndpointUsesDirect() async throws {
        StubURLProtocol.install { url in
            let target = url.absoluteString
            if target.contains("10.83.12.7"), target.hasSuffix("/info") {
                return .ok(#"{"address":"\#(testAgentAddress)","name":"Campus Agent"}"#)
            }
            // The relay must not be needed when the preferred endpoint answers.
            return .failure(URLError(.unsupportedURL))
        }
        defer { StubURLProtocol.removeAll() }

        let service = AgentDirectoryService(session: .stubbedRouting())
        let route = try await service.resolveRoute(for: testAgentAddress, preferredEndpoint: campusEndpoint)

        guard case let .direct(httpURL, webSocketURL) = route else {
            Issue.record("Expected a direct route, got \(route)")
            return
        }
        #expect(httpURL == campusEndpoint)
        #expect(webSocketURL == URL(string: "ws://10.83.12.7:8000/ws")!)
    }

    @Test("With no preferred endpoint, a relay-only agent resolves to the relay route")
    func noPreferredEndpointUsesRelay() async throws {
        StubURLProtocol.install { url in
            if url.absoluteString.contains("/api/relay/agents/") {
                return .ok(#"{"relay":"oo","endpoints":[]}"#)
            }
            return .failure(URLError(.unsupportedURL))
        }
        defer { StubURLProtocol.removeAll() }

        let service = AgentDirectoryService(session: .stubbedRouting())
        let route = try await service.resolveRoute(for: testAgentAddress, preferredEndpoint: nil)

        guard case .relay = route else {
            Issue.record("Expected a relay route, got \(route)")
            return
        }
    }
}

@Suite("Agent status refresh")
@MainActor
struct AgentStatusRefreshTests {
    private let firstAddress = "agent-first"
    private let secondAddress = "agent-second"

    @Test("Unknown status remains Checking until the first fetch completes")
    func initialStatusIsChecking() async {
        let directory = DelayedAgentDirectory(delay: .milliseconds(100), onlineAddresses: [firstAddress])
        let store = AgentInfoStore(directory: directory)

        #expect(store.connectionPhase(for: firstAddress) == .checking)

        let refresh = Task { @MainActor in
            await store.refreshNow(addresses: [firstAddress])
        }
        await waitUntil { store.isRefreshing }

        #expect(store.connectionPhase(for: firstAddress) == .checking)

        await refresh.value

        #expect(store.connectionPhase(for: firstAddress) == .online)
        #expect(!store.isRefreshing)
    }

    @Test("An overlapping manual refresh waits for the shared queue")
    func overlappingRefreshWaitsForRequestedAddresses() async {
        let directory = DelayedAgentDirectory(
            delay: .milliseconds(100),
            onlineAddresses: [firstAddress, secondAddress]
        )
        let store = AgentInfoStore(directory: directory)

        let firstRefresh = Task { @MainActor in
            await store.refreshNow(addresses: [firstAddress])
        }
        await waitUntil { store.isRefreshing }

        await store.refreshNow(addresses: [secondAddress])

        #expect(store.connectionPhase(for: firstAddress) == .online)
        #expect(store.connectionPhase(for: secondAddress) == .online)
        #expect(!store.isRefreshing)
        await firstRefresh.value
    }

    @Test("A fast agent publishes while another agent is still loading")
    func completedProbePublishesWithoutWaitingForBatch() async {
        let directory = StaggeredAgentDirectory(
            delays: [firstAddress: .milliseconds(20), secondAddress: .seconds(2)],
            onlineAddresses: [firstAddress, secondAddress]
        )
        let store = AgentInfoStore(directory: directory)

        let refresh = Task { @MainActor in
            await store.refreshNow(addresses: [firstAddress, secondAddress])
        }
        await waitUntil { store.connectionPhase(for: firstAddress) == .online }

        #expect(store.connectionPhase(for: firstAddress) == .online)
        #expect(store.connectionPhase(for: secondAddress) == .checking)
        #expect(store.isRefreshing)

        await refresh.value
        #expect(store.connectionPhase(for: secondAddress) == .online)
    }

    @Test("A deleted agent rejects refresh work that arrives after deletion")
    func deletedAgentRejectsLateRefresh() async {
        let directory = CountingAgentDirectory(delay: .milliseconds(20), onlineAddresses: [firstAddress])
        let store = AgentInfoStore(directory: directory)

        store.remove(address: firstAddress)
        await store.refreshNow(addresses: [firstAddress])

        let fetchCount = await directory.fetchCount()
        #expect(fetchCount == 0)
        #expect(store.infoByAddress[firstAddress] == nil)

        store.activate(address: firstAddress)
        await store.refreshNow(addresses: [firstAddress])

        let readdedFetchCount = await directory.fetchCount()
        #expect(readdedFetchCount == 1)
        #expect(store.connectionPhase(for: firstAddress) == .online)
    }

    @Test("Overlapping refreshes for one generation share a single probe")
    func sameGenerationRefreshesShareProbe() async {
        let directory = CountingAgentDirectory(delay: .milliseconds(150), onlineAddresses: [firstAddress])
        let store = AgentInfoStore(directory: directory)

        let firstRefresh = Task { @MainActor in
            await store.refreshNow(addresses: [firstAddress])
        }
        await waitUntil { store.isRefreshing }
        try? await Task.sleep(for: .milliseconds(30))

        await store.refreshNow(addresses: [firstAddress])
        await firstRefresh.value

        let fetchCount = await directory.fetchCount()
        #expect(fetchCount == 1)
        #expect(store.connectionPhase(for: firstAddress) == .online)
    }
}

private struct DelayedAgentDirectory: AgentDirectoryServicing {
    var delay: Duration
    var onlineAddresses: Set<String>

    func fetchAgentInfo(address: String, preferredEndpoint: URL?) async -> AgentInfo {
        try? await Task.sleep(for: delay)
        return AgentInfo(address: address, online: onlineAddresses.contains(address))
    }

    func resolveRoute(for address: String, preferredEndpoint: URL?) async throws -> AgentRoute {
        .relay(webSocketURL: URL(string: "wss://example.com/ws/input")!)
    }
}

private struct StaggeredAgentDirectory: AgentDirectoryServicing {
    var delays: [String: Duration]
    var onlineAddresses: Set<String>

    func fetchAgentInfo(address: String, preferredEndpoint: URL?) async -> AgentInfo {
        try? await Task.sleep(for: delays[address] ?? .zero)
        return AgentInfo(address: address, online: onlineAddresses.contains(address))
    }

    func resolveRoute(for address: String, preferredEndpoint: URL?) async throws -> AgentRoute {
        .relay(webSocketURL: URL(string: "wss://example.com/ws/input")!)
    }
}

private actor CountingAgentDirectory: AgentDirectoryServicing {
    let delay: Duration
    let onlineAddresses: Set<String>
    private var count = 0

    init(delay: Duration, onlineAddresses: Set<String>) {
        self.delay = delay
        self.onlineAddresses = onlineAddresses
    }

    func fetchAgentInfo(address: String, preferredEndpoint: URL?) async -> AgentInfo {
        count += 1
        try? await Task.sleep(for: delay)
        return AgentInfo(address: address, online: onlineAddresses.contains(address))
    }

    func resolveRoute(for address: String, preferredEndpoint: URL?) async throws -> AgentRoute {
        .relay(webSocketURL: URL(string: "wss://example.com/ws/input")!)
    }

    func fetchCount() -> Int {
        count
    }
}

// MARK: - URLSession stubbing

private extension URLSession {
    /// An ephemeral session whose only protocol is `StubURLProtocol`, so every request is served from
    /// the test's installed responder and nothing touches the network.
    static func stubbedRouting() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

/// A `URLProtocol` that serves canned responses so `AgentDirectoryService`'s relay-record and `/info`
/// probes can be driven without real networking. Register a responder per test; the suite is
/// `.serialized` so the shared responder is never contended.
final class StubURLProtocol: URLProtocol {
    struct Response {
        var statusCode: Int
        var body: Data
    }

    typealias Responder = @Sendable (URL) -> Result<Response, Error>
    private static let responder = OSAllocatedUnfairLock<Responder?>(initialState: nil)

    static func install(_ responder: @escaping Responder) {
        self.responder.withLock { $0 = responder }
    }

    static func removeAll() {
        responder.withLock { $0 = nil }
    }

    private static func outcome(for url: URL) -> Result<Response, Error> {
        (responder.withLock { $0 })?(url) ?? .failure(URLError(.unsupportedURL))
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url ?? URL(string: "about:blank")!
        switch Self.outcome(for: url) {
        case .success(let response):
            let http = HTTPURLResponse(
                url: url,
                statusCode: response.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response.body)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension Result where Success == StubURLProtocol.Response, Failure == Error {
    /// A 200 response carrying `json` as its body.
    static func ok(_ json: String) -> Result<StubURLProtocol.Response, Error> {
        .success(StubURLProtocol.Response(statusCode: 200, body: Data(json.utf8)))
    }
}
