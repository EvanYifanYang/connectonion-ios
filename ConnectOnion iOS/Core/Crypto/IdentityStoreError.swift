//
//  IdentityStoreError.swift
//
//  Purpose: Implements IdentityStoreError for the Core/Crypto module.
//  Collaborates with: ClientIdentity, IdentityProviding, KeychainIdentityStore, MockIdentityStore, SignedEnvelope.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

enum IdentityStoreError: LocalizedError {
    case invalidStoredPrivateKey
    case signingFailed

    var errorDescription: String? {
        switch self {
        case .invalidStoredPrivateKey:
            "The stored ConnectOnion identity is invalid."
        case .signingFailed:
            "Unable to sign the ConnectOnion request."
        }
    }
}
