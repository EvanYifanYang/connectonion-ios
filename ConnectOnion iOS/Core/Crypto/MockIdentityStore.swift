//
//  MockIdentityStore.swift
//
//  Purpose: Implements MockIdentityStore for the Core/Crypto module.
//  Collaborates with: ClientIdentity, IdentityProviding, IdentityStoreError, KeychainIdentityStore, SignedEnvelope.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import CryptoKit
import Foundation

@MainActor
final class MockIdentityStore: IdentityProviding {
    private var privateKey: Curve25519.Signing.PrivateKey

    init(seed: Data = Data(repeating: 7, count: 32)) {
        do {
            privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
        } catch {
            fatalError("Mock identity seed must be 32 bytes.")
        }
    }

    var currentIdentity: ClientIdentity {
        get throws { identity(for: privateKey) }
    }

    func regenerateIdentity() throws -> ClientIdentity {
        privateKey = Curve25519.Signing.PrivateKey()
        return identity(for: privateKey)
    }

    func sign(payload: [String: JSONValue]) throws -> SignedEnvelope {
        let data = try payload.jsonData(sortedKeys: true)
        let signature = try privateKey.signature(for: data)
        return SignedEnvelope(
            payload: payload,
            from: identity(for: privateKey).address,
            signature: HexCoding.encode(Data(signature)),
            timestamp: payload[int: "timestamp"] ?? Int(Date.now.timeIntervalSince1970)
        )
    }

    private func identity(for privateKey: Curve25519.Signing.PrivateKey) -> ClientIdentity {
        let publicKey = privateKey.publicKey.rawRepresentation
        let publicHex = HexCoding.encode(publicKey)
        return ClientIdentity(address: "0x" + publicHex, publicKeyHex: publicHex)
    }
}
