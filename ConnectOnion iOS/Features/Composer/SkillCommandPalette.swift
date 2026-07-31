//
//  SkillCommandPalette.swift
//
//  Purpose: Implements SkillCommandPalette for the Features/Composer module.
//  Collaborates with: AttachmentSheet, AttachmentStrip, CameraPicker, ChatInputBar, ComposerAttachmentPreviews, RecentPhotos.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

struct SkillCommandPalette: View {
    private static let visibleSkillLimit = 6

    var skills: [SkillInfo]
    var onSelect: (SkillInfo) -> Void

    var body: some View {
        // The hidden six-row copy preserves the palette's existing, Dynamic-Type-aware viewport.
        // The full list overlays that exact footprint and scrolls without growing the composer.
        skillRows(Array(skills.prefix(Self.visibleSkillLimit)))
            .hidden()
            .accessibilityHidden(true)
            .overlay {
                ScrollView(.vertical) {
                    skillRows(skills)
                }
                .scrollIndicators(.visible)
                .scrollBounceBehavior(.basedOnSize)
            }
            .glassSurface(cornerRadius: 18, isInteractive: true)
            .accessibilityIdentifier(AccessibilityID.chatSkillPalette)
    }

    private func skillRows(_ visibleSkills: [SkillInfo]) -> some View {
        VStack(spacing: 0) {
            ForEach(visibleSkills) { skill in
                Button {
                    onSelect(skill)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("/\(skill.name)")
                            .appFont(.footnote, weight: .semibold)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .frame(minWidth: 76, alignment: .leading)

                        Text(skill.description)
                            .appFont(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityID.chatSkill(skill.name))

                if skill.id != visibleSkills.last?.id {
                    Divider()
                        .padding(.leading, 12)
                }
            }
        }
    }
}
