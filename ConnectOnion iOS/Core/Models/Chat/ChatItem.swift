//
//  ChatItem.swift
//
//  Purpose: Implements ChatItem for the Core/Models/Chat module.
//  Collaborates with: ApprovalMode, AskUserField, BatchApproval, ChatItemKind, ConversationSession, ExecutionStatus.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

struct ChatItem: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var kind: ChatItemKind
    var createdAt: Date
    var content: String
    var images: [String]
    var files: [FileAttachment]
    var name: String?
    var arguments: [String: JSONValue]
    var status: ExecutionStatus?
    var result: String?
    var timingMS: Int?
    var model: String?
    var durationMS: Int?
    var contextPercent: Double?
    var usage: TokenUsage?
    var options: [String]
    var multiSelect: Bool
    var inputType: String?
    var fields: [AskUserField]
    var answered: Bool
    var answer: String?
    var tool: String?
    var description: String?
    var batchRemaining: [BatchApproval]
    var methods: [String]
    var paymentAmount: Double?
    var paymentAddress: String?
    var level: String?
    var ack: String?
    var isBuild: Bool?
    var passed: Bool?
    var expected: String?
    var evalPath: String?
    var reason: String?
    var command: String?
    var planContent: String?
    var receivedFiles: [ReceivedFile]
    var turnsUsed: Int?
    var maxTurns: Int?
    var eventType: String?
    var rawPayload: [String: JSONValue]

    init(
        id: String = UUID().uuidString,
        kind: ChatItemKind,
        createdAt: Date = .now,
        content: String = ""
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.content = content
        images = []
        files = []
        arguments = [:]
        options = []
        multiSelect = false
        fields = []
        answered = false
        batchRemaining = []
        methods = []
        receivedFiles = []
        rawPayload = [:]
    }
}

extension ChatItem {
    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case type
        case createdAt
        case content
        case images
        case files
        case name
        case arguments
        case status
        case result
        case timingMS = "timing_ms"
        case model
        case durationMS = "duration_ms"
        case contextPercent = "context_percent"
        case usage
        case options
        case multiSelect = "multi_select"
        case inputType = "input_type"
        case fields
        case answered
        case answer
        case tool
        case description
        case batchRemaining = "batch_remaining"
        case methods
        case paymentAmount = "paymentAmount"
        case paymentAmountSnake = "payment_amount"
        case paymentAddress = "paymentAddress"
        case paymentAddressSnake = "payment_address"
        case level
        case ack
        case isBuild = "is_build"
        case passed
        case expected
        case evalPath = "eval_path"
        case reason
        case command
        case planContent = "plan_content"
        case receivedFiles = "received_files"
        case turnsUsed = "turns_used"
        case maxTurns = "max_turns"
        case eventType = "event_type"
        case rawPayload = "raw_payload"
        case args
        case image
        case message
        case text
        case question
        case summary
        case error
        case createdAtSnake = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeLossy(String.self, forKey: .id) ?? UUID().uuidString

        let kindValue = container.decodeLossy(String.self, forKey: .kind)
        let typeValue = container.decodeLossy(String.self, forKey: .type)
        let rawKind = kindValue.flatMap(ChatItemKind.init(rawValue:)) != nil ? kindValue : typeValue ?? kindValue
        kind = rawKind.flatMap(ChatItemKind.init(rawValue:)) ?? .unknown
        eventType = container.decodeLossy(String.self, forKey: .eventType)
        if eventType == nil, kind == .unknown {
            eventType = typeValue ?? kindValue
        }

