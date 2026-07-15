import Foundation

struct TokenUsage: Codable, Equatable, Hashable, Sendable {
    var inputTokens: Int?
    var outputTokens: Int?
    var promptTokens: Int?
    var completionTokens: Int?
    var totalTokens: Int?
    var cost: Double?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
        case cost
    }
}
