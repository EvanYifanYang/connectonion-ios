//
//  AgentReplyActivityAttributes.swift
//
//  Purpose: Implements AgentReplyActivityAttributes for the ConnectOnionShared module.
//  Collaborates with: ConnectOnionSharedData.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import ActivityKit
import Foundation

struct AgentReplyActivityAttributes: ActivityAttributes {
    var conversationID: String
    var agentAddress: String
    var agentName: String

    struct ContentState: Codable, Hashable {
        var phase: AgentReplyActivityPhase
        var headline: String
        var detail: String
        var toolName: String?
        var startedAt: Date
        var updatedAt: Date

        static func connecting(agentName: String) -> ContentState {
            ContentState(
                phase: .connecting,
                headline: "Contacting \(agentName)",
                detail: "Opening a secure session",
                toolName: nil,
                startedAt: .now,
                updatedAt: .now
            )
        }
    }
}

enum AgentReplyActivityPhase: String, Codable, Hashable {
    case connecting
    case running
    case tool
    case waiting
    case completed
    case failed
    case stopped

    var systemImageName: String {
        switch self {
        case .connecting:
            "antenna.radiowaves.left.and.right"
        case .running:
            "sparkles"
        case .tool:
            "wrench.and.screwdriver"
        case .waiting:
            "person.crop.circle.badge.questionmark"
        case .completed:
            "checkmark.circle"
        case .failed:
            "exclamationmark.triangle"
        case .stopped:
            "stop.circle"
        }
    }
}
