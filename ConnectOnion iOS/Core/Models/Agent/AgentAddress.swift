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
