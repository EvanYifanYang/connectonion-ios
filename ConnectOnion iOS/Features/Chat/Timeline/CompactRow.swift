import SwiftUI

struct CompactRow: View {
    var item: ChatItem

    var body: some View {
        StatusPill(
            systemImage: item.status == .error ? "exclamationmark.triangle" : "archivebox",
            text: item.content.nilIfEmpty ?? "Compacting context",
            tint: item.status == .error ? .red : .secondary
        )
    }
}

#Preview("Compact Row") {
    CompactRow(item: PreviewFixtures.sampleCompact)
        .padding()
}
