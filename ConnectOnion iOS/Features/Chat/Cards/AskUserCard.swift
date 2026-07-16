import SwiftUI

struct AskUserCard: View {
    var item: ChatItem
    var isPending: Bool
    var onResponse: (String) -> Void

    @State private var text = ""
    @State private var selectedOptions: Set<String> = []
    @State private var fieldValues: [String: String] = [:]
    @State private var feedbackTrigger = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(item.content, systemImage: "questionmark.circle")
                .font(.headline)
                .labelStyle(.titleAndIcon)

            if isPending {
                if !item.fields.isEmpty {
                    fieldsView
                } else {
                    if !item.options.isEmpty {
                        optionsView
                    }

                    HStack(spacing: 8) {
                        TextField("Answer", text: $text)
                            .textFieldStyle(.plain)
                            .submitLabel(.send)
                            .onSubmit(submitText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(.secondary.opacity(0.08), in: .rect(cornerRadius: 12))
                            .accessibilityIdentifier(AccessibilityID.askUserAnswerField)

                        Button("Send", systemImage: "paperplane.fill", action: submitText)
                            .labelStyle(.iconOnly)
                            .frame(width: 44, height: 44)
                            .buttonStyle(.glassProminent)
                            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier(AccessibilityID.askUserSendButton)
                    }
                }
            } else if let answer = item.answer {
                Label(answer, systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.green)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(AccessibilityID.askUserStatus)
                    .transition(AppMotion.panelTransition)
            }
        }
        .padding(14)
        .frame(maxWidth: 560, alignment: .leading)
        .glassSurface(cornerRadius: 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 42)
        .padding(.vertical, 5)
        .animation(AppMotion.standard, value: item.answer)
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
    }

    private var fieldsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button("Submit", systemImage: "checkmark", action: submitFields)
                .buttonStyle(.glassProminent)
                .disabled(hasMissingRequiredField)
                .accessibilityIdentifier(AccessibilityID.askUserSubmitButton)

            ForEach(item.fields) { field in
                if field.type == .password {
                    SecureField(field.label, text: binding(for: field.name))
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit {
                            if !hasMissingRequiredField {
                                submitFields()
                            }
                        }
                        .accessibilityIdentifier(AccessibilityID.askUserField(field.name))
                } else {
                    TextField(field.label, text: binding(for: field.name))
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.next)
                        .accessibilityIdentifier(AccessibilityID.askUserField(field.name))
                }
            }
        }
    }

    private var optionsView: some View {
        VStack(spacing: 8) {
            ForEach(item.options, id: \.self) { option in
                Button {
                    toggle(option)
                } label: {
                    Label(option, systemImage: selectedOptions.contains(option) ? "checkmark.circle.fill" : "circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.glass)
                .accessibilityIdentifier(AccessibilityID.askUserOption(option))
            }

            if item.multiSelect {
                Button("Confirm", systemImage: "checkmark", action: submitOptions)
                    .buttonStyle(.glassProminent)
                    .disabled(selectedOptions.isEmpty)
                    .accessibilityIdentifier(AccessibilityID.askUserConfirmButton)
            }
        }
    }

    private var hasMissingRequiredField: Bool {
        item.fields.contains { field in
            field.required != false && (fieldValues[field.name] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func binding(for key: String) -> Binding<String> {
        Binding {
            fieldValues[key] ?? ""
        } set: { value in
            fieldValues[key] = value
        }
    }

    private func toggle(_ option: String) {
        feedbackTrigger += 1
        if item.multiSelect {
            if selectedOptions.contains(option) {
                selectedOptions.remove(option)
            } else {
                selectedOptions.insert(option)
            }
        } else {
            onResponse(option)
        }
    }

    private func submitText() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        feedbackTrigger += 1
        onResponse(trimmed)
        text = ""
    }

    private func submitOptions() {
        guard !selectedOptions.isEmpty else { return }
        feedbackTrigger += 1
        onResponse(selectedOptions.sorted().joined(separator: ", "))
    }

    private func submitFields() {
        guard !hasMissingRequiredField else { return }
        feedbackTrigger += 1
        let object = item.fields.reduce(into: [String: JSONValue]()) { partialResult, field in
            partialResult[field.name] = .string(fieldValues[field.name] ?? "")
        }
        let answer = (try? object.jsonString(sortedKeys: true)) ?? "{}"
        onResponse(answer)
    }
}

#Preview("Ask User Options") {
    AskUserCard(item: PreviewFixtures.sampleAskUser, isPending: true, onResponse: { _ in })
        .padding()
}

#Preview("Ask User Fields") {
    AskUserCard(item: PreviewFixtures.sampleAskUserFields, isPending: true, onResponse: { _ in })
        .padding()
}
