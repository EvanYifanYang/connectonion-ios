//
//  AccessibilityID.swift
//
//  Purpose: Implements AccessibilityID for the Core/Support module.
//  Collaborates with: AgentContentSanitizer, AttachmentEncoding, CustomInstructions, HexCoding, JSONValue, PersonalisationPreferences.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

enum AccessibilityID {
    static let appShell = "connectonion.app.shell"
    static let sidebar = "connectonion.sidebar"
    static let addAgentButton = "connectonion.agent.add.button"
    static let addAgentAddressField = "connectonion.agent.add.address"
    static let addAgentAliasField = "connectonion.agent.add.alias"
    static let addAgentEndpointField = "connectonion.agent.add.endpoint"
    static let scanAgentQRCodeButton = "connectonion.agent.qr.scan.button"
    static let agentQRScanner = "connectonion.agent.qr.scanner"
    static let agentQRScannerPhotoButton = "connectonion.agent.qr.photo.button"
    static let saveAgentButton = "connectonion.agent.save.button"
    static let renameAgentButton = "connectonion.agent.rename.button"
    static let deleteAgentButton = "connectonion.agent.delete.button"
    static let confirmDeleteAgentButton = "connectonion.agent.delete.confirm.button"
    static let agentActionsButton = "connectonion.agent.actions.button"
    static let agentRenameField = "connectonion.agent.rename.field"
    static let renameConversationButton = "connectonion.chat.rename.button"
    static let conversationActionsButton = "connectonion.chat.actions.button"
    static let agentSearchField = "connectonion.search.agents"
    static let chatSearchField = "connectonion.search.chats"
    static let conversationRenameField = "connectonion.chat.rename.field"
    static let newChatButton = "connectonion.chat.new.button"
    static let newChatInAgentButton = "connectonion.agent.newchat.button"
    static let agentInfoButton = "connectonion.agent.info.button"
    static let agentHome = "connectonion.agent.home"
    static let newChatSheet = "connectonion.chat.new.sheet"
    static let newChatPromptField = "connectonion.chat.new.prompt"
    static let newChatStartButton = "connectonion.chat.new.start"
    static let newChatToolsDisclosure = "connectonion.chat.new.tools.disclosure"
    static let newChatToolsSummary = "connectonion.chat.new.tools.summary"
    static let newChatSkillsDisclosure = "connectonion.chat.new.skills.disclosure"
    static let chatList = "connectonion.chat.list"
    static let chatInput = "connectonion.chat.input"
    static let chatSendButton = "connectonion.chat.send.button"
    static let chatStopButton = "connectonion.chat.stop.button"
    static let latestMessageEditButton = "connectonion.chat.latest-message.edit"
    static let latestMessageEditor = "connectonion.chat.latest-message.editor"
    static let latestMessageEditCancelButton = "connectonion.chat.latest-message.edit.cancel"
    static let latestMessageEditSaveButton = "connectonion.chat.latest-message.edit.save"
    static let chatAttachmentButton = "connectonion.chat.attachment.button"
    static let chatAttachmentPhotoButton = "connectonion.chat.attachment.photo"
    static let chatAttachmentFilesButton = "connectonion.chat.attachment.files"
    static let chatAttachmentError = "connectonion.chat.attachment.error"
    static let chatVoiceButton = "connectonion.chat.voice.button"
    static let chatVoiceStatus = "connectonion.chat.voice.status"
    static let chatVoiceError = "connectonion.chat.voice.error"
    static let chatSkillPalette = "connectonion.chat.skill.palette"
    static let settingsButton = "connectonion.settings.button"
    static let uiFontPicker = "connectonion.settings.ui-font.picker"
    static let uiFontSizeField = "connectonion.settings.ui-font-size.field"
    static let codeFontPicker = "connectonion.settings.code-font.picker"
    static let codeFontSizeField = "connectonion.settings.code-font-size.field"
    static let personalityPicker = "connectonion.settings.personality.picker"
    static let customInstructionsEditor = "connectonion.settings.custom-instructions.editor"
    static let saveCustomInstructionsButton = "connectonion.settings.custom-instructions.save"
    static let reconnectButton = "connectonion.chat.reconnect.button"
    static let inviteCodeField = "connectonion.onboard.invite"
    static let inviteSubmitButton = "connectonion.onboard.submit"
    static let onboardStatus = "connectonion.onboard.status"
    static let approvalApproveButton = "connectonion.approval.approve"
    static let approvalAlwaysButton = "connectonion.approval.always"
    static let approvalSkipButton = "connectonion.approval.skip"
    static let approvalStatus = "connectonion.approval.status"
    static let askUserAnswerField = "connectonion.ask-user.answer"
    static let askUserSendButton = "connectonion.ask-user.send"
    static let askUserConfirmButton = "connectonion.ask-user.confirm"
    static let askUserSubmitButton = "connectonion.ask-user.submit"
    static let askUserStatus = "connectonion.ask-user.status"
    static let planReviewFeedbackField = "connectonion.plan-review.feedback"
    static let planReviewApproveButton = "connectonion.plan-review.approve"
    static let planReviewReviseButton = "connectonion.plan-review.revise"
    static let planReviewStatus = "connectonion.plan-review.status"

    static func message(_ id: String) -> String {
        "connectonion.chat.message.\(id)"
    }

    static func agent(_ address: String) -> String {
        "connectonion.agent.\(address)"
    }

    static func conversation(_ id: UUID) -> String {
        "connectonion.conversation.\(id.uuidString)"
    }

    static func deleteConversation(_ id: UUID) -> String {
        "connectonion.conversation.delete.\(id.uuidString)"
    }

    static func newChatAgent(_ address: String) -> String {
        "connectonion.chat.new.agent.\(address)"
    }

    static func newChatSuggestion(_ prompt: String) -> String {
        "connectonion.chat.new.suggestion.\(slug(prompt))"
    }

    static func newChatSkill(_ name: String) -> String {
        "connectonion.chat.new.skill.\(slug(name))"
    }

    static func attachmentRemove(_ id: String) -> String {
        "connectonion.chat.attachment.remove.\(normalizedComponent(id))"
    }

    static func chatSkill(_ name: String) -> String {
        "connectonion.chat.skill.\(normalizedComponent(name))"
    }

    static func askUserField(_ name: String) -> String {
        "connectonion.ask-user.field.\(normalizedComponent(name))"
    }

    static func askUserOption(_ option: String) -> String {
        "connectonion.ask-user.option.\(normalizedComponent(option))"
    }

    private static func normalizedComponent(_ value: String) -> String {
        value
            .lowercased()
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? Character($0) : Character("-") }
            .reduce(into: "") { $0.append($1) }
    }

    private static func slug(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }
}
