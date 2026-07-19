import Foundation
import Testing
@testable import ConnectOnion_iOS

@Suite("Agent QR code payload")
struct AgentQRCodePayloadTests {
    private let address = "0xf5ff043a9c5df95eac9387908dea87beb7b59c2a3b04787e3222fdf8209cdee1"

    @Test func decodesSampleAgentURL() throws {
        let payload = try #require(
            AgentQRCodePayload(rawValue: "https://chat.openonion.ai/\(address)")
        )

        #expect(payload.address == address)
        #expect(payload.endpoint == URL(string: "https://chat.openonion.ai"))
    }

    @Test func decodesAndNormalizesBareAddress() throws {
        let payload = try #require(
            AgentQRCodePayload(rawValue: "  \(address.uppercased())  ")
        )

        #expect(payload.address == address)
        #expect(payload.endpoint == nil)
    }

    @Test(
        arguments: [
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
