import Foundation
import OSLog

enum AgentDirectoryError: LocalizedError, Sendable {
    case invalidAddress
    case directoryUnavailable
    case preferredEndpointUnavailable(URL)
    case noReachableRoute([URL])

    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            "This agent address is not valid."
        case .directoryUnavailable:
            "Could not resolve this agent. Check the address and network connection."
        case .preferredEndpointUnavailable(let endpoint):
            "Could not reach the configured endpoint \(endpoint.absoluteString). Check that the agent is running and reachable from this iPhone."
        case .noReachableRoute(let endpoints):
            if endpoints.isEmpty {
                "This agent is online in the directory but has no reachable route for this iPhone."
            } else {
                "This agent only advertises endpoints that are not reachable from this iPhone: \(endpoints.map(\.absoluteString).joined(separator: ", ")). Set a LAN endpoint such as http://<Mac-IP>:8000."
            }
        }
    }
}

struct AgentDirectoryService: AgentDirectoryServicing {
    private let relayURL: URL
    private let session: URLSession
    private let logger = Logger(subsystem: "com.romantcD.ConnectOnion-iOS", category: "AgentDirectory")

    init(relayURL: URL = URL(string: "wss://oo.openonion.ai")!, session: URLSession = .shared) {
        self.relayURL = relayURL
        self.session = session
    }

    func fetchAgentInfo(address: String) async -> AgentInfo {
        guard let relayData = await relayRecord(address: address) else {
            return AgentInfo(address: address, online: false)
        }

        let online = relayData.relay != nil
        var info = AgentInfo(address: address, online: online).merged(with: relayData.profile)

        for endpoint in usableHTTPEndpoints(relayData.endpoints) {
            if let direct = await directInfo(endpoint: endpoint, address: address) {
                info = info.merged(with: direct)
                info.online = true
                return info
            }
        }

        return info
    }

    func resolveRoute(for address: String, preferredEndpoint: URL?) async throws -> AgentRoute {
        if let preferredEndpoint,
           isUsableFromCurrentDevice(preferredEndpoint) {
            if let direct = await verifiedDirectRoute(httpURL: preferredEndpoint, address: address) {
                logger.info("Using preferred direct endpoint \(preferredEndpoint.absoluteString, privacy: .public)")
                return direct
            }
            logger.error("Preferred endpoint unavailable: \(preferredEndpoint.absoluteString, privacy: .public)")
            throw AgentDirectoryError.preferredEndpointUnavailable(preferredEndpoint)
        }

        guard AgentAddress.isValid(address) else { throw AgentDirectoryError.invalidAddress }
        guard let relayData = await relayRecord(address: address) else { throw AgentDirectoryError.directoryUnavailable }

        let relaySummary = relayData.relay ?? "nil"
        let endpointSummary = relayData.endpoints.map(\.absoluteString).joined(separator: ",")
        logger.info("Relay record relay=\(relaySummary, privacy: .public), endpoints=\(endpointSummary, privacy: .public)")

        for endpoint in usableHTTPEndpoints(relayData.endpoints) {
            if let direct = await verifiedDirectRoute(httpURL: endpoint, address: address) {
                logger.info("Using direct endpoint \(endpoint.absoluteString, privacy: .public)")
                return direct
            }
        }

        if relayData.relay != nil {
            logger.info("Using relay route")
            return relayRoute()
        }

        logger.error("No reachable route for iPhone. Advertised endpoints: \(endpointSummary, privacy: .public)")
        throw AgentDirectoryError.noReachableRoute(relayData.endpoints)
    }

    private func relayRecord(address: String) async -> RelayAgentRecord? {
        let relay = relayURL.normalizedRelayHTTPURL()
        let url = relay.appending(path: "api/relay/agents/\(address)")
        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        do {
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(RelayAgentRecord.self, from: data)
        } catch {
            return nil
        }
    }

    private func directInfo(endpoint: URL, address: String) async -> AgentInfo? {
        let url = endpoint.appending(path: "info")
        var request = URLRequest(url: url)
        request.timeoutInterval = 3

        do {
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let info = try JSONDecoder().decode(DirectAgentInfo.self, from: data)
            guard info.address == address else { return nil }
            return AgentInfo(address: address, online: true).merged(with: info.profile)
        } catch {
            return nil
        }
    }

    private func verifiedDirectRoute(httpURL: URL, address: String) async -> AgentRoute? {
        guard await directInfo(endpoint: httpURL, address: address) != nil else { return nil }
        guard let webSocketURL = httpURL.webSocketURL(path: "ws") else { return nil }
        return .direct(httpURL: httpURL, webSocketURL: webSocketURL)
    }

    private func relayRoute() -> AgentRoute {
        let normalized = relayURL.normalizedRelayWebSocketURL()
        return .relay(webSocketURL: normalized.appending(path: "ws/input"))
    }

    private func sortedByProximity(_ endpoints: [URL]) -> [URL] {
        endpoints.sorted { lhs, rhs in
            priority(lhs) < priority(rhs)
        }
    }

    private func usableHTTPEndpoints(_ endpoints: [URL]) -> [URL] {
        sortedByProximity(endpoints).filter { endpoint in
            endpoint.scheme?.hasPrefix("http") == true && isUsableFromCurrentDevice(endpoint)
        }
    }

    private func isUsableFromCurrentDevice(_ endpoint: URL) -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        let host = endpoint.host(percentEncoded: false)?.lowercased() ?? ""
        return host != "localhost" && host != "127.0.0.1" && host != "::1"
        #endif
    }

    private func priority(_ url: URL) -> Int {
        let host = url.host(percentEncoded: false)?.lowercased() ?? ""
        if host == "localhost" || host == "127.0.0.1" || host == "::1" { return 0 }
        if host.hasPrefix("192.168.") || host.hasPrefix("10.") || host.hasPrefix("172.16.") { return 1 }
        return 2
    }
}

private extension URL {
    func normalizedRelayHTTPURL() -> URL {
        var absolute = absoluteString
            .replacing(/^wss?:\/\//, with: "https://")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if absolute.hasSuffix("/ws/announce") {
            absolute.removeLast("/ws/announce".count)
        } else if absolute.hasSuffix("/ws") {
            absolute.removeLast("/ws".count)
        }

        return URL(string: absolute)!
    }

    func normalizedRelayWebSocketURL() -> URL {
        var absolute = absoluteString
            .replacing(/^https?:\/\//, with: "wss://")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if absolute.hasSuffix("/ws/announce") {
            absolute.removeLast("/ws/announce".count)
        } else if absolute.hasSuffix("/ws") {
            absolute.removeLast("/ws".count)
        }

        return URL(string: absolute)!
    }

    func webSocketURL(path: String) -> URL? {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.scheme = scheme == "https" ? "wss" : "ws"
        let currentPath = components?.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
        components?.path = currentPath.isEmpty ? "/\(path)" : "/\(currentPath)/\(path)"
        return components?.url
    }
}
