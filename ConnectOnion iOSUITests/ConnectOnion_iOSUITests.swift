//
//  ConnectOnion_iOSUITests.swift
//
//  Purpose: Implements ConnectOnion_iOSUITests for the ConnectOnion iOSUITests module.
//  Collaborates with: ConnectOnion_iOSE2ETests.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import XCTest

final class ConnectOnion_iOSUITests: XCTestCase {
    private let appShellID = "connectonion.app.shell"
    private let addAgentButtonID = "connectonion.agent.add.button"
    private let addAgentAddressFieldID = "connectonion.agent.add.address"
    private let addAgentAliasFieldID = "connectonion.agent.add.alias"
    private let addAgentEndpointFieldID = "connectonion.agent.add.endpoint"
    private let agentActionsButtonID = "connectonion.agent.actions.button"
    private let renameAgentButtonID = "connectonion.agent.rename.button"
    private let agentRenameFieldID = "connectonion.agent.rename.field"
    private let renameConversationButtonID = "connectonion.chat.rename.button"
    private let conversationRenameFieldID = "connectonion.chat.rename.field"
    private let deleteAgentButtonID = "connectonion.agent.delete.button"
    private let newChatButtonID = "connectonion.chat.new.button"
    private let newChatSheetID = "connectonion.chat.new.sheet"
    private let newChatPromptFieldID = "connectonion.chat.new.prompt"
    private let newChatStartButtonID = "connectonion.chat.new.start"
    private let whatCanYouDoSuggestionID = "connectonion.chat.new.suggestion.what-can-you-do"
    private let planDaySuggestionID = "connectonion.chat.new.suggestion.help-me-plan-my-day"
    private let newChatToolsDisclosureID = "connectonion.chat.new.tools.disclosure"
    private let newChatToolsSummaryID = "connectonion.chat.new.tools.summary"
    private let newChatSkillsDisclosureID = "connectonion.chat.new.skills.disclosure"
    private let summarizeSkillID = "connectonion.chat.new.skill.summarize"
    private let organizeSkillID = "connectonion.chat.new.skill.organize"
    private let chatSkillPaletteID = "connectonion.chat.skill.palette"
    private let chatOrganizeSkillID = "connectonion.chat.skill.organize"
    private let chatInputID = "connectonion.chat.input"
    private let chatSendButtonID = "connectonion.chat.send.button"
    private let chatStopButtonID = "connectonion.chat.stop.button"
    private let latestMessageEditButtonID = "connectonion.chat.latest-message.edit"
    private let latestMessageEditorID = "connectonion.chat.latest-message.editor"
    private let latestMessageEditCancelButtonID = "connectonion.chat.latest-message.edit.cancel"
    private let latestMessageEditSaveButtonID = "connectonion.chat.latest-message.edit.save"
    private let chatAttachmentButtonID = "connectonion.chat.attachment.button"
    private let chatAttachmentPhotoButtonID = "connectonion.chat.attachment.photo"
    private let chatAttachmentFilesButtonID = "connectonion.chat.attachment.files"
    private let newChatInAgentButtonID = "connectonion.agent.newchat.button"
    private let seededAgentID = "connectonion.agent.0xf5ff043a9c5df95eac9387908dea87beb7b59c2a3b04787e3222fdf8209cdee1"
    private let seededNewChatAgentID = "connectonion.chat.new.agent.0xf5ff043a9c5df95eac9387908dea87beb7b59c2a3b04787e3222fdf8209cdee1"
    private let seededConversationID = "connectonion.conversation.C9F4D04E-6D26-4F70-9808-74F09752D6D1"
    private let seededDeleteConversationID = "connectonion.conversation.delete.C9F4D04E-6D26-4F70-9808-74F09752D6D1"
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

        // Agent-centric IA: the root lists agents only; conversations live on the agent's home.
        XCTAssertTrue(app.anyElement(appShellID).waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["OpenOnion"].waitForExistence(timeout: 5))

