//
//  KeychainIdentityStore.swift
//
//  Purpose: Implements KeychainIdentityStore for the Core/Crypto module.
//  Collaborates with: ClientIdentity, IdentityProviding, IdentityStoreError, MockIdentityStore, SignedEnvelope.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import CryptoKit
import Foundation

@MainActor
final class KeychainIdentityStore: IdentityProviding {
    private let keychain: KeychainCredentialStoring
    private let account = "ed25519-private-key"

    init(keychain: KeychainCredentialStoring = KeychainCredentialStore()) {
        self.keychain = keychain
    }

    var currentIdentity: ClientIdentity {
        get throws {
            let privateKey = try loadOrCreatePrivateKey()
            return identity(for: privateKey)
        }
    }

    func regenerateIdentity() throws -> ClientIdentity {
        let privateKey = Curve25519.Signing.PrivateKey()
        try keychain.save(privateKey.rawRepresentation, for: account)
        return identity(for: privateKey)
    }

    func sign(payload: [String: JSONValue]) throws -> SignedEnvelope {
        let privateKey = try loadOrCreatePrivateKey()
        let canonical = try payload.jsonData(sortedKeys: true)
        let signature = try privateKey.signature(for: canonical)
        let timestamp = payload[int: "timestamp"] ?? Int(Date.now.timeIntervalSince1970)

        return SignedEnvelope(
            payload: payload,
            from: identity(for: privateKey).address,
            signature: HexCoding.encode(Data(signature)),
            timestamp: timestamp
        )
    }

    private func loadOrCreatePrivateKey() throws -> Curve25519.Signing.PrivateKey {
        if let stored = try keychain.data(for: account) {
            do {
                return try Curve25519.Signing.PrivateKey(rawRepresentation: stored)
            } catch {
                try keychain.delete(account: account)
                throw IdentityStoreError.invalidStoredPrivateKey
            }
        }

        let privateKey = Curve25519.Signing.PrivateKey()
        try keychain.save(privateKey.rawRepresentation, for: account)
        return privateKey
    }

    private func identity(for privateKey: Curve25519.Signing.PrivateKey) -> ClientIdentity {
        let publicKey = privateKey.publicKey.rawRepresentation
        let publicHex = HexCoding.encode(publicKey)
        return ClientIdentity(address: "0x" + publicHex, publicKeyHex: publicHex)
    }
}
