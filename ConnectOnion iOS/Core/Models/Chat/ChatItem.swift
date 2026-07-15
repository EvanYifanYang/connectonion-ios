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
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString

        if let decodedKind = try container.decodeIfPresent(ChatItemKind.self, forKey: .kind) {
            kind = decodedKind
        } else if let type = try container.decodeIfPresent(String.self, forKey: .type),
                  let decodedKind = ChatItemKind(rawValue: type) {
            kind = decodedKind
        } else {
            kind = .agent
        }

        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        let decodedContent = try container.decodeIfPresent(String.self, forKey: .content)
        let decodedAck = try container.decodeIfPresent(String.self, forKey: .ack)
        content = decodedContent ?? decodedAck ?? ""
        images = try container.decodeIfPresent([String].self, forKey: .images) ?? []
        files = try container.decodeIfPresent([FileAttachment].self, forKey: .files) ?? []
        name = try container.decodeIfPresent(String.self, forKey: .name)
        arguments = try container.decodeIfPresent([String: JSONValue].self, forKey: .arguments) ?? [:]
        status = try container.decodeIfPresent(ExecutionStatus.self, forKey: .status)
        result = try container.decodeIfPresent(String.self, forKey: .result)
        timingMS = try container.decodeIfPresent(Int.self, forKey: .timingMS)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        durationMS = try container.decodeIfPresent(Int.self, forKey: .durationMS)
        contextPercent = try container.decodeIfPresent(Double.self, forKey: .contextPercent)
        usage = try container.decodeIfPresent(TokenUsage.self, forKey: .usage)
        options = try container.decodeIfPresent([String].self, forKey: .options) ?? []
        multiSelect = try container.decodeIfPresent(Bool.self, forKey: .multiSelect) ?? false
        inputType = try container.decodeIfPresent(String.self, forKey: .inputType)
        fields = try container.decodeIfPresent([AskUserField].self, forKey: .fields) ?? []
        answered = try container.decodeIfPresent(Bool.self, forKey: .answered) ?? false
        answer = try container.decodeIfPresent(String.self, forKey: .answer)
        tool = try container.decodeIfPresent(String.self, forKey: .tool)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        batchRemaining = try container.decodeIfPresent([BatchApproval].self, forKey: .batchRemaining) ?? []
        methods = try container.decodeIfPresent([String].self, forKey: .methods) ?? []
        let decodedPaymentAmount = try container.decodeIfPresent(Double.self, forKey: .paymentAmount)
        let decodedPaymentAmountSnake = try container.decodeIfPresent(Double.self, forKey: .paymentAmountSnake)
        paymentAmount = decodedPaymentAmount ?? decodedPaymentAmountSnake
        let decodedPaymentAddress = try container.decodeIfPresent(String.self, forKey: .paymentAddress)
        let decodedPaymentAddressSnake = try container.decodeIfPresent(String.self, forKey: .paymentAddressSnake)
        paymentAddress = decodedPaymentAddress ?? decodedPaymentAddressSnake
        level = try container.decodeIfPresent(String.self, forKey: .level)
        ack = try container.decodeIfPresent(String.self, forKey: .ack)
        isBuild = try container.decodeIfPresent(Bool.self, forKey: .isBuild)
        passed = try container.decodeIfPresent(Bool.self, forKey: .passed)
        expected = try container.decodeIfPresent(String.self, forKey: .expected)
        evalPath = try container.decodeIfPresent(String.self, forKey: .evalPath)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        command = try container.decodeIfPresent(String.self, forKey: .command)
        planContent = try container.decodeIfPresent(String.self, forKey: .planContent)
        receivedFiles = try container.decodeIfPresent([ReceivedFile].self, forKey: .receivedFiles) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(kind.rawValue, forKey: .type)
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
    }
}
