import Foundation

/// The agent connection details encoded in a ConnectOnion QR code.
///
/// Supported payloads are either a bare agent address or an HTTP(S) URL whose final path
/// component is an agent address, for example:
/// `https://chat.openonion.ai/0x…`
struct AgentQRCodePayload: Equatable, Sendable {
    let address: String
    let endpoint: URL?

    init?(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if let agentAddress = AgentAddress(rawValue: trimmed) {
            address = agentAddress.rawValue
            endpoint = nil
            return
        }

        guard
            let components = URLComponents(string: trimmed),
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

        var endpointComponents = URLComponents()
        endpointComponents.scheme = scheme
        endpointComponents.host = host
        endpointComponents.port = components.port

        guard let endpointURL = endpointComponents.url else { return nil }

        address = agentAddress.rawValue
        endpoint = endpointURL
    }
}
