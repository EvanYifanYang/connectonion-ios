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
