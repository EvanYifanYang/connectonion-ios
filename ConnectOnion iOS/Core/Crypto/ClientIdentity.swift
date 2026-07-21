//
//  ClientIdentity.swift
//
//  Purpose: Implements ClientIdentity for the Core/Crypto module.
//  Collaborates with: IdentityProviding, IdentityStoreError, KeychainIdentityStore, MockIdentityStore, SignedEnvelope.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

struct ClientIdentity: Codable, Equatable, Sendable {
    var address: String
    var publicKeyHex: String

    var shortAddress: String {
        AgentAddress(rawValue: address)?.shortDisplay ?? address
    }
}
