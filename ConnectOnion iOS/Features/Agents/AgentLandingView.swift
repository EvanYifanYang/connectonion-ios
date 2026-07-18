import SwiftUI
import SwiftData
import UIKit

struct AgentLandingView: View {
    var agent: AgentConfigRecord
    var info: AgentInfo?
    var onSend: (AgentInput) -> Void

    private static let suggestions = [
        "What can you do?",
        "Help me plan my day"
    ]

    private static let greetings = [
        "What shall we think through?",
        "How can I help you?",
        "Where should we start?",
        "What's on your mind?",
        "Ready when you are",
        "Good to see you"
    ]
    // Picked once per landing appearance so the greeting varies between new chats but stays put while
    // you're on the screen.
    @State private var greeting = AgentLandingView.greetings.randomElement() ?? "How can I help you?"

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 30) {
                        // The brand logo over a single warm, serif greeting — no repeated agent hero.
                        // The onion assembles itself layer-by-layer when the landing appears.
                        VStack(spacing: 18) {
                            OnionRevealView(trigger: greeting)
                                .frame(width: 60, height: 60)
                            Text(greeting)
                                .appFont(.title, weight: .medium)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .multilineTextAlignment(.center)
                        }

                        LandingSuggestions(suggestions: Self.suggestions) { suggestion in
                            onSend(AgentInput(prompt: suggestion))
                        }

                        AgentLandingCapabilities(
                            tools: info?.tools ?? [],
                            skills: info?.skills ?? []
                        )
                    }
                    .frame(maxWidth: 540)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                    .frame(minHeight: geometry.size.height, alignment: .center)
                }
                .scrollDismissesKeyboard(.interactively)
            }

            LandingComposer(
                acceptedInputs: info?.acceptedInputs,
                skills: info?.skills ?? [],
                onSend: { prompt, images, files in
                    onSend(AgentInput(prompt: prompt, images: images, files: files))
                }
            )
        }
        // Tapping the empty area (anywhere outside the composer's controls) dismisses the keyboard.
        .contentShape(.rect)
        .onTapGesture { dismissKeyboard() }
        .background(Color.appCanvas.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private struct LandingSuggestions: View {
    var suggestions: [String]
    var onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    onSelect(suggestion)
                } label: {
                    Text(suggestion)
                        .appFont(.subheadline, weight: .medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(AppTheme.contrastForeground)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(AppTheme.contrastFill, in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(suggestion)
                .accessibilityHint("Starts a new conversation with this prompt")
                .accessibilityIdentifier(AccessibilityID.newChatSuggestion(suggestion))
            }
        }
    }
}

private struct AgentLandingCapabilities: View {
    var tools: [String]
    var skills: [SkillInfo]
    var toolsInitiallyExpanded = false
    var skillsInitiallyExpanded = false

    var body: some View {
        VStack(spacing: 24) {
            if !tools.isEmpty {
                ToolSummary(tools: tools, initiallyExpanded: toolsInitiallyExpanded)
            }
            if !skills.isEmpty {
                SkillSummary(skills: skills, initiallyExpanded: skillsInitiallyExpanded)
            }
        }
        .frame(maxWidth: 460)
    }
}

private struct ToolSummary: View {
    private let visibleLimit = 6

    var tools: [String]
    @State private var isExpanded: Bool

    init(tools: [String], initiallyExpanded: Bool) {
        self.tools = tools
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        VStack(spacing: 12) {
            disclosureButton

            if isExpanded {
                Text(summary)
                    .appFont(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(AccessibilityID.newChatToolsSummary)
                    .transition(AppMotion.panelTransition)
            }
        }
    }

    private var disclosureButton: some View {
        Button {
            withAnimation(AppMotion.quick) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 7) {
                Text("\(tools.count) \(tools.count == 1 ? "tool" : "tools")")
                    .appFont(.footnote, weight: .medium)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(QuietPressButtonStyle())
        .accessibilityLabel("\(tools.count) \(tools.count == 1 ? "tool" : "tools"), \(isExpanded ? "expanded" : "collapsed")")
        .accessibilityHint(isExpanded ? "Collapses the tool list" : "Expands the tool list")
        .accessibilityIdentifier(AccessibilityID.newChatToolsDisclosure)
    }

    private var summary: String {
        var parts = Array(tools.prefix(visibleLimit))
        let remainingCount = tools.count - parts.count
        if remainingCount > 0 {
            parts.append("+\(remainingCount) more")
        }
        return parts.joined(separator: " · ")
    }
}

private struct SkillSummary: View {
    private let visibleLimit = 3

    var skills: [SkillInfo]
    @State private var isExpanded: Bool

    init(skills: [SkillInfo], initiallyExpanded: Bool) {
        self.skills = skills
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        VStack(spacing: 12) {
            disclosureButton

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(skills.prefix(visibleLimit))) { skill in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(skill.name)
                                .appFont(.footnote, weight: .semibold)
                                .foregroundStyle(.primary)
                            Text(skill.description)
                                .appFont(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier(AccessibilityID.newChatSkill(skill.name))
                    }

                    let remainingCount = skills.count - min(skills.count, visibleLimit)
                    if remainingCount > 0 {
                        Text("+\(remainingCount) more")
                            .appFont(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.horizontal, 18)
                .transition(AppMotion.panelTransition)
            }
        }
    }

    private var disclosureButton: some View {
        Button {
            withAnimation(AppMotion.quick) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 7) {
                Text("\(skills.count) \(skills.count == 1 ? "skill" : "skills")")
                    .appFont(.footnote, weight: .medium)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(QuietPressButtonStyle())
        .accessibilityLabel("\(skills.count) \(skills.count == 1 ? "skill" : "skills"), \(isExpanded ? "expanded" : "collapsed")")
        .accessibilityHint(isExpanded ? "Collapses the skill list" : "Expands the skill list")
        .accessibilityIdentifier(AccessibilityID.newChatSkillsDisclosure)
    }
}

#Preview("Agent Landing") {
    let _ = PreviewFixtures.installMockDependencies()
    let container = PreviewFixtures.seededContainer()
    if let agent = try? container.mainContext.fetch(FetchDescriptor<AgentConfigRecord>()).first {
        AgentLandingView(agent: agent, info: agent.cachedInfo) { _ in }
            .modelContainer(container)
    } else {
        Text("Preview unavailable")
    }
}

#Preview("Agent Landing Without Metadata") {
    let agent = AgentConfigRecord(address: PreviewFixtures.testAgentAddress, alias: "OpenOnion")
    AgentLandingView(agent: agent, info: nil) { _ in }
        .modelContainer(PreviewFixtures.container())
}

#Preview("Landing Capabilities Collapsed") {
    AgentLandingCapabilities(
        tools: PreviewFixtures.sampleAgentInfo.tools,
        skills: PreviewFixtures.sampleSkills,
        toolsInitiallyExpanded: false,
        skillsInitiallyExpanded: false
    )
    .padding()
    .background(Color.appCanvas)
}

#Preview("Landing Capabilities Long Lists") {
    AgentLandingCapabilities(
        tools: PreviewFixtures.sampleAgentInfo.tools,
        skills: PreviewFixtures.sampleSkills,
        toolsInitiallyExpanded: true,
        skillsInitiallyExpanded: true
    )
    .padding()
    .background(Color.appCanvas)
}
