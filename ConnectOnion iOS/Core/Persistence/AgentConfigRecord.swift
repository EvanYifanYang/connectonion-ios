import Foundation
import SwiftData

@Model
final class AgentConfigRecord {
    var address: String
    var alias: String
    var preferredEndpoint: URL?
    var createdAt: Date
    var updatedAt: Date
    var lastConnectedAt: Date?
    var cachedInfoData: Data?
    /// Set when the user pins this agent to the top of the list (most recent pin sorts first).
    var pinnedAt: Date?

    init(
        address: String,
        alias: String = "",
        preferredEndpoint: URL? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        lastConnectedAt: Date? = nil,
        cachedInfoData: Data? = nil
    ) {
        self.address = address
        self.alias = alias
        self.preferredEndpoint = preferredEndpoint
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastConnectedAt = lastConnectedAt
        self.cachedInfoData = cachedInfoData
    }
}

extension AgentConfigRecord {
    var config: AgentConfig {
        AgentConfig(
            address: address,
            alias: alias,
            preferredEndpoint: preferredEndpoint,
            createdAt: createdAt,
            lastConnectedAt: lastConnectedAt
        )
    }

    var cachedInfo: AgentInfo? {
        get {
            guard let cachedInfoData else { return nil }
            return try? JSONDecoder().decode(AgentInfo.self, from: cachedInfoData)
        }
        set {
            cachedInfoData = try? JSONEncoder().encode(newValue)
            updatedAt = .now
        }
    }

    var displayName: String {
        displayName(info: cachedInfo)
    }

    func displayName(info: AgentInfo?) -> String {
        let trimmedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAlias.isEmpty {
            return trimmedAlias
        } else {
            return info?.name ?? AgentAddress(rawValue: address)?.shortDisplay ?? address
        }
    }

    func remoteProfileName(info: AgentInfo?) -> String? {
        let localAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !localAlias.isEmpty else { return nil }

        guard let profileName = info?.name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !profileName.isEmpty,
              profileName.localizedCaseInsensitiveCompare(localAlias) != .orderedSame else {
            return nil
        }

        return profileName
    }
}
