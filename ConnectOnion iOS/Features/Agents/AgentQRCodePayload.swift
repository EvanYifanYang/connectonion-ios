import Foundation

/// The agent connection details encoded in a ConnectOnion QR code.
///
/// Preferred payload — a `connectonion://add` deep link carrying all three add-agent fields:
/// ```
/// connectonion://add?address=0x…&name=OpenOnion&endpoint=http%3A%2F%2F192.168.1.102%3A8000
/// ```
/// `name` and `endpoint` are optional; `endpoint` is the agent's DIRECT endpoint URL (e.g. a LAN
/// address). `name` / `endpoint` values must be percent-encoded.
///
/// Backward-compatible payloads (fill the address only): a bare agent address, or an HTTP(S) URL
/// whose final path component is an agent address (e.g. `https://chat.openonion.ai/0x…`). For those
/// the URL host is discovery context, not a direct endpoint, so no endpoint is filled.
struct AgentQRCodePayload: Equatable, Sendable {
    let address: String
    let name: String?
    let endpoint: URL?

    init?(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let payload = Self.parseAddDeepLink(trimmed)
            ?? Self.parseBareAddress(trimmed)
            ?? Self.parseLegacyHTTPURL(trimmed)
        else {
            return nil
        }
        self = payload
    }

    private init(address: String, name: String?, endpoint: URL?) {
        self.address = address
        self.name = name
        self.endpoint = endpoint
    }

    /// Preferred: `connectonion://add?address=&name=&endpoint=`.
    private static func parseAddDeepLink(_ raw: String) -> AgentQRCodePayload? {
        guard
            let components = URLComponents(string: raw),
            components.scheme?.lowercased() == "connectonion"
        else {
            return nil
        }

        // URLComponents percent-decodes query values for us.
        let items = components.queryItems ?? []
        func query(_ key: String) -> String? {
            items.first { $0.name.lowercased() == key }?.value?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty
        }

        // Accept `?address=` (or `?id=`), falling back to a trailing path segment for flexibility.
        let rawAddress = query("address") ?? query("id")
            ?? components.path.split(separator: "/", omittingEmptySubsequences: true).last.map(String.init)
        guard let rawAddress, let agentAddress = AgentAddress(rawValue: rawAddress) else {
            return nil
        }

        var endpoint: URL?
        if let rawEndpoint = query("endpoint"),
           case .some(let normalized?) = AgentEndpoint.normalized(from: rawEndpoint) {
            endpoint = normalized
        }

        return AgentQRCodePayload(address: agentAddress.rawValue, name: query("name"), endpoint: endpoint)
    }

    private static func parseBareAddress(_ raw: String) -> AgentQRCodePayload? {
        guard let agentAddress = AgentAddress(rawValue: raw) else { return nil }
        return AgentQRCodePayload(address: agentAddress.rawValue, name: nil, endpoint: nil)
    }

    /// Legacy: an HTTP(S) URL whose final path component is an agent address — fills the address only.
    private static func parseLegacyHTTPURL(_ raw: String) -> AgentQRCodePayload? {
        guard
            let components = URLComponents(string: raw),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let host = components.host,
            !host.isEmpty,
            components.user == nil,
            components.password == nil,
            let encodedAddress = components.path
                .split(separator: "/", omittingEmptySubsequences: true)
                .last,
            let decodedAddress = String(encodedAddress).removingPercentEncoding,
            let agentAddress = AgentAddress(rawValue: decodedAddress)
        else {
            return nil
        }
        return AgentQRCodePayload(address: agentAddress.rawValue, name: nil, endpoint: nil)
    }
}
