//
//  String+NilIfEmpty.swift
//
//  Purpose: Implements String+NilIfEmpty for the Core/Support module.
//  Collaborates with: AccessibilityID, AgentContentSanitizer, AttachmentEncoding, CustomInstructions, HexCoding, JSONValue.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
