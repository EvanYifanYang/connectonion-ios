//
//  ConnectOnionSharedData.swift
//
//  Purpose: Implements ConnectOnionSharedData for the ConnectOnionShared module.
//  Collaborates with: AgentReplyActivityAttributes.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

enum ConnectOnionAppGroup {
    static let identifier = "group.com.romantcD.ConnectOnion-iOS"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

struct ConnectOnionAgentShortcut: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: String { address }
    var address: String
    var displayName: String
    var subtitle: String
    var lastUsedAt: Date
    var suggestions: [String]
}

struct ConnectOnionWidgetSnapshot: Codable, Equatable, Sendable {
    var updatedAt: Date
    var agents: [ConnectOnionAgentShortcut]

    static let empty = ConnectOnionWidgetSnapshot(updatedAt: .distantPast, agents: [])

    static let placeholder = ConnectOnionWidgetSnapshot(
        updatedAt: .now,
        agents: [
            ConnectOnionAgentShortcut(
                address: "0xagent",
                displayName: "OpenOnion",
                subtitle: "Last used just now",
                lastUsedAt: .now,
                suggestions: ConnectOnionSharedSuggestions.defaults
            )
        ]
    )
}

enum ConnectOnionWidgetSnapshotStore {
    private static let snapshotKey = "connectonion.widget.snapshot"

    static func load() -> ConnectOnionWidgetSnapshot {
        guard let data = ConnectOnionAppGroup.defaults.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(ConnectOnionWidgetSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    static func save(_ snapshot: ConnectOnionWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        ConnectOnionAppGroup.defaults.set(data, forKey: snapshotKey)
    }
}

enum ConnectOnionSharedSuggestions {
    static let defaults = [
        "What can you do?",
        "Summarize the latest state",
        "Help me debug this",
        "Plan the next step"
    ]
}

enum ConnectOnionDeepLink {
    static let scheme = "connectonion"
    static let newChatHost = "new-chat"
    static let conversationHost = "conversation"
    static let scanAgentHost = "scan-agent"

    static func newChat(agentAddress: String, suggestion: String? = nil) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = newChatHost
        components.queryItems = [
            URLQueryItem(name: "agent", value: agentAddress)
        ]

        if let suggestion, !suggestion.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "suggestion", value: suggestion))
        }

        return components.url ?? URL(string: "\(scheme)://\(newChatHost)")!
    }

    static func conversation(id: String) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = conversationHost
        components.queryItems = [
            URLQueryItem(name: "id", value: id)
        ]
        return components.url ?? URL(string: "\(scheme)://\(conversationHost)")!
    }

    static func scanAgent() -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = scanAgentHost
        return components.url ?? URL(string: "\(scheme)://\(scanAgentHost)")!
    }

    static func parse(_ url: URL) -> Request? {
        guard url.scheme == scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let queryItems = components.queryItems ?? []

        if url.host == scanAgentHost {
            return Request(
                agentAddress: nil,
                suggestion: nil,
                conversationID: nil,
                opensAgentScanner: true
            )
        }

        if url.host == conversationHost {
            return Request(
                agentAddress: nil,
                suggestion: nil,
                conversationID: queryItems.first { $0.name == "id" }?.value,
                opensAgentScanner: false
            )
        }

        guard url.host == newChatHost else { return nil }
        let agentAddress = queryItems.first { $0.name == "agent" }?.value
        let suggestion = queryItems.first { $0.name == "suggestion" }?.value

        return Request(
            agentAddress: agentAddress,
            suggestion: suggestion,
            conversationID: nil,
            opensAgentScanner: false
        )
    }

    struct Request: Equatable, Sendable {
        var agentAddress: String?
        var suggestion: String?
        var conversationID: String?
        var opensAgentScanner: Bool
    }
}
