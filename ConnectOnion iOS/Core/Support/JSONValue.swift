//
//  JSONValue.swift
//
//  Purpose: Implements JSONValue for the Core/Support module.
//  Collaborates with: AccessibilityID, AgentContentSanitizer, AttachmentEncoding, CustomInstructions, HexCoding, PersonalisationPreferences.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

enum JSONValue: Codable, Equatable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .number(Double(value))
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

extension JSONValue {
    var stringValue: String? {
        if case .string(let value) = self { value } else { nil }
    }

    var intValue: Int? {
        if case .number(let value) = self { Int(value) } else { nil }
    }

    var doubleValue: Double? {
        if case .number(let value) = self { value } else { nil }
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { value } else { nil }
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { value } else { nil }
    }

    var arrayValue: [JSONValue]? {
        if case .array(let value) = self { value } else { nil }
    }

    var foundationObject: Any {
        switch self {
        case .string(let value):
            value
        case .number(let value):
            value.rounded() == value ? Int(value) : value
        case .bool(let value):
            value
        case .object(let value):
            value.mapValues(\.foundationObject)
        case .array(let value):
            value.map(\.foundationObject)
        case .null:
            NSNull()
        }
    }
}

extension [String: JSONValue] {
    subscript(string key: String) -> String? {
        self[key]?.stringValue
    }

    subscript(int key: String) -> Int? {
        self[key]?.intValue
    }

    subscript(double key: String) -> Double? {
        self[key]?.doubleValue
    }

    subscript(bool key: String) -> Bool? {
        self[key]?.boolValue
    }

    func jsonData(sortedKeys: Bool = false) throws -> Data {
        let options: JSONSerialization.WritingOptions = sortedKeys ? [.sortedKeys] : []
        return try JSONSerialization.data(withJSONObject: mapValues(\.foundationObject), options: options)
    }

    func jsonString(sortedKeys: Bool = false) throws -> String {
        let data = try jsonData(sortedKeys: sortedKeys)
        guard let string = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(data, .init(codingPath: [], debugDescription: "JSON data is not UTF-8"))
        }
        return string
    }
}
