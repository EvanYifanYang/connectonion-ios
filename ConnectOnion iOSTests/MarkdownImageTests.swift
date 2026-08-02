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


/// A pre-CONNECTED ERROR frame is free text, so "the agent isn't running" and "the agent rejected
/// you" arrive as the same case. Observed live: a stopped agent produced "Agent not connected: 0x…"
/// and the app told the user to check trust settings, with no Retry.
@Suite("Rejected vs absent agent")
struct RejectionCopyTests {
    @Test("A relay saying the agent isn't connected offers Retry, not trust advice")
    func absentAgentIsRetryable() {
        let failure = ChatFailure(
            error: ConnectOnionClientError.connectionRejected("Agent not connected: 0x5513e629e0"),
            canResend: false
        )
        #expect(failure.title == "That agent isn't online")
        #expect(failure.action == .reconnect)
        #expect(failure.body.contains("Start the agent"))
    }

    @Test("A genuine trust rejection keeps its advice and offers no retry")
    func trustRejectionIsTerminal() {
        let failure = ChatFailure(
            error: ConnectOnionClientError.connectionRejected("Invalid signature"),
            canResend: false
        )
        #expect(failure.title.contains("refused"))
        #expect(failure.action == .dismiss)
        #expect(failure.detail == "Invalid signature")
    }
}

/// Observed on device: with airplane mode on, the agent home still read "Online". The offline
/// override had only been applied to the agent-list row, not to the other status surfaces.
@Suite("Offline status phase")
struct OfflineStatusPhaseTests {
    @Test("A confirmed-online agent still reads No internet once the device has no path")
    func onlineAgentBecomesNoInternet() {
        let online = AgentConnectionPhase(info: AgentInfo(address: testAgentAddress, online: true))
        #expect(online == .online)
        #expect(online.offlineAware(deviceIsOffline: true) == .noInternet)
    }

    @Test("Every phase reads No internet while offline, and is untouched while online")
    func phasesMapConsistently() {
        for phase in [AgentConnectionPhase.checking, .online, .offline] {
            #expect(phase.offlineAware(deviceIsOffline: true) == .noInternet)
            #expect(phase.offlineAware(deviceIsOffline: false) == phase)
        }
    }

    @Test("No internet carries its own label, distinct from Offline")
    func noInternetHasItsOwnLabel() {
        #expect(AgentConnectionPhase.noInternet.accessibilityLabel == "No internet")
        #expect(AgentConnectionPhase.offline.accessibilityLabel == "Offline")
    }
}

/// With an endpoint configured, every routing failure used to be reported as "couldn't reach that
/// endpoint" — even when the directory had answered and simply had no live connection for the agent.
/// The address can be perfectly correct and the agent just not running.
@Suite("Directory failure attribution")
struct DirectoryFailureAttributionTests {
    @Test("A registered but disconnected agent is named as offline, not as a bad endpoint")
    func offlineAgentIsNotBlamedOnTheEndpoint() {
        let failure = ChatFailure(error: AgentDirectoryError.agentOffline(endpoints: []), canResend: false)
        #expect(failure.title == "That agent isn't online")
        #expect(failure.action == .reconnect)
        #expect(failure.body.contains("Start the agent"))
    }

    @Test("Advertised addresses that all failed are surfaced as detail")
    func advertisedAddressesBecomeDetail() {
        let endpoints = [URL(string: "http://10.0.0.5:8000")!, URL(string: "http://10.0.0.6:8000")!]
        let failure = ChatFailure(error: AgentDirectoryError.agentOffline(endpoints: endpoints), canResend: false)
        #expect(failure.title == "Can't reach that agent")
        #expect(failure.detail?.contains("10.0.0.5") == true)
    }

    @Test("The endpoint is still named when the directory told us nothing")
    func silentDirectoryStillBlamesTheEndpoint() {
        let failure = ChatFailure(
            error: AgentDirectoryError.preferredEndpointUnavailable(URL(string: "http://192.168.1.8:8001")!),
            canResend: false
        )
        #expect(failure.title.contains("192.168.1.8:8001"))
    }
}
