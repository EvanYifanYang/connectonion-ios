//
//  UserBubble.swift
//
//  Purpose: Implements UserBubble for the Features/Chat/Timeline module.
//  Collaborates with: AgentActivityGroup, AgentBubble, ActivityStep, ActivityStepRow.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

struct UserBubble: View {
    var item: ChatItem
    var canEdit = false
    var isEditing = false
    var onBeginEditing: () -> Void = {}
    var onCancelEditing: () -> Void = {}
    var onSaveEditing: (String) -> Bool = { _ in false }

    @State private var draft = ""
    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if !item.images.isEmpty || !item.files.isEmpty {
                AttachmentStrip(images: item.images, files: item.files)
            }

            if isEditing {
                editor
            } else if !item.content.isEmpty {
                Text(.init(item.content))
                    .appFont(.body)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.appUserBubble, in: .rect(cornerRadius: AppTheme.bubbleCornerRadius))
                    .frame(maxWidth: 620, alignment: .trailing)
            }

            if canEdit, !isEditing {
                Button("Edit message", systemImage: "pencil", action: onBeginEditing)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityID.latestMessageEditButton)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.vertical, 5)
        .onChange(of: isEditing) { _, nowEditing in
            if nowEditing {
                draft = item.content
                Task { @MainActor in
                    await Task.yield()
                    editorFocused = true
                }
            } else {
                editorFocused = false
            }
        }
    }

    private var normalizedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        normalizedDraft != item.content.trimmingCharacters(in: .whitespacesAndNewlines) &&
            (!normalizedDraft.isEmpty || !item.images.isEmpty || !item.files.isEmpty)
    }

    private var editor: some View {
        VStack(alignment: .trailing, spacing: 10) {
            TextEditor(text: $draft)
                .appFont(.body)
                .scrollContentBackground(.hidden)
                .focused($editorFocused)
                .frame(minHeight: 110)
                .padding(10)
                .background(Color.appElevated2, in: .rect(cornerRadius: AppTheme.bubbleCornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.bubbleCornerRadius)
                        .strokeBorder(Color.onion.opacity(0.45), lineWidth: 1)
                }
                .accessibilityLabel("Edit latest message")
                .accessibilityIdentifier(AccessibilityID.latestMessageEditor)

            HStack(spacing: 10) {
                Button("Cancel") {
                    draft = item.content
                    editorFocused = false
                    onCancelEditing()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier(AccessibilityID.latestMessageEditCancelButton)

                Button("Save & Regenerate") {
                    if onSaveEditing(normalizedDraft) {
                        editorFocused = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .accessibilityIdentifier(AccessibilityID.latestMessageEditSaveButton)
            }
        }
        .frame(maxWidth: 620, alignment: .trailing)
    }
}

#Preview("User Bubble") {
    UserBubble(item: PreviewFixtures.sampleUserMessage)
        .padding()
}
