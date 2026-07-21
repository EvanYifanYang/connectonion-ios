//
//  HexCoding.swift
//
//  Purpose: Implements HexCoding for the Core/Support module.
//  Collaborates with: AccessibilityID, AgentContentSanitizer, AttachmentEncoding, CustomInstructions, JSONValue, PersonalisationPreferences.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

enum HexCoding {
    static func encode(_ data: Data, prefixed: Bool = false) -> String {
        let body = data.map { String(format: "%02x", $0) }.joined()
        return prefixed ? "0x" + body : body
    }

    static func decode(_ hex: String) -> Data? {
        let trimmed = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        guard trimmed.count.isMultiple(of: 2) else { return nil }

        var data = Data()
        data.reserveCapacity(trimmed.count / 2)

        var index = trimmed.startIndex
        while index < trimmed.endIndex {
            let next = trimmed.index(index, offsetBy: 2)
            guard let byte = UInt8(trimmed[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }

        return data
    }
}