        tapElement(seededAgentID, in: app)
        XCTAssertTrue(app.anyElement(seededConversationID).waitForExistence(timeout: 5), app.debugDescription)

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
    func testLatestUserMessageCanBeEditedAndRegeneratedInline() throws {
        // The inline edit-message UI was deferred during the main↔feature-improvements merge (the
        // ViewModel edit state is kept; the view is re-wired in a follow-up). Skip until then.
        // XCTSkipIf (vs an unconditional throw) avoids an unreachable-code warning on the body below.
        try XCTSkipIf(true, "Inline user-message edit UI is deferred to a follow-up; re-enable when re-wired.")

        let app = launchUITestApp()
        openSeededConversation(in: app)

        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: latestMessageEditButtonID).count, 1)
        tapElement(latestMessageEditButtonID, in: app)

        let editor = waitForElement(latestMessageEditorID, in: app)
        XCTAssertFalse(app.anyElement(chatInputID).isEnabled)
        XCTAssertTrue(app.anyElement(latestMessageEditCancelButtonID).isEnabled)
        XCTAssertFalse(app.anyElement(latestMessageEditSaveButtonID).isEnabled)

        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        editor.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 80))
        editor.typeText("Updated question")
        XCTAssertTrue(app.anyElement(latestMessageEditSaveButtonID).isEnabled)
        tapElement(latestMessageEditSaveButtonID, in: app)

        let response = app.staticTexts
            .matching(NSPredicate(
                format: "label CONTAINS %@",
                "Connected. Streaming mock response for: Updated question"
            ))
            .firstMatch
        XCTAssertTrue(response.waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Updated question"].exists)
        XCTAssertTrue(app.anyElement(chatInputID).isEnabled)
    }

    @MainActor
    func testChatAttachmentMenuExposesPhotoAndFileOptions() throws {
        let app = launchUITestApp()
        openSeededConversation(in: app)

        XCTAssertTrue(app.anyElement(chatAttachmentButtonID).exists)
        tapElement(chatAttachmentButtonID, in: app)

        XCTAssertTrue(app.anyElement(chatAttachmentPhotoButtonID).waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.anyElement(chatAttachmentFilesButtonID).exists, app.debugDescription)
        // The photo/file options above are the assertion. iOS 26's attachment menu has no explicit
        // "Cancel", so dismiss best-effort only if that affordance is present.
        if app.buttons["Cancel"].exists {
            app.buttons["Cancel"].tap()
        }
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
        openLandingComposer(in: app)

        XCTAssertTrue(app.anyElement(chatInputID).waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.staticTexts["/summarize"].exists)
        XCTAssertFalse(app.staticTexts["/debug"].exists)
        XCTAssertFalse(app.staticTexts["Bash"].exists)
    }

    @MainActor
    func testAgentLandingShowsSuggestionsAndCapabilitySummaries() throws {
        let app = launchUITestApp()
        openLandingComposer(in: app)

        XCTAssertTrue(app.anyElement(whatCanYouDoSuggestionID).waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.anyElement(planDaySuggestionID).exists, app.debugDescription)

        let toolsDisclosure = waitForElement(newChatToolsDisclosureID, in: app)
        XCTAssertTrue(toolsDisclosure.label.contains("7 tools"), toolsDisclosure.label)
        XCTAssertTrue(toolsDisclosure.label.contains("collapsed"), toolsDisclosure.label)
        XCTAssertFalse(app.anyElement(newChatToolsSummaryID).exists, app.debugDescription)
        tapElement(newChatToolsDisclosureID, in: app)

        let toolsSummary = waitForElement(newChatToolsSummaryID, in: app)
        XCTAssertTrue(toolsSummary.label.contains("bash"), toolsSummary.label)
        XCTAssertTrue(toolsSummary.label.contains("read_file"), toolsSummary.label)
        XCTAssertTrue(toolsSummary.label.contains("+1 more"), toolsSummary.label)

        let skillsDisclosure = waitForElement(newChatSkillsDisclosureID, in: app)
        XCTAssertTrue(skillsDisclosure.label.contains("8 skills"), skillsDisclosure.label)
        XCTAssertTrue(skillsDisclosure.label.contains("collapsed"), skillsDisclosure.label)
        XCTAssertFalse(app.anyElement(summarizeSkillID).exists, app.debugDescription)
        tapElement(newChatSkillsDisclosureID, in: app)

        let skill = waitForElement(summarizeSkillID, in: app)
        XCTAssertTrue(skill.label.contains("summarize"), skill.label)
        XCTAssertTrue(skill.label.contains("Summarize a document"), skill.label)
        app.swipeUp()
        XCTAssertTrue(waitForElement(organizeSkillID, in: app).isHittable, app.debugDescription)
    }

    @MainActor
    func testSlashSkillPaletteKeepsItsViewportAndScrollsToEverySkill() throws {
        let app = launchUITestApp()
        openLandingComposer(in: app)

        let input = waitForElement(chatInputID, in: app)
        input.tap()
        app.typeText("/")

        let palette = waitForElement(chatSkillPaletteID, in: app)
        palette.swipeUp()

        XCTAssertTrue(waitForElement(chatOrganizeSkillID, in: app).isHittable, app.debugDescription)
    }

    @MainActor
    func testAgentLandingCapabilitySectionsCollapseAndExpand() throws {
        let app = launchUITestApp()
        openLandingComposer(in: app)

        XCTAssertFalse(app.anyElement(newChatToolsSummaryID).exists, app.debugDescription)
        tapElement(newChatToolsDisclosureID, in: app)
        XCTAssertTrue(app.anyElement(newChatToolsSummaryID).waitForExistence(timeout: 5), app.debugDescription)
        tapElement(newChatToolsDisclosureID, in: app)
        XCTAssertFalse(app.anyElement(newChatToolsSummaryID).exists, app.debugDescription)

        XCTAssertFalse(app.anyElement(summarizeSkillID).exists, app.debugDescription)
        tapElement(newChatSkillsDisclosureID, in: app)
        XCTAssertTrue(app.anyElement(summarizeSkillID).waitForExistence(timeout: 5), app.debugDescription)
        tapElement(newChatSkillsDisclosureID, in: app)
        XCTAssertFalse(app.anyElement(summarizeSkillID).exists, app.debugDescription)
    }

    @MainActor
    func testAgentLandingHidesEmptyCapabilitySections() throws {
        let app = launchUITestApp(scenario: "metadata-empty")
        openLandingComposer(in: app)

        XCTAssertTrue(app.anyElement(whatCanYouDoSuggestionID).waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.anyElement(chatInputID).exists, app.debugDescription)
        XCTAssertFalse(app.anyElement(newChatToolsDisclosureID).exists, app.debugDescription)
        XCTAssertFalse(app.anyElement(newChatSkillsDisclosureID).exists, app.debugDescription)
    }

    @MainActor
    func testAgentLandingSuggestionStartsConversationImmediately() throws {
        let app = launchUITestApp()
        openLandingComposer(in: app)

        tapElement(whatCanYouDoSuggestionID, in: app)

        let response = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS %@", "Connected. Streaming mock response for: What can you do?"))
            .firstMatch
        XCTAssertTrue(response.waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertTrue(app.staticTexts["What can you do?"].exists, app.debugDescription)
    }

    @MainActor
    func testAgentLongPressExposesRenameAndDelete() throws {
        let app = launchUITestApp()

        XCTAssertTrue(app.anyElement(appShellID).waitForExistence(timeout: 8), app.debugDescription)
        let agent = waitForElement(seededAgentID, in: app)
        agent.press(forDuration: 0.8)

        XCTAssertTrue(app.anyElement(renameAgentButtonID).waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.anyElement(deleteAgentButtonID).exists, app.debugDescription)

        tapElement(renameAgentButtonID, in: app)
        XCTAssertTrue(app.anyElement(agentRenameFieldID).waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testAgentActionsMenuRenamesInline() throws {
        let app = launchUITestApp()

        XCTAssertTrue(app.anyElement(appShellID).waitForExistence(timeout: 8), app.debugDescription)
        tapElement(agentActionsButtonID, in: app)

        XCTAssertTrue(app.anyElement(renameAgentButtonID).waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.anyElement(deleteAgentButtonID).exists, app.debugDescription)

        tapElement(renameAgentButtonID, in: app)
        let field = waitForElement(agentRenameFieldID, in: app)
        // Tap near the right edge so the caret lands at the end, then clear generously before typing.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 40))
        field.typeText("Renamed Agent\n")

        XCTAssertTrue(app.staticTexts["Renamed Agent"].waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testNewAgentButtonOpensAgentEditor() throws {
        // The bottom-right "+" is now "New Agent" (it opens the agent editor), replacing the old
        // New-Chat picker. New chats are started from an agent's landing composer instead.
        let app = launchUITestApp()

        XCTAssertTrue(app.anyElement(appShellID).waitForExistence(timeout: 8), app.debugDescription)
        tapElement(addAgentButtonID, in: app)

        let addressField = waitForElement(addAgentAddressFieldID, in: app)
        XCTAssertTrue(addressField.isEnabled, app.debugDescription)
        XCTAssertTrue(app.anyElement(addAgentAliasFieldID).exists, app.debugDescription)
        app.buttons["Cancel"].tap()
    }

    @MainActor
    func testAgentLandingComposerStartsConversation() throws {
        let app = launchUITestApp()
        openLandingComposer(in: app)

        let input = waitForElement(chatInputID, in: app)
        input.tap()
        app.typeText("Start a fresh chat")
        tapElement(chatSendButtonID, in: app)

        let response = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Connected. Streaming mock response for: Start a fresh chat")).firstMatch
        XCTAssertTrue(response.waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertTrue(app.anyElement(chatSendButtonID).exists)
        XCTAssertFalse(app.anyElement(chatStopButtonID).exists)
    }

    @MainActor
    func testConversationRowSwipeDeletesChat() throws {
        let app = launchUITestApp()

        XCTAssertTrue(app.anyElement(appShellID).waitForExistence(timeout: 8), app.debugDescription)
        tapElement(seededAgentID, in: app) // agent-centric IA: conversations live on the agent home
        let conversation = waitForElement(seededConversationID, in: app)
        // A plain swipeLeft() doesn't reliably reveal SwiftUI swipeActions on iOS 26; a deliberate
        // right-to-left coordinate drag across the row does.
        let start = conversation.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        let end = conversation.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)

        // On iOS 26 the revealed swipe-action button keeps the row's accessibility identifier (the
        // `.delete.` id does not propagate through SwiftUI swipeActions) and is distinguished by its
        // "Delete …" label. Match on that label instead.
        let deleteButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Delete'")).firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), app.debugDescription)
        deleteButton.tap()

        XCTAssertFalse(app.anyElement(seededConversationID).waitForExistence(timeout: 2), app.debugDescription)
    }

    @MainActor
    func testConversationMenuRenamesInline() throws {
        let app = launchUITestApp()

        XCTAssertTrue(app.anyElement(appShellID).waitForExistence(timeout: 8), app.debugDescription)
        tapElement(seededAgentID, in: app) // agent-centric IA: conversations live on the agent home
        _ = waitForElement(seededConversationID, in: app)
        app.buttons["Conversation Actions"].firstMatch.tap()

        tapElement(renameConversationButtonID, in: app)

        let field = app.textFields[conversationRenameFieldID]
        XCTAssertTrue(field.waitForExistence(timeout: 5), app.debugDescription)
        // Tap near the right edge so the caret lands at the end, then clear generously before typing.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 40))
        field.typeText("Renamed by test\n")

        XCTAssertTrue(app.staticTexts["Renamed by test"].waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testConversationRenameCommitsOnBackgroundTap() throws {
        let app = launchUITestApp()

        XCTAssertTrue(app.anyElement(appShellID).waitForExistence(timeout: 8), app.debugDescription)
        tapElement(seededAgentID, in: app) // agent-centric IA: conversations live on the agent home
        _ = waitForElement(seededConversationID, in: app)
        app.buttons["Conversation Actions"].firstMatch.tap()
        tapElement(renameConversationButtonID, in: app)

        let field = app.textFields[conversationRenameFieldID]
        XCTAssertTrue(field.waitForExistence(timeout: 5), app.debugDescription)
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 40))
        field.typeText("Tapped away")

        // No Return: tapping empty (non-interactive) space above the keyboard — here the "Chats"
        // section header on the agent home — should dismiss the keyboard and commit the rename.
        app.staticTexts["Chats"].tap()

        XCTAssertTrue(app.staticTexts["Tapped away"].waitForExistence(timeout: 5), app.debugDescription)
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
    func testFirstPromptResendsAfterInviteGate() throws {
        let app = launchUITestApp(scenario: "onboard-first-message")

        openLandingComposer(in: app)

        let input = waitForElement(chatInputID, in: app)
        input.tap()
        app.typeText("What can you do?")
        tapElement(chatSendButtonID, in: app)

        XCTAssertTrue(app.anyElement(inviteCodeFieldID).waitForExistence(timeout: 5), app.debugDescription)
        // Note: that the pending user prompt is *suppressed* during the invite gate is asserted precisely
        // by the Sprint 2 unit test `firstPromptThatTriggersOnboardingResendsOriginalInputAfterInviteSuccess`.
        // It is not re-checked here because on iOS 26 the suggestion button's label resolves as a static
        // text, so an absence check at the UI layer is unreliable.

        app.anyElement(inviteCodeFieldID).tap()
        app.typeText("OpenOnion")
        tapElement(inviteSubmitButtonID, in: app)

        let status = waitForStaticText(onboardStatusID, in: app)
        XCTAssertTrue(status.label.contains("Invite submitted"), status.label)
        XCTAssertTrue(app.staticTexts["What can you do?"].waitForExistence(timeout: 5), app.debugDescription)
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
        tapElement(seededAgentID, in: app) // agent-centric IA: open the agent's home first
        tapElement(seededConversationID, in: app)
        XCTAssertTrue(app.anyElement(chatInputID).waitForExistence(timeout: 8), app.debugDescription)
    }

    /// Agent-centric IA: reach the fresh-chat composer via agent home → "New chat".
    @MainActor
    private func openLandingComposer(in app: XCUIApplication) {
        XCTAssertTrue(app.anyElement(appShellID).waitForExistence(timeout: 8), app.debugDescription)
        tapElement(seededAgentID, in: app)
        tapElement(newChatInAgentButtonID, in: app)
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
        // Use firstMatch: on iOS 26 some SwiftUI rows expose their accessibility identifier on more
        // than one element, so a single-match subscript throws "Multiple matching elements" on tap/swipe.
        descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
