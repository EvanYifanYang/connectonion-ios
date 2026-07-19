import XCTest

/// Sprint 1 — Real-backend end-to-end smoke test.
///
/// Unlike `ConnectOnion_iOSUITests` (which seed mock dependencies via `--ui-testing`), this test
/// launches the app with its **real** networking + persistence stack and drives it against a **live
/// ConnectOnion agent** hosted locally (default `http://localhost:8000`). It proves the minimum
/// deliverable: a real connection → prompt → streamed agent response.
///
/// Inject the live agent's address at run time:
///   xcodebuild test ... \
///     -only-testing:"ConnectOnion iOSUITests/ConnectOnion_iOSE2ETests" \
///     TEST_RUNNER_E2E_AGENT_ADDRESS=0x... \
///     TEST_RUNNER_E2E_AGENT_ENDPOINT=http://localhost:8000
/// The test is skipped (not failed) when the address env var is absent.
final class ConnectOnion_iOSE2ETests: XCTestCase {
    private let appShellID = "connectonion.app.shell"
    private let addAgentButtonID = "connectonion.agent.add.button"
    private let addressFieldID = "connectonion.agent.add.address"
    private let aliasFieldID = "connectonion.agent.add.alias"
    private let endpointFieldID = "connectonion.agent.add.endpoint"
    private let saveAgentButtonID = "connectonion.agent.save.button"
    private let chatInputID = "connectonion.chat.input"
    private let chatSendButtonID = "connectonion.chat.send.button"
    private let newChatButtonID = "connectonion.agent.newchat.button"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testRealAgentEndToEnd() throws {
        let env = ProcessInfo.processInfo.environment
        let address = env["E2E_AGENT_ADDRESS"] ?? ""
        let endpoint = env["E2E_AGENT_ENDPOINT"] ?? "http://localhost:8000"
        try XCTSkipIf(address.isEmpty, "Set TEST_RUNNER_E2E_AGENT_ADDRESS to run the real-agent E2E test.")

        let app = XCUIApplication()
        // Show the home screen (with the app icon) first, so the demo recording captures
        // entering the app from the home screen before the springboard launch animation.
        XCUIDevice.shared.press(.home)
        pause(2.5)
        // No `--ui-testing`: use the real network stack + persistence, not seeded mocks.
        app.launch()
        XCTAssertTrue(element(appShellID, app).waitForExistence(timeout: 12), app.debugDescription)
        pause()

        // 1) Configure the live agent. Tolerant of persisted state: add it if the empty-state
        //    "Add Agent" button is present, otherwise open the already-configured agent.
        let addButton = app.descendants(matching: .any).matching(identifier: addAgentButtonID).firstMatch
        if addButton.waitForExistence(timeout: 5) {
            tap(addAgentButtonID, app)
            let addressField = element(addressFieldID, app)
            XCTAssertTrue(addressField.waitForExistence(timeout: 6), app.debugDescription)
            pause()
            addressField.tap(); addressField.typeText(address); pause()

            let aliasField = element(aliasFieldID, app)
            aliasField.tap(); aliasField.typeText("E2E Local Agent"); pause()

            let endpointField = element(endpointFieldID, app)
            endpointField.tap(); endpointField.typeText(endpoint); pause()

            tap(saveAgentButtonID, app)
            pause()
        } else {
            let agentRow = app.descendants(matching: .any)
                .matching(identifier: "connectonion.agent.\(address)").firstMatch
            if agentRow.waitForExistence(timeout: 5) { agentRow.tap() }
        }

        // The post-add flow now lands on the agent home ("No chats yet"); open a fresh chat so the
        // chat input appears (the custom-instructions update moved chat behind a "New Chat" tap).
        let newChatButton = element(newChatButtonID, app)
        if newChatButton.waitForExistence(timeout: 8) {
            tap(newChatButtonID, app)
            pause()
        }

        // 2) Send a prompt that should exercise the `add` tool round-trip.
        let input = element(chatInputID, app)
        XCTAssertTrue(input.waitForExistence(timeout: 10), app.debugDescription)
        input.tap()
        input.typeText("What is 21 plus 21? Use the add tool and tell me the result.")
        pause()
        tap(chatSendButtonID, app)

        // 3) Wait for the real agent's streamed answer (LLM round trip can take a while).
        let answer = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS %@", "42"))
            .firstMatch
        XCTAssertTrue(
            answer.waitForExistence(timeout: 60),
            "No '42' answer streamed back from the live agent.\n" + app.debugDescription
        )
        pause(5)  // linger on the result so the demo recording shows the answer
    }

    // MARK: - Helpers

    /// Small deliberate pause so the screen recording is watchable as a demo (not needed for correctness).
    private func pause(_ seconds: TimeInterval = 1.2) { Thread.sleep(forTimeInterval: seconds) }

    @MainActor private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// Robust tap: an identifier can match several elements (e.g. a toolbar button + its label),
    /// so tap the first *hittable* match rather than a single subscript lookup.
    @MainActor private func tap(_ id: String, _ app: XCUIApplication) {
        let query = app.descendants(matching: .any).matching(identifier: id)
        XCTAssertTrue(query.firstMatch.waitForExistence(timeout: 8), "missing \(id)\n" + app.debugDescription)
        for index in 0..<query.count {
            let el = query.element(boundBy: index)
            if el.exists, el.isHittable { el.tap(); return }
        }
        app.swipeUp()
        for index in 0..<query.count {
            let el = query.element(boundBy: index)
            if el.exists, el.isHittable { el.tap(); return }
        }
        XCTFail("\(id) exists but is not hittable\n" + app.debugDescription)
    }
}
