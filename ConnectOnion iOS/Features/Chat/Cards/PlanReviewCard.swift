import SwiftUI

struct PlanReviewCard: View {
    var item: ChatItem
    var isPending: Bool
    var onResponse: (String) -> Void

    @State private var feedback = ""
    @State private var isExpanded = true
    @State private var feedbackTrigger = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                feedbackTrigger += 1
                withAnimation(.smooth(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                Label("Plan review", systemImage: "list.bullet.clipboard")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if isPending {
                HStack(spacing: 8) {
                    Button("Approve", systemImage: "checkmark", action: approvePlan)
                    .buttonStyle(.glassProminent)
                    .accessibilityIdentifier(AccessibilityID.planReviewApproveButton)

                    Button("Revise", systemImage: "arrow.uturn.backward", action: revisePlan)
                        .buttonStyle(.glass)
                        .accessibilityIdentifier(AccessibilityID.planReviewReviseButton)
                }
            }

            if isExpanded {
                Text(.init(item.planContent ?? ""))
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(.secondary.opacity(0.08), in: .rect(cornerRadius: 12))
            }

            if isPending {
                TextField("Feedback", text: $feedback, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit(revisePlan)
                    .accessibilityIdentifier(AccessibilityID.planReviewFeedbackField)
            } else if let answer = item.answer {
                Label(answer, systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.green)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(AccessibilityID.planReviewStatus)
                    .transition(AppMotion.panelTransition)
            }
        }
        .padding(14)
        .frame(maxWidth: 640, alignment: .leading)
        .glassSurface(cornerRadius: 18, tint: .blue.opacity(0.06), isInteractive: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 42)
        .padding(.vertical, 5)
        .animation(AppMotion.standard, value: isExpanded)
        .animation(AppMotion.standard, value: item.answer)
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
    }

    private func approvePlan() {
        feedbackTrigger += 1
        onResponse("Plan approved. Implement now. Do NOT re-enter plan mode.")
    }

    private func revisePlan() {
        let message = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        feedbackTrigger += 1
        onResponse(message.isEmpty ? "Plan needs revision." : message)
    }
}

#Preview("Plan Review") {
    PlanReviewCard(item: PreviewFixtures.samplePlanReview, isPending: true, onResponse: { _ in })
        .padding()
}
