//
//  AgentQRCodePayloadTests.swift
//
//  Purpose: Implements AgentQRCodePayloadTests for the ConnectOnion iOSTests module.
//  Collaborates with: AgentRoutingTests, ChatSessionStoreTests, CustomInstructionsTests, PersonalisationPreferencesTests, Sprint1Tests, Sprint2Tests.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation
import Testing
@testable import ConnectOnion_iOS

@Suite("Agent QR code payload")
struct AgentQRCodePayloadTests {
    private let address = "0xf5ff043a9c5df95eac9387908dea87beb7b59c2a3b04787e3222fdf8209cdee1"

    @Test func decodesAddDeepLinkWithAllThreeFields() throws {
        let payload = try #require(
            AgentQRCodePayload(rawValue:
                "connectonion://add?address=\(address)&name=OpenOnion&endpoint=http%3A%2F%2F192.168.1.102%3A8000"
            )
        )

        #expect(payload.address == address)
        #expect(payload.name == "OpenOnion")
        #expect(payload.endpoint == URL(string: "http://192.168.1.102:8000"))
    }

    @Test func decodesAddDeepLinkWithEncodedNameAndNoEndpoint() throws {
        let payload = try #require(
            AgentQRCodePayload(rawValue: "connectonion://add?address=\(address)&name=Weather%20Bot")
        )

        #expect(payload.address == address)
        #expect(payload.name == "Weather Bot")
        #expect(payload.endpoint == nil)
    }

    @Test func addDeepLinkAcceptsIdAliasAndTrailingPathAddress() throws {
        let viaId = try #require(AgentQRCodePayload(rawValue: "connectonion://add?id=\(address)"))
        #expect(viaId.address == address)

        let viaPath = try #require(AgentQRCodePayload(rawValue: "connectonion://add/\(address)"))
        #expect(viaPath.address == address)
    }

    @Test func decodesAndNormalizesBareAddress() throws {
        let payload = try #require(
            AgentQRCodePayload(rawValue: "  \(address.uppercased())  ")
        )

        #expect(payload.address == address)
        #expect(payload.name == nil)
        #expect(payload.endpoint == nil)
    }

    @Test func legacyHostedURLFillsAddressOnly() throws {
        // The hosted URL's host is discovery context, so only the address is taken (no direct endpoint).
        let payload = try #require(
            AgentQRCodePayload(rawValue: "https://chat.openonion.ai/\(address)")
        )

        #expect(payload.address == address)
        #expect(payload.name == nil)
        #expect(payload.endpoint == nil)
    }

    @Test(
        arguments: [
            "connectonion://add?name=OpenOnion",   // missing address
            "connectonion://add?address=0x1234",   // malformed address
            "ftp://chat.openonion.ai/0xf5ff043a9c5df95eac9387908dea87beb7b59c2a3b04787e3222fdf8209cdee1",
            "https://user:password@chat.openonion.ai/0xf5ff043a9c5df95eac9387908dea87beb7b59c2a3b04787e3222fdf8209cdee1",
            "https:///0xf5ff043a9c5df95eac9387908dea87beb7b59c2a3b04787e3222fdf8209cdee1",
            "https://chat.openonion.ai/0x1234",
            "https://chat.openonion.ai/not-an-address"
        ]
    )
    func rejectsUnsupportedOrMalformedPayload(_ rawValue: String) {
        #expect(AgentQRCodePayload(rawValue: rawValue) == nil)
    }
}
