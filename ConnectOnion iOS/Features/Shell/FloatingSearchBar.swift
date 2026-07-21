//
//  FloatingSearchBar.swift
//
//  Purpose: Implements FloatingSearchBar for the Features/Shell module.
//  Collaborates with: AgentAvatar, AgentListView, AgentSidebarRow, AppShellView, ConnectOnionWordmark, ConversationSidebarRow.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

/// The floating pill search bar that sits under the bottom-right action button (Claude-style):
/// a full-width glass capsule with a magnifier, live text, and a clear button.
struct FloatingSearchBar: View {
    @Binding var text: String
    var prompt: String = "Search"
    var accessibilityID: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("", text: $text)
                .textFieldStyle(.plain)
                .tint(.primary)
                .autocorrectionDisabled()
                .submitLabel(.search)
                // Custom placeholder — the system one (~30% primary) is barely legible on glass.
                .overlay(alignment: .leading) {
                    if text.isEmpty {
                        Text(prompt)
                            .foregroundStyle(Color(.systemGray))
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityIdentifier(accessibilityID ?? "connectonion.search.field")

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .glassSurface(cornerRadius: 26)
    }
}

#Preview("Floating Search Bar") {
    @Previewable @State var text = ""
    VStack {
        Spacer()
        FloatingSearchBar(text: $text, prompt: "Search")
            .padding(20)
    }
    .background(Color.appCanvas)
}
