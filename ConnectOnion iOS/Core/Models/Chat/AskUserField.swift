import Foundation

struct AskUserField: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: String { name }
    var name: String
    var label: String
    var type: FieldType?
    var placeholder: String?
    var required: Bool?
    var autocomplete: String?
}

extension AskUserField {
    enum FieldType: String, Codable, Sendable {
        case text
        case password
    }
}
