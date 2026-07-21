//
//  IdentityProviding.swift
//
//  Purpose: Implements IdentityProviding for the Core/Crypto module.
//  Collaborates with: ClientIdentity, IdentityStoreError, KeychainIdentityStore, MockIdentityStore, SignedEnvelope.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

@MainActor
protocol IdentityProviding: AnyObject {
    var currentIdentity: ClientIdentity { get throws }
    func regenerateIdentity() throws -> ClientIdentity
    func sign(payload: [String: JSONValue]) throws -> SignedEnvelope
}
