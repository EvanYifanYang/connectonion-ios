import AppIntents
import SwiftUI
import WidgetKit

struct ConnectOnionWidget: Widget {
    let kind = "ConnectOnionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ConnectOnionTimelineProvider()) { entry in
            ConnectOnionWidgetView(entry: entry)
        }
        .configurationDisplayName("ConnectOnion")
        .description("Recent agents and suggested prompts.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ConnectOnionTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ConnectOnionWidgetEntry {
        ConnectOnionWidgetEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ConnectOnionWidgetEntry) -> Void) {
        let snapshot = context.isPreview ? .placeholder : ConnectOnionWidgetSnapshotStore.load()
        completion(ConnectOnionWidgetEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ConnectOnionWidgetEntry>) -> Void) {
        let entry = ConnectOnionWidgetEntry(date: .now, snapshot: ConnectOnionWidgetSnapshotStore.load())
        completion(Timeline(entries: [entry], policy: .after(.now + 15 * 60)))
    }
}

struct ConnectOnionWidgetEntry: TimelineEntry {
    var date: Date
    var snapshot: ConnectOnionWidgetSnapshot
}

struct ConnectOnionWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: ConnectOnionWidgetEntry

    var body: some View {
        if let agent = entry.snapshot.agents.first {
            switch family {
            case .systemSmall:
                SmallAgentWidget(agent: agent)
            default:
                MediumAgentWidget(agents: Array(entry.snapshot.agents.prefix(3)))
            }
        } else {
            EmptyWidgetView()
        }
    }
}

private struct SmallAgentWidget: View {
    var agent: ConnectOnionAgentShortcut

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Link(destination: ConnectOnionDeepLink.newChat(agentAddress: agent.address)) {
                WidgetHeader(agent: agent)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button(intent: StartSuggestedChatIntent(agentAddress: agent.address, suggestion: nil)) {
                Label("New chat", systemImage: "plus.bubble")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderedProminent)

            if let suggestion = agent.suggestions.first {
                Button(intent: StartSuggestedChatIntent(agentAddress: agent.address, suggestion: suggestion)) {
                    Text(suggestion)
                        .font(.caption.weight(.medium))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

private struct MediumAgentWidget: View {
    var agents: [ConnectOnionAgentShortcut]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(agents) { agent in
                    Link(destination: ConnectOnionDeepLink.newChat(agentAddress: agent.address)) {
                        WidgetAgentRow(agent: agent)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let agent = agents.first {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(agent.suggestions.prefix(3)), id: \.self) { suggestion in
                        Link(destination: ConnectOnionDeepLink.newChat(agentAddress: agent.address, suggestion: suggestion)) {
                            Text(suggestion)
                                .font(.caption.weight(.medium))
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(.fill.tertiary)
                                .clipShape(.rect(cornerRadius: 8))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

private struct EmptyWidgetView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("ConnectOnion")
                .font(.headline)

            Button(intent: StartSuggestedChatIntent(agentAddress: "", suggestion: nil)) {
                Label("Add agent", systemImage: "plus")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderedProminent)
        }
        .containerBackground(.background, for: .widget)
    }
}

private struct WidgetHeader: View {
    var agent: ConnectOnionAgentShortcut

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(.green.opacity(0.16))
                Text(String(agent.displayName.prefix(1)).uppercased())
                    .font(.caption.weight(.bold))
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(agent.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text(agent.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct WidgetAgentRow: View {
    var agent: ConnectOnionAgentShortcut

    var body: some View {
        HStack(spacing: 8) {
            Text(String(agent.displayName.prefix(1)).uppercased())
                .font(.caption.weight(.bold))
                .frame(width: 24, height: 24)
                .background(.green.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(agent.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(agent.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview(as: .systemSmall) {
    ConnectOnionWidget()
} timeline: {
    ConnectOnionWidgetEntry(date: .now, snapshot: .placeholder)
}

#Preview(as: .systemMedium) {
    ConnectOnionWidget()
} timeline: {
    ConnectOnionWidgetEntry(date: .now, snapshot: .placeholder)
}
