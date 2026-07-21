//
//  AgentAddress.swift
//
//  Purpose: Implements AgentAddress for the Core/Models/Agent module.
//  Collaborates with: AgentAcceptedInputs, AgentConfig, AgentInfo+Merging, AgentInfo, SkillInfo.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

struct AgentAddress: RawRepresentable, Codable, Hashable, Identifiable, Sendable {
    let rawValue: String

    var id: String { rawValue }

    init?(rawValue: String) {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard Self.isValid(normalized) else { return nil }
        self.rawValue = normalized
    }

    static func isValid(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.hasPrefix("0x"), normalized.count == 66 else { return false }
        return normalized.dropFirst(2).allSatisfy(\.isHexDigit)
    }

    var shortDisplay: String {
        "\(rawValue.prefix(8))...\(rawValue.suffix(4))"
    }
}
