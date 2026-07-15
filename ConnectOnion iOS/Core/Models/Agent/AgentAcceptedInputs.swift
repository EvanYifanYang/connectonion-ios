import Foundation

struct AgentAcceptedInputs: Codable, Equatable, Hashable, Sendable {
    var text: Bool?
    var images: Bool?
    var files: FilePolicy?
}

extension AgentAcceptedInputs {
    struct FilePolicy: Codable, Equatable, Hashable, Sendable {
        var maxFileSizeMB: Int
        var maxFilesPerRequest: Int

        enum CodingKeys: String, CodingKey {
            case maxFileSizeMB = "max_file_size_mb"
            case maxFilesPerRequest = "max_files_per_request"
        }
    }
}
