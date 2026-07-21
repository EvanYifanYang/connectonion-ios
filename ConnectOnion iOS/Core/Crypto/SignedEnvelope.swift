//
//  SignedEnvelope.swift
//
//  Purpose: Implements SignedEnvelope for the Core/Crypto module.
//  Collaborates with: ClientIdentity, IdentityProviding, IdentityStoreError, KeychainIdentityStore, MockIdentityStore.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

struct SignedEnvelope: Sendable {
    var payload: [String: JSONValue]
    var from: String
    var signature: String
    var timestamp: Int

    var jsonObject: [String: JSONValue] {
        [
            "payload": .object(payload),
            "from": .string(from),
            "signature": .string(signature),
            "timestamp": .number(Double(timestamp))
        ]
    }
}
