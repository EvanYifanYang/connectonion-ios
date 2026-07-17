import SwiftUI
import WidgetKit

struct ConnectOnionWidget: Widget {
    let kind = "ConnectOnionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ConnectOnionTimelineProvider()) { entry in
            ConnectOnionWidgetView(entry: entry)
        }
        .configurationDisplayName("ConnectOnion")
        .description("Recent agents, quick chats, and QR setup.")
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
    @Environment(\.colorScheme) private var colorScheme
    var entry: ConnectOnionWidgetEntry

    var body: some View {
        Group {
            if let agent = entry.snapshot.agents.first {
                switch family {
                case .systemSmall:
                    SmallAgentWidget(agent: agent)
                default:
                    MediumAgentWidget(agents: Array(entry.snapshot.agents.prefix(3)))
                }
            } else {
                switch family {
                case .systemSmall:
                    SmallEmptyWidget()
                default:
                    MediumEmptyWidget()
                }
            }
        }
        .containerBackground(for: .widget) {
            WidgetPalette.canvas(for: colorScheme)
        }
    }
}

private struct SmallAgentWidget: View {
    @Environment(\.colorScheme) private var colorScheme
    var agent: ConnectOnionAgentShortcut

    private var newChatURL: URL {
        ConnectOnionDeepLink.newChat(agentAddress: agent.address)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Link(destination: newChatURL) {
                WidgetAgentIdentity(agent: agent, avatarSize: 32)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Link(destination: newChatURL) {
                WidgetPrimaryAction(title: "New Chat", systemImage: "plus")
            }
            .buttonStyle(.plain)

            if let suggestion = agent.suggestions.first {
                Link(destination: ConnectOnionDeepLink.newChat(agentAddress: agent.address, suggestion: suggestion)) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(WidgetPalette.onion(for: colorScheme))
                        Text(suggestion)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .imageScale(.small)
                            .foregroundStyle(.tertiary)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 9)
                    .frame(maxWidth: .infinity, minHeight: 27, alignment: .leading)
                    .background(WidgetPalette.elevated(for: colorScheme), in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .widgetURL(newChatURL)
    }
}

private struct MediumAgentWidget: View {
    @Environment(\.colorScheme) private var colorScheme
    var agents: [ConnectOnionAgentShortcut]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                WidgetWordmark()

                Spacer()

                Label("Quick Start", systemImage: "bolt.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(WidgetPalette.onion(for: colorScheme))
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(agents) { agent in
                        Link(destination: ConnectOnionDeepLink.newChat(agentAddress: agent.address)) {
                            WidgetAgentRow(agent: agent)
                                .padding(.horizontal, 7)
                                .frame(maxWidth: .infinity, minHeight: 29, alignment: .leading)
                                .background(WidgetPalette.elevated(for: colorScheme), in: .rect(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let agent = agents.first {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("ASK \(agent.displayName.uppercased())")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        ForEach(Array(agent.suggestions.prefix(2)), id: \.self) { suggestion in
                            Link(destination: ConnectOnionDeepLink.newChat(agentAddress: agent.address, suggestion: suggestion)) {
                                HStack(spacing: 6) {
                                    Text(suggestion)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                    Image(systemName: "arrow.up.right")
                                        .imageScale(.small)
                                }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 8)
                                .frame(maxWidth: .infinity, minHeight: 31, alignment: .leading)
                                .background(
                                    WidgetPalette.onion(for: colorScheme).opacity(0.11),
                                    in: .rect(cornerRadius: 10)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .widgetURL(
            agents.first.map { ConnectOnionDeepLink.newChat(agentAddress: $0.address) }
        )
    }
}

private struct SmallEmptyWidget: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                WidgetBrandMark(size: 31)
                Spacer()
                Image(systemName: "qrcode.viewfinder")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(WidgetPalette.onion(for: colorScheme))
            }

            Text("Add your first agent")
                .font(.system(.headline, design: .serif).weight(.semibold))
                .lineLimit(2)

            Text("Scan its QR code to connect.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Link(destination: ConnectOnionDeepLink.scanAgent()) {
                WidgetPrimaryAction(title: "Scan QR Code", systemImage: "qrcode.viewfinder")
            }
            .buttonStyle(.plain)
        }
        .widgetURL(ConnectOnionDeepLink.scanAgent())
    }
}

private struct MediumEmptyWidget: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                WidgetWordmark()

                Text("Add your first agent")
                    .font(.system(.title3, design: .serif).weight(.semibold))

                Text("Scan an agent QR code to start secure conversations from ConnectOnion.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 31, weight: .semibold))
                    .foregroundStyle(WidgetPalette.onion(for: colorScheme))
                    .frame(width: 58, height: 58)
                    .background(
                        WidgetPalette.onion(for: colorScheme).opacity(0.11),
                        in: .rect(cornerRadius: 18)
                    )

                Link(destination: ConnectOnionDeepLink.scanAgent()) {
                    WidgetPrimaryAction(title: "Scan QR", systemImage: "camera.viewfinder")
                }
                .buttonStyle(.plain)
                .frame(width: 116)
            }
        }
        .widgetURL(ConnectOnionDeepLink.scanAgent())
    }
}

private struct WidgetAgentIdentity: View {
    var agent: ConnectOnionAgentShortcut
    var avatarSize: CGFloat

    var body: some View {
        HStack(spacing: 9) {
            WidgetAgentAvatar(name: agent.displayName, size: avatarSize)

            VStack(alignment: .leading, spacing: 1) {
                Text(agent.displayName)
                    .font(.system(.headline, design: .serif).weight(.semibold))
                    .lineLimit(1)
                Text(agent.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .contentShape(.rect)
    }
}

private struct WidgetAgentRow: View {
    var agent: ConnectOnionAgentShortcut

    var body: some View {
        HStack(spacing: 7) {
            WidgetAgentAvatar(name: agent.displayName, size: 22)

            VStack(alignment: .leading, spacing: 0) {
                Text(agent.displayName)
                    .font(.system(.caption, design: .serif).weight(.semibold))
                    .lineLimit(1)
                Text(agent.subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .contentShape(.rect)
    }
}

private struct WidgetAgentAvatar: View {
    @Environment(\.colorScheme) private var colorScheme
    var name: String
    var size: CGFloat

    var body: some View {
        Text(String(name.first ?? "O").uppercased())
            .font(.system(size: size * 0.4, weight: .bold))
            .foregroundStyle(WidgetPalette.canvas(for: colorScheme))
            .frame(width: size, height: size)
            .background(.primary, in: .rect(cornerRadius: size * 0.3))
    }
}

private struct WidgetPrimaryAction: View {
    @Environment(\.colorScheme) private var colorScheme
    var title: String
    var systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
                .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right")
                .imageScale(.small)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 29, alignment: .leading)
        .background(WidgetPalette.onion(for: colorScheme), in: .capsule)
        .contentShape(.capsule)
    }
}

private struct WidgetWordmark: View {
    var body: some View {
        HStack(spacing: 6) {
            WidgetBrandMark(size: 22)
            Text("ConnectOnion")
                .font(.system(.subheadline, design: .serif).weight(.semibold))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ConnectOnion")
    }
}

private struct WidgetBrandMark: View {
    @Environment(\.colorScheme) private var colorScheme
    var size: CGFloat

    var body: some View {
        Image("Onion")
            .resizable()
            .scaledToFit()
            .padding(size * 0.16)
            .background(
                WidgetPalette.onion(for: colorScheme).opacity(0.12),
                in: .rect(cornerRadius: size * 0.3)
            )
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private enum WidgetPalette {
    static func canvas(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.149, green: 0.145, blue: 0.137)
            : Color(red: 0.980, green: 0.976, blue: 0.961)
    }

    static func elevated(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.204, green: 0.196, blue: 0.184)
            : .white
    }

    static func onion(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.545, green: 0.467, blue: 1.000)
            : Color(red: 0.431, green: 0.337, blue: 0.949)
    }
}

#Preview("Small · Agent", as: .systemSmall) {
    ConnectOnionWidget()
} timeline: {
    ConnectOnionWidgetEntry(date: .now, snapshot: .placeholder)
}

#Preview("Medium · Agents", as: .systemMedium) {
    ConnectOnionWidget()
} timeline: {
    ConnectOnionWidgetEntry(date: .now, snapshot: .placeholder)
}

#Preview("Small · Scan Agent", as: .systemSmall) {
    ConnectOnionWidget()
} timeline: {
    ConnectOnionWidgetEntry(date: .now, snapshot: .empty)
}

#Preview("Medium · Scan Agent", as: .systemMedium) {
    ConnectOnionWidget()
} timeline: {
    ConnectOnionWidgetEntry(date: .now, snapshot: .empty)
}
