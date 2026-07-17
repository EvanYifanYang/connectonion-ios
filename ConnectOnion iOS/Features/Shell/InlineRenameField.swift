import SwiftUI

/// A single-line, inline title editor used in sidebar rows: it focuses itself (raising the keyboard)
/// as soon as it appears, and commits on Return **or** when it loses focus (the user taps elsewhere).
/// Both paths can fire during teardown, so callers must make their commit idempotent.
struct InlineRenameField: View {
    @Binding var text: String
    var accessibilityID: String
    var onCommit: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $text)
            .font(.body)
            .textFieldStyle(.plain)
            .tint(.primary)
            .submitLabel(.done)
            .autocorrectionDisabled()
            .focused($focused)
            .onSubmit(onCommit)
            .onChange(of: focused) { _, isFocused in
                if !isFocused { onCommit() }
            }
            .accessibilityIdentifier(accessibilityID)
            .task { focused = true }
    }
}
