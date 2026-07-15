import SwiftUI

struct StatusPill: View {
    var systemImage: String
    var text: String
    var tint: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.footnote)
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassSurface(cornerRadius: 14, tint: tint.opacity(0.08))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 42)
            .padding(.vertical, 4)
    }
}

#Preview("Status Pill") {
    StatusPill(systemImage: "checkmark.circle", text: "Connected", tint: .green)
        .padding()
}