        createdAt = container.decodeLossy(Date.self, forKey: .createdAt)
            ?? container.decodeServerDate(forKey: .createdAtSnake)
            ?? .now
        let decodedContent = container.decodeLossy(String.self, forKey: .content)
        let decodedAck = container.decodeLossy(String.self, forKey: .ack)
        content = decodedContent
            ?? decodedAck
            ?? container.decodeLossy(String.self, forKey: .message)
            ?? container.decodeLossy(String.self, forKey: .text)
            ?? container.decodeLossy(String.self, forKey: .question)
            ?? container.decodeLossy(String.self, forKey: .summary)
            ?? container.decodeLossy(String.self, forKey: .error)
            ?? ""
        images = container.decodeLossy([String].self, forKey: .images) ?? []
        if let image = container.decodeLossy(String.self, forKey: .image), !images.contains(image) {
            images.append(image)
        }
        files = container.decodeLossy([FileAttachment].self, forKey: .files) ?? []
        name = container.decodeLossy(String.self, forKey: .name)
        arguments = container.decodeLossy([String: JSONValue].self, forKey: .arguments)
            ?? container.decodeLossy([String: JSONValue].self, forKey: .args)
            ?? [:]
        status = container.decodeLossy(String.self, forKey: .status).flatMap(ExecutionStatus.init(rawValue:))
        result = container.decodeLossy(String.self, forKey: .result)
        timingMS = container.decodeLossy(Int.self, forKey: .timingMS)
        model = container.decodeLossy(String.self, forKey: .model)
        durationMS = container.decodeLossy(Int.self, forKey: .durationMS)
        contextPercent = container.decodeLossy(Double.self, forKey: .contextPercent)
        usage = container.decodeLossy(TokenUsage.self, forKey: .usage)
        options = container.decodeLossy([String].self, forKey: .options) ?? []
        multiSelect = container.decodeLossy(Bool.self, forKey: .multiSelect) ?? false
        inputType = container.decodeLossy(String.self, forKey: .inputType)
        fields = container.decodeLossy([AskUserField].self, forKey: .fields) ?? []
        answered = container.decodeLossy(Bool.self, forKey: .answered) ?? false
        answer = container.decodeLossy(String.self, forKey: .answer)
        tool = container.decodeLossy(String.self, forKey: .tool)
        description = container.decodeLossy(String.self, forKey: .description)
        batchRemaining = container.decodeLossy([BatchApproval].self, forKey: .batchRemaining) ?? []
        methods = container.decodeLossy([String].self, forKey: .methods) ?? []
        let decodedPaymentAmount = container.decodeLossy(Double.self, forKey: .paymentAmount)
        let decodedPaymentAmountSnake = container.decodeLossy(Double.self, forKey: .paymentAmountSnake)
        paymentAmount = decodedPaymentAmount ?? decodedPaymentAmountSnake
        let decodedPaymentAddress = container.decodeLossy(String.self, forKey: .paymentAddress)
        let decodedPaymentAddressSnake = container.decodeLossy(String.self, forKey: .paymentAddressSnake)
        paymentAddress = decodedPaymentAddress ?? decodedPaymentAddressSnake
        level = container.decodeLossy(String.self, forKey: .level)
        ack = container.decodeLossy(String.self, forKey: .ack)
        isBuild = container.decodeLossy(Bool.self, forKey: .isBuild)
        passed = container.decodeLossy(Bool.self, forKey: .passed)
        expected = container.decodeLossy(String.self, forKey: .expected)
        evalPath = container.decodeLossy(String.self, forKey: .evalPath)
        reason = container.decodeLossy(String.self, forKey: .reason)
        command = container.decodeLossy(String.self, forKey: .command)
        planContent = container.decodeLossy(String.self, forKey: .planContent)
        receivedFiles = container.decodeLossy([ReceivedFile].self, forKey: .receivedFiles) ?? []
        turnsUsed = container.decodeLossy(Int.self, forKey: .turnsUsed)
        maxTurns = container.decodeLossy(Int.self, forKey: .maxTurns)
        rawPayload = container.decodeLossy([String: JSONValue].self, forKey: .rawPayload) ?? [:]
        if rawPayload.isEmpty, kind == .unknown {
            rawPayload = Self.decodeRawPayload(from: decoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(eventType ?? kind.rawValue, forKey: .type)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(content, forKey: .content)
        try container.encode(images, forKey: .images)
        try container.encode(files, forKey: .files)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encode(arguments, forKey: .arguments)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(result, forKey: .result)
        try container.encodeIfPresent(timingMS, forKey: .timingMS)
        try container.encodeIfPresent(model, forKey: .model)
        try container.encodeIfPresent(durationMS, forKey: .durationMS)
        try container.encodeIfPresent(contextPercent, forKey: .contextPercent)
        try container.encodeIfPresent(usage, forKey: .usage)
        try container.encode(options, forKey: .options)
        try container.encode(multiSelect, forKey: .multiSelect)
        try container.encodeIfPresent(inputType, forKey: .inputType)
        try container.encode(fields, forKey: .fields)
        try container.encode(answered, forKey: .answered)
        try container.encodeIfPresent(answer, forKey: .answer)
        try container.encodeIfPresent(tool, forKey: .tool)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(batchRemaining, forKey: .batchRemaining)
        try container.encode(methods, forKey: .methods)
        try container.encodeIfPresent(paymentAmount, forKey: .paymentAmount)
        try container.encodeIfPresent(paymentAddress, forKey: .paymentAddress)
        try container.encodeIfPresent(level, forKey: .level)
        try container.encodeIfPresent(ack, forKey: .ack)
        try container.encodeIfPresent(isBuild, forKey: .isBuild)
        try container.encodeIfPresent(passed, forKey: .passed)
        try container.encodeIfPresent(expected, forKey: .expected)
        try container.encodeIfPresent(evalPath, forKey: .evalPath)
        try container.encodeIfPresent(reason, forKey: .reason)
        try container.encodeIfPresent(command, forKey: .command)
        try container.encodeIfPresent(planContent, forKey: .planContent)
        try container.encode(receivedFiles, forKey: .receivedFiles)
        try container.encodeIfPresent(turnsUsed, forKey: .turnsUsed)
        try container.encodeIfPresent(maxTurns, forKey: .maxTurns)
        try container.encodeIfPresent(eventType, forKey: .eventType)
        if !rawPayload.isEmpty {
            try container.encode(rawPayload, forKey: .rawPayload)
        }
    }

    private static func decodeRawPayload(from decoder: Decoder) -> [String: JSONValue] {
        guard let container = try? decoder.container(keyedBy: DynamicCodingKey.self) else { return [:] }
        return container.allKeys.reduce(into: [:]) { result, key in
            if let value = try? container.decode(JSONValue.self, forKey: key) {
                result[key.stringValue] = value
            }
        }
    }
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

private extension KeyedDecodingContainer {
    func decodeLossy<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        guard contains(key) else { return nil }
        return try? decode(T.self, forKey: key)
    }

    func decodeServerDate(forKey key: Key) -> Date? {
        if let timestamp = decodeLossy(Double.self, forKey: key) {
            return Date(timeIntervalSince1970: timestamp)
        }
        guard let value = decodeLossy(String.self, forKey: key) else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }
}
