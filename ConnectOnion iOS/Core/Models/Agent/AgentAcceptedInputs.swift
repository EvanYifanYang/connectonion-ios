//
//  AgentAcceptedInputs.swift
//
//  Purpose: Implements AgentAcceptedInputs for the Core/Models/Agent module.
//  Collaborates with: AgentAddress, AgentConfig, AgentInfo+Merging, AgentInfo, SkillInfo.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
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
