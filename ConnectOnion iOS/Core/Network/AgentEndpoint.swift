//
//  AgentEndpoint.swift
//
//  Purpose: Implements AgentEndpoint for the Core/Network module.
//  Collaborates with: the owning feature or module.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

/// Parses a user-entered agent endpoint into a normalized `http(s)` URL. Shared by the add-agent
/// sheet and the edit-agent detail so both accept the same inputs (bare host:port, ws/wss, trailing
/// `/info` or `/ws`).
enum AgentEndpoint {
    /// Returns:
    /// - `.some(url)` for a valid endpoint (scheme normalized to http/https),
    /// - `.some(nil)` for empty input (agent has no configured endpoint),
    /// - `nil` for input that isn't a usable endpoint.
    static func normalized(from raw: String) -> URL?? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .some(nil) }

        let candidate = trimmed.contains("://") ? trimmed : "http://\(trimmed)"
        guard var components = URLComponents(string: candidate), let scheme = components.scheme?.lowercased() else {
            return nil
        }

        switch scheme {
        case "http", "https":
            // Store the lowercased scheme so downstream `scheme == "https"` / `hasPrefix("http")`
            // checks behave for a pasted `HTTPS://…`.
            components.scheme = scheme
        case "ws":
            components.scheme = "http"
        case "wss":
            components.scheme = "https"
        default:
            return nil
        }

        guard components.host != nil else { return nil }

        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path == "info" || path == "ws" {
            components.path = ""
        }
        components.query = nil
        components.fragment = nil

        guard let url = components.url else { return nil }
        return .some(url)
    }
}
