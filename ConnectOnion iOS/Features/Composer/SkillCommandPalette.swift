import SwiftUI

struct SkillCommandPalette: View {
    var skills: [SkillInfo]
    var onSelect: (SkillInfo) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(skills) { skill in
                Button {
                    onSelect(skill)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("/\(skill.name)")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .frame(minWidth: 76, alignment: .leading)

                        Text(skill.description)
                            .font(.caption)
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

                if skill.id != skills.last?.id {
                    Divider()
                        .padding(.leading, 12)
                }
            }
        }
        .glassSurface(cornerRadius: 18, isInteractive: true)
        .accessibilityIdentifier(AccessibilityID.chatSkillPalette)
    }
}
