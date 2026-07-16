import SwiftUI

struct ApprovalButtons: View {
    var onResponse: (Bool, String, String?, String?) -> Void

    @State private var response: String?
    @State private var feedbackTrigger = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    approvalButton(title: "Approve", systemImage: "checkmark", id: AccessibilityID.approvalApproveButton, isProminent: true) {
                        submit("Approved", approved: true, scope: "once", mode: nil)
                    }

                    approvalButton(title: "Always", systemImage: "checkmark.seal", id: AccessibilityID.approvalAlwaysButton, isProminent: false) {
                        submit("Approved for session", approved: true, scope: "session", mode: nil)
                    }

                    approvalButton(title: "Skip", systemImage: "forward", id: AccessibilityID.approvalSkipButton, isProminent: false) {
                        submit("Skipped", approved: false, scope: "once", mode: "reject_soft")
                    }
                }

                VStack(spacing: 8) {
                    approvalButton(title: "Approve", systemImage: "checkmark", id: AccessibilityID.approvalApproveButton, isProminent: true) {
                        submit("Approved", approved: true, scope: "once", mode: nil)
                    }

                    approvalButton(title: "Always", systemImage: "checkmark.seal", id: AccessibilityID.approvalAlwaysButton, isProminent: false) {
                        submit("Approved for session", approved: true, scope: "session", mode: nil)
                    }

                    approvalButton(title: "Skip", systemImage: "forward", id: AccessibilityID.approvalSkipButton, isProminent: false) {
                        submit("Skipped", approved: false, scope: "once", mode: "reject_soft")
                    }
                }
                .frame(maxWidth: 260)
            }
            .disabled(response != nil)

            if let response {
                Label(response, systemImage: response == "Skipped" ? "forward.fill" : "checkmark.circle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(response == "Skipped" ? Color.secondary : Color.green)
                    .accessibilityIdentifier(AccessibilityID.approvalStatus)
                    .transition(AppMotion.panelTransition)
            }
        }
        .animation(AppMotion.standard, value: response)
        .sensoryFeedback(.success, trigger: feedbackTrigger)
    }

    @ViewBuilder
    private func approvalButton(title: String, systemImage: String, id: String, isProminent: Bool, action: @escaping () -> Void) -> some View {
        let button = Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.body.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .accessibilityIdentifier(id)

        if isProminent {
            button.buttonStyle(.glassProminent)
        } else {
            button.buttonStyle(.glass)
        }
    }

    private func submit(_ label: String, approved: Bool, scope: String, mode: String?) {
        feedbackTrigger += 1
        response = label
        onResponse(approved, scope, mode, nil)
    }
}

#Preview("Approval Buttons") {
    ApprovalButtons(onResponse: { _, _, _, _ in })
        .padding()
}
