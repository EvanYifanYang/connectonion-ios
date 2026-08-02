import Foundation
import Testing
@testable import ConnectOnion_iOS

/// An agent asked for a picture typically answers with a markdown image. `Text` cannot draw one, so
/// without a dedicated block the reply rendered as just the alt text (observed live: a request for an
/// apple photo showed the single word "苹果").
@Suite("Markdown images")
struct MarkdownImageTests {
    @Test("A standalone image line becomes an image block, not alt text")
    func standaloneImageBecomesBlock() {
        let blocks = MarkdownParser.parse("这是一张红苹果的图片：\n\n![苹果](https://example.com/apple.png)")

        #expect(blocks.contains { block in
            guard case .image(let url, let alt) = block else { return false }
            return url.absoluteString == "https://example.com/apple.png" && alt == "苹果"
        })
        #expect(!blocks.contains { block in
            guard case .paragraph(let text) = block else { return false }
            return text.contains("![")
        })
    }

    @Test("An image title and a link-wrapped image still resolve")
    func imageVariantsResolve() {
        let titled = MarkdownParser.parse(#"![a](https://example.com/a.png "Title")"#)
        #expect(titled.contains { if case .image(let url, _) = $0 { url.absoluteString == "https://example.com/a.png" } else { false } })

        let linked = MarkdownParser.parse("[![a](https://example.com/b.png)](https://example.com)")
        #expect(linked.contains { if case .image = $0 { true } else { false } })
    }

    @Test("Non-image bracket syntax is left as a paragraph")
    func plainLinksStayParagraphs() {
        let blocks = MarkdownParser.parse("See [the docs](https://example.com) for more.")
        #expect(blocks.allSatisfy { if case .image = $0 { false } else { true } })
    }

    @Test("A reply containing an image skips the typewriter reveal")
    @MainActor
    func imageRepliesSkipTypewriter() {
        #expect(ChatViewModel.hasBlockMarkdown("Here you go:\n\n![apple](https://example.com/a.png)"))
    }
}

/// Route resolution converts every probe failure into an AgentDirectoryError, so an offline device
/// would otherwise be reported as an unreachable endpoint — blaming the agent for the phone's problem.
@Suite("Offline failure copy")
struct OfflineFailureCopyTests {
    private let endpoint = URL(string: "http://192.168.1.20:8000")!

    @Test("An offline device owns the failure, not the endpoint")
    func offlineDeviceOwnsTheFailure() {
        let failure = ChatFailure(
            error: AgentDirectoryError.preferredEndpointUnavailable(endpoint),
            canResend: false,
            deviceIsOffline: true
        )
        #expect(failure.title == "This iPhone is offline")
    }

    @Test("The same error blames the endpoint when the device has a network path")
    func onlineDeviceBlamesTheEndpoint() {
        let failure = ChatFailure(
            error: AgentDirectoryError.preferredEndpointUnavailable(endpoint),
            canResend: false,
            deviceIsOffline: false
        )
        #expect(failure.title.contains("192.168.1.20:8000"))
    }

    @Test("A user-fixable failure keeps its own copy even offline")
    func userFixableFailuresSurviveOffline() {
        let invalid = ChatFailure(error: AgentDirectoryError.invalidAddress, canResend: false, deviceIsOffline: true)
        #expect(invalid.title.contains("isn't valid"))
        #expect(invalid.action == .dismiss)

        let tooLarge = ChatFailure(
            error: ConnectOnionClientError.inputFrameTooLarge(size: 2_000_000, maxSize: 900_000),
            canResend: false,
            deviceIsOffline: true
        )
        #expect(tooLarge.action == .dismiss)
    }
}
