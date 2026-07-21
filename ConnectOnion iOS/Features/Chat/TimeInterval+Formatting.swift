//
//  TimeInterval+Formatting.swift
//
//  Purpose: Implements TimeInterval+Formatting for the Features/Chat module.
//  Collaborates with: ChatErrorBanner, ChatHeaderView, ChatItemView, ChatMessageList, ChatScreen, ChatTimeline.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

extension TimeInterval {
    var formattedDuration: String {
        let seconds = Int(self)
        if seconds < 60 {
            return "\(seconds)s"
        }
        return "\(seconds / 60)m \(seconds % 60)s"
    }
}
