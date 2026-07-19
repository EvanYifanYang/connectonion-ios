import SwiftUI

struct SidebarSectionTitle: View {
    var title: String

    var body: some View {
        Text(title)
            .brandSerifFont(.headline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.top, 6)
    }
}

#Preview("Sidebar Section Title") {
    SidebarSectionTitle(title: "Agents")
        .padding()
}
