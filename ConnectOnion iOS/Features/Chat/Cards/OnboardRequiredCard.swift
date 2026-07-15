import SwiftUI

struct OnboardRequiredCard: View {
    var item: ChatItem
    var isPending: Bool
    var onSubmit: (String?, Double?) -> Void

    @State private var inviteCode = ""
    @State private var feedbackTrigger = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Verification required", systemImage: "lock")
                .font(.headline)

            if isPending {
                if item.methods.contains("invite_code") {
                    HStack(spacing: 8) {
                        TextField("Invite code", text: $inviteCode)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.plain)
                            .submitLabel(.continue)
                            .onSubmit(submitInvite)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(.secondary.opacity(0.08), in: .rect(cornerRadius: 12))
                            .accessibilityIdentifier(AccessibilityID.inviteCodeField)

                        Button("Continue", systemImage: "arrow.right", action: submitInvite)
                            .labelStyle(.iconOnly)
                            .frame(width: 44, height: 44)
                            .buttonStyle(.glassProminent)
                            .disabled(inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier(AccessibilityID.inviteSubmitButton)
                    }
                }

                if let paymentAmount = item.paymentAmount {
                    Button("Pay \(paymentAmount, format: .currency(code: "USD"))", systemImage: "creditcard") {
                        feedbackTrigger += 1
                        onSubmit(nil, paymentAmount)
                    }
                    .buttonStyle(.glass)
                }
            } else if let answer = item.answer {
                Label(answer, systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.green)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(AccessibilityID.onboardStatus)
                    .transition(AppMotion.panelTransition)
            }
        }
        .padding(14)
        .frame(maxWidth: 560, alignment: .leading)
        .glassSurface(cornerRadius: 18, tint: .orange.opacity(0.08), isInteractive: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 42)
        .padding(.vertical, 5)
        .animation(AppMotion.standard, value: item.answer)
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
    }

    private func submitInvite() {
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        feedbackTrigger += 1
        onSubmit(code, nil)
    }
}

#Preview("Onboard Required") {
    OnboardRequiredCard(item: PreviewFixtures.sampleOnboardRequired, isPending: true, onSubmit: { _, _ in })
        .padding()
}
