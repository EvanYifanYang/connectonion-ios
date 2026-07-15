import SwiftUI

struct PromptSuggestionStrip: View {
    var suggestions: [String]
    var onSelect: (String) -> Void

    @State private var feedbackTrigger = 0

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        feedbackTrigger += 1
                        onSelect(suggestion)
                    }
                    .buttonStyle(.glass)
                    .accessibilityIdentifier(AccessibilityID.suggestion(suggestion))
                    .transition(AppMotion.panelTransition)
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .animation(AppMotion.standard, value: suggestions)
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
    }
}

#Preview("Prompt Suggestions") {
    PromptSuggestionStrip(
        suggestions: AgentPromptSuggestions.defaults,
        onSelect: { _ in }
    )
    .padding(.vertical)
}
