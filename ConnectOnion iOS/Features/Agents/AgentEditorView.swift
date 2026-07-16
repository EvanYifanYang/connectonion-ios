import SwiftUI

struct AgentEditorView: View {
    @Environment(\.dismiss) private var dismiss

    var title: String
    var isAddressEditable: Bool
    var onSave: (String, String, URL?) -> Void

    @State private var address = ""
    @State private var alias = ""
    @State private var endpoint = ""
    @State private var feedbackTrigger = 0

    init(
        title: String = "Agent",
        initialAddress: String = "",
        initialAlias: String = "",
        initialEndpoint: URL? = nil,
        isAddressEditable: Bool = true,
        onSave: @escaping (String, String, URL?) -> Void
    ) {
        self.title = title
        self.isAddressEditable = isAddressEditable
        self.onSave = onSave
        _address = State(initialValue: initialAddress)
        _alias = State(initialValue: initialAlias)
        _endpoint = State(initialValue: initialEndpoint?.absoluteString ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Agent address", text: $address)
                        .font(.body.monospaced())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(!isAddressEditable)
                        .accessibilityIdentifier(AccessibilityID.addAgentAddressField)

                    TextField("Name", text: $alias)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier(AccessibilityID.addAgentAliasField)

                    TextField("Endpoint", text: $endpoint)
                        .font(.body.monospaced())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .accessibilityIdentifier(AccessibilityID.addAgentEndpointField)
                }
            }
            // Keep text-entry neutral (black caret/selection) app-wide; purple is reserved for the
            // primary action below, so the field itself doesn't read as "flashy".
            .tint(.primary)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        feedbackTrigger += 1
                        dismiss()
                    }
                }

                // Symmetric to Cancel: a bold accent "Save" on the trailing side (no bottom button).
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                        .accessibilityIdentifier(AccessibilityID.saveAgentButton)
                }
            }
            .sensoryFeedback(.selection, trigger: feedbackTrigger)
        }
        // A compact bottom sheet sized to the fields (no wasted vertical space), still draggable up
        // to full height, with the standard grabber.
        .presentationDetents([.height(300), .large])
        .presentationDragIndicator(.visible)
    }

    private var canSave: Bool {
        AgentAddress.isValid(address) && normalizedEndpointURL != nil
    }

    private var normalizedEndpointURL: URL?? {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .some(nil) }

        let candidate = trimmed.contains("://") ? trimmed : "http://\(trimmed)"
        guard var components = URLComponents(string: candidate), let scheme = components.scheme?.lowercased() else {
            return nil
        }

        switch scheme {
        case "http", "https":
            break
        case "ws":
            components.scheme = "http"
        case "wss":
            components.scheme = "https"
        default:
            return nil
        }

        guard components.host != nil else { return nil }

        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path == "info" || path == "ws" {
            components.path = ""
        }
        components.query = nil
        components.fragment = nil

        guard let url = components.url else { return nil }
        return .some(url)
    }

    private func save() {
        guard case .some(let endpointURL) = normalizedEndpointURL else { return }
        feedbackTrigger += 1
        onSave(address, alias, endpointURL)
        dismiss()
    }
}

#Preview("Add Agent") {
    AgentEditorView { _, _, _ in }
}

#Preview("Edit Agent") {
    AgentEditorView(
        title: "Edit Agent",
        initialAddress: PreviewFixtures.testAgentAddress,
        initialAlias: "OpenOnion",
        initialEndpoint: URL(string: "http://192.168.50.16:8000"),
        isAddressEditable: false
    ) { _, _, _ in }
}
