import XCTest

final class ConnectOnion_iOSUITests: XCTestCase {
    private let appShellID = "connectonion.app.shell"
    private let addAgentButtonID = "connectonion.agent.add.button"
    private let addAgentAddressFieldID = "connectonion.agent.add.address"
    private let addAgentAliasFieldID = "connectonion.agent.add.alias"
    private let addAgentEndpointFieldID = "connectonion.agent.add.endpoint"
    private let agentActionsButtonID = "connectonion.agent.actions.button"
    private let renameAgentButtonID = "connectonion.agent.rename.button"
    private let deleteAgentButtonID = "connectonion.agent.delete.button"
    private let newChatButtonID = "connectonion.chat.new.button"
    private let newChatSheetID = "connectonion.chat.new.sheet"
    private let newChatPromptFieldID = "connectonion.chat.new.prompt"
    private let newChatStartButtonID = "connectonion.chat.new.start"
    private let chatInputID = "connectonion.chat.input"
    private let chatSendButtonID = "connectonion.chat.send.button"
    private let chatStopButtonID = "connectonion.chat.stop.button"
    private let chatAttachmentButtonID = "connectonion.chat.attachment.button"
    private let chatAttachmentPhotoButtonID = "connectonion.chat.attachment.photo"
    private let chatAttachmentFilesButtonID = "connectonion.chat.attachment.files"
    private let showSystemInfoSuggestionID = "connectonion.suggestion.show-system-info"
    private let seededAgentID = "connectonion.agent.0xf5ff043a9c5df95eac9387908dea87beb7b59c2a3b04787e3222fdf8209cdee1"
    private let seededNewChatAgentID = "connectonion.chat.new.agent.0xf5ff043a9c5df95eac9387908dea87beb7b59c2a3b04787e3222fdf8209cdee1"
    private let seededConversationID = "connectonion.conversation.C9F4D04E-6D26-4F70-9808-74F09752D6D1"
    private let approvalApproveButtonID = "connectonion.approval.approve"
    private let approvalAlwaysButtonID = "connectonion.approval.always"
    private let approvalSkipButtonID = "connectonion.approval.skip"
    private let approvalStatusID = "connectonion.approval.status"
    private let askUserAnswerFieldID = "connectonion.ask-user.answer"
    private let askUserSendButtonID = "connectonion.ask-user.send"
    private let askUserConfirmButtonID = "connectonion.ask-user.confirm"
    private let askUserSubmitButtonID = "connectonion.ask-user.submit"
    private let askUserStatusID = "connectonion.ask-user.status"
    private let inviteCodeFieldID = "connectonion.onboard.invite"
    private let inviteSubmitButtonID = "connectonion.onboard.submit"
    private let onboardStatusID = "connectonion.onboard.status"
    private let planReviewFeedbackFieldID = "connectonion.plan-review.feedback"
    private let planReviewApproveButtonID = "connectonion.plan-review.approve"
    private let planReviewReviseButtonID = "connectonion.plan-review.revise"
    private let planReviewStatusID = "connectonion.plan-review.status"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSeededAgentLaunchesIntoUsableShell() throws {
        let app = launchUITestApp()

        XCTAssertTrue(app.anyElement(appShellID).waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["OpenOnion"].exists)
        XCTAssertTrue(app.anyElement(seededConversationID).waitForExistence(timeout: 5))

        app.anyElement(seededConversationID).tap()

        XCTAssertTrue(app.anyElement(chatInputID).waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertTrue(app.anyElement(chatSendButtonID).exists)
    }

    @MainActor
    func testStandardComposerSendsMockStreamingResponse() throws {
        let app = launchUITestApp()
        openSeededConversation(in: app)

        XCTAssertTrue(app.anyElement(chatSendButtonID).exists)
        XCTAssertFalse(app.anyElement(chatStopButtonID).exists)
        XCTAssertFalse(app.buttons["Safe"].exists)
        XCTAssertFalse(app.buttons["Plan"].exists)
        XCTAssertFalse(app.buttons["Accept Edits"].exists)

        app.anyElement(chatInputID).tap()
        app.typeText("Hello from UI tests")
        tapElement(chatSendButtonID, in: app)

        let response = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Connected. Streaming mock response")).firstMatch
        XCTAssertTrue(response.waitForExistence(timeout: 8), app.debugDescription)
    }

    @MainActor
    func testChatAttachmentMenuExposesPhotoAndFileOptions() throws {
        let app = launchUITestApp()
        openSeededConversation(in: app)

        XCTAssertTrue(app.anyElement(chatAttachmentButtonID).exists)
        tapElement(chatAttachmentButtonID, in: app)

        XCTAssertTrue(app.anyElement(chatAttachmentPhotoButtonID).waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.anyElement(chatAttachmentFilesButtonID).exists, app.debugDescription)
        app.buttons["Cancel"].tap()
    }

    @MainActor
    func testEmptyShellHidesSectionTitlesAndShowsAddAgentState() throws {
        let app = launchUITestApp(scenario: "empty")

        XCTAssertTrue(app.anyElement(appShellID).waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertTrue(app.anyElement(addAgentButtonID).waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.staticTexts["Agents"].exists)
        XCTAssertFalse(app.staticTexts["Chats"].exists)
        XCTAssertFalse(app.anyElement(newChatButtonID).exists)
    }

    @MainActor
    func testAgentLandingHidesDesktopSkillCommandPalette() throws {
        let app = launchUITestApp()

        XCTAssertTrue(app.anyElement(appShellID).waitForExistence(timeout: 8), app.debugDescription)
        tapElement(seededAgentID, in: app)

        XCTAssertTrue(app.buttons["What can you do?"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.staticTexts["/summarize"].exists)
        XCTAssertFalse(app.staticTexts["/debug"].exists)
        XCTAssertFalse(app.staticTexts["Bash"].exists)
    }

    @MainActor
    func testAgentLongPressExposesRenameDeleteAndEndpointEditing() throws {
        let app = launchUITestApp()

        XCTAssertTrue(app.anyElement(appShellID).waitForExistence(timeout: 8), app.debugDescription)
        let agent = waitForElement(seededAgentID, in: app)
        agent.press(forDuration: 0.8)

        XCTAssertTrue(app.anyElement(renameAgentButtonID).waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.anyElement(deleteAgentButtonID).exists, app.debugDescription)

        tapElement(renameAgentButtonID, in: app)
        let addressField = waitForElement(addAgentAddressFieldID, in: app)
        XCTAssertFalse(addressField.isEnabled)
        XCTAssertTrue(app.anyElement(addAgentAliasFieldID).exists, app.debugDescription)
        XCTAssertTrue(app.anyElement(addAgentEndpointFieldID).exists, app.debugDescription)
        app.buttons["Cancel"].tap()
    }

    @MainActor
    func testAgentActionsMenuExposesRenameDeleteAndEndpointEditing() throws {
        let app = launchUITestApp()

        XCTAssertTrue(app.anyElement(appShellID).waitForExistence(timeout: 8), app.debugDescription)
        tapElement(agentActionsButtonID, in: app)

        XCTAssertTrue(app.anyElement(renameAgentButtonID).waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.anyElement(deleteAgentButtonID).exists, app.debugDescription)

        tapElement(renameAgentButtonID, in: app)
        let addressField = waitForElement(addAgentAddressFieldID, in: app)
        XCTAssertFalse(addressField.isEnabled)
        XCTAssertTrue(app.anyElement(addAgentAliasFieldID).exists, app.debugDescription)
        XCTAssertTrue(app.anyElement(addAgentEndpointFieldID).exists, app.debugDescription)
        app.buttons["Cancel"].tap()
    }

    @MainActor
    func testNewChatButtonOpensAgentPickerAndStartsPrompt() throws {
        let app = launchUITestApp()

        XCTAssertTrue(app.anyElement(appShellID).waitForExistence(timeout: 8), app.debugDescription)
        tapElement(newChatButtonID, in: app)

        XCTAssertTrue(app.anyElement(newChatSheetID).waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.anyElement(seededNewChatAgentID).exists, app.debugDescription)

        app.anyElement(newChatPromptFieldID).tap()
        app.typeText("Start a fresh chat")
        tapElement(newChatStartButtonID, in: app)

        XCTAssertTrue(app.anyElement(chatInputID).waitForExistence(timeout: 8), app.debugDescription)
        let response = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Connected. Streaming mock response for: Start a fresh chat")).firstMatch
        XCTAssertTrue(response.waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertTrue(app.anyElement(chatSendButtonID).exists)
        XCTAssertFalse(app.anyElement(chatStopButtonID).exists)
    }

    @MainActor
    func testApprovalActionsResolveAndKeepComposerInSendState() throws {
        try assertApprovalAction(buttonID: approvalApproveButtonID, expectedStatus: "Approved")
        try assertApprovalAction(buttonID: approvalAlwaysButtonID, expectedStatus: "Approved for session")
        try assertApprovalAction(buttonID: approvalSkipButtonID, expectedStatus: "Skipped")
    }

    @MainActor
    func testAskUserTextFlowResponds() throws {
        let app = launchUITestApp(scenario: "ask-text")
        openSeededConversation(in: app)

        XCTAssertFalse(app.anyElement(chatStopButtonID).exists)
        app.anyElement(askUserAnswerFieldID).tap()
        app.typeText("Focus on UI automation")
        tapElement(askUserSendButtonID, in: app)

        let status = waitForStaticText(askUserStatusID, in: app)
        XCTAssertTrue(status.label.contains("Focus on UI automation"), status.label)
        XCTAssertTrue(app.anyElement(chatSendButtonID).exists)
        XCTAssertFalse(app.anyElement(chatStopButtonID).exists)
    }

    @MainActor
    func testAskUserOptionsFlowResponds() throws {
        let app = launchUITestApp(scenario: "ask-options")
        openSeededConversation(in: app)

        tapElement("connectonion.ask-user.option.quick-smoke-test", in: app)
        tapElement(askUserConfirmButtonID, in: app)

        let status = waitForStaticText(askUserStatusID, in: app)
        XCTAssertTrue(status.label.contains("Quick smoke test"), status.label)
        XCTAssertTrue(app.anyElement(chatSendButtonID).exists)
        XCTAssertFalse(app.anyElement(chatStopButtonID).exists)
    }

    @MainActor
    func testAskUserFieldsFlowResponds() throws {
        let app = launchUITestApp(scenario: "ask-fields")
        openSeededConversation(in: app)

        app.anyElement("connectonion.ask-user.field.username").tap()
        app.typeText("romanticd")
        app.anyElement("connectonion.ask-user.field.token").tap()
        app.typeText("secret")
        tapElement(askUserSubmitButtonID, in: app)

        let status = waitForStaticText(askUserStatusID, in: app)
        XCTAssertTrue(status.label.contains("username"), status.label)
        XCTAssertTrue(app.anyElement(chatSendButtonID).exists)
        XCTAssertFalse(app.anyElement(chatStopButtonID).exists)
    }

    @MainActor
    func testOnboardingInviteFlowResponds() throws {
        let app = launchUITestApp(scenario: "onboard")
        openSeededConversation(in: app)

        XCTAssertFalse(app.anyElement(chatStopButtonID).exists)
        app.anyElement(inviteCodeFieldID).tap()
        app.typeText("OpenOnion")
        tapElement(inviteSubmitButtonID, in: app)

        let status = waitForStaticText(onboardStatusID, in: app)
        XCTAssertTrue(status.label.contains("Invite submitted"), status.label)
        XCTAssertTrue(app.anyElement(chatSendButtonID).exists)
        XCTAssertFalse(app.anyElement(chatStopButtonID).exists)
    }

    @MainActor
    func testSuggestionsReturnWhenFirstPromptTriggersInviteGate() throws {
        let app = launchUITestApp(scenario: "onboard-first-message")

        XCTAssertTrue(app.anyElement(appShellID).waitForExistence(timeout: 8), app.debugDescription)
        tapElement(seededAgentID, in: app)

        XCTAssertTrue(app.buttons["What can you do?"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["What can you do?"].tap()

        XCTAssertTrue(app.anyElement(inviteCodeFieldID).waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.staticTexts["What can you do?"].exists)

        app.anyElement(inviteCodeFieldID).tap()
        app.typeText("OpenOnion")
        tapElement(inviteSubmitButtonID, in: app)

        let status = waitForStaticText(onboardStatusID, in: app)
        XCTAssertTrue(status.label.contains("Invite submitted"), status.label)
        XCTAssertTrue(app.anyElement(showSystemInfoSuggestionID).waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.anyElement(chatSendButtonID).exists)
        XCTAssertFalse(app.anyElement(chatStopButtonID).exists)
    }

    @MainActor
    func testPlanReviewApproveAndReviseFlowsRespond() throws {
        var app = launchUITestApp(scenario: "plan-review")
        openSeededConversation(in: app)
        tapElement(planReviewApproveButtonID, in: app)

        var status = waitForStaticText(planReviewStatusID, in: app)
        XCTAssertTrue(status.label.contains("Plan approved"), status.label)
        XCTAssertTrue(app.anyElement(chatSendButtonID).exists)
        XCTAssertFalse(app.anyElement(chatStopButtonID).exists)
        app.terminate()

        app = launchUITestApp(scenario: "plan-review")
        openSeededConversation(in: app)
        app.anyElement(planReviewFeedbackFieldID).tap()
        app.typeText("Revise the risk section")
        tapElement(planReviewReviseButtonID, in: app)

        status = waitForStaticText(planReviewStatusID, in: app)
        XCTAssertTrue(status.label.contains("Revision requested"), status.label)
        XCTAssertTrue(app.anyElement(chatSendButtonID).exists)
        XCTAssertFalse(app.anyElement(chatStopButtonID).exists)
    }

    @MainActor
    func testAgentListIsAccessibleWhenSidebarIsVisible() throws {
        let app = launchUITestApp()

        let sidebarAgentVisible = app.anyElement(seededAgentID).waitForExistence(timeout: 3)
        let newChatVisible = app.anyElement(newChatButtonID).waitForExistence(timeout: 2)
        let chatInputVisible = app.anyElement(chatInputID).waitForExistence(timeout: 2)

        XCTAssertTrue(sidebarAgentVisible || newChatVisible || chatInputVisible)
    }

    @MainActor
    private func assertApprovalAction(buttonID: String, expectedStatus: String) throws {
        let app = launchUITestApp(scenario: "approval")
        openSeededConversation(in: app)

        XCTAssertFalse(app.anyElement(chatStopButtonID).exists)
        tapElement(buttonID, in: app)

        let status = waitForStaticText(approvalStatusID, in: app)
        XCTAssertTrue(status.label.contains(expectedStatus), status.label)
        XCTAssertTrue(app.anyElement(chatSendButtonID).exists)
        XCTAssertFalse(app.anyElement(chatStopButtonID).exists)
        app.terminate()
    }

    @MainActor
    private func launchUITestApp(scenario: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        if let scenario {
            app.launchArguments.append("--ui-testing-scenario=\(scenario)")
        }
        app.launch()
        return app
    }

    @MainActor
    private func openSeededConversation(in app: XCUIApplication) {
        XCTAssertTrue(app.anyElement(appShellID).waitForExistence(timeout: 8), app.debugDescription)
        if app.anyElement(chatInputID).waitForExistence(timeout: 1) {
            return
        }
        tapElement(seededConversationID, in: app)
        XCTAssertTrue(app.anyElement(chatInputID).waitForExistence(timeout: 8), app.debugDescription)
    }

    @MainActor
    private func waitForElement(_ identifier: String, in app: XCUIApplication, timeout: TimeInterval = 6) -> XCUIElement {
        let element = app.anyElement(identifier)
        XCTAssertTrue(element.waitForExistence(timeout: timeout), app.debugDescription)
        return element
    }

    @MainActor
    private func waitForStaticText(_ identifier: String, in app: XCUIApplication, timeout: TimeInterval = 6) -> XCUIElement {
        let element = app.staticTexts[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: timeout), app.debugDescription)
        return element
    }

    @MainActor
    private func tapElement(_ identifier: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let query = app.descendants(matching: .any).matching(identifier: identifier)
        XCTAssertTrue(query.firstMatch.waitForExistence(timeout: 6), app.debugDescription, file: file, line: line)

        for index in 0..<query.count {
            let element = query.element(boundBy: index)
            if element.exists, element.isHittable {
                element.tap()
                return
            }
        }

        app.swipeUp()

        for index in 0..<query.count {
            let element = query.element(boundBy: index)
            if element.exists, element.isHittable {
                element.tap()
                return
            }
        }

        XCTFail("Element \(identifier) exists but is not hittable", file: file, line: line)
    }
}

private extension XCUIApplication {
    func anyElement(_ identifier: String) -> XCUIElement {
        descendants(matching: .any)[identifier]
    }
}
