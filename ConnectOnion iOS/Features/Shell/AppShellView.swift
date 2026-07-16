import SwiftData
import SwiftUI
import UIKit
import WidgetKit

/// Agent-centric navigation levels (P4): the root lists agents, tapping one pushes its home (chat
/// list), and a chat / a fresh-chat landing push on top of that.
enum ShellRoute: Hashable {
    case agentHome(String)   // agent address
    case newChat(String)     // agent address — a fresh landing/composer
    case conversation(UUID)  // conversation id
}

struct AppShellView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \AgentConfigRecord.createdAt) private var agents: [AgentConfigRecord]
    @Query(sort: \ConversationRecord.updatedAt, order: .reverse) private var conversations: [ConversationRecord]

    @State private var path: [ShellRoute] = []
    @State private var pendingInputs: [UUID: AgentInput] = [:]
    @State private var showingAddAgent = false
    @State private var showingSettings = false
    @State private var editingAgent: AgentConfigRecord?
    @State private var deletingAgent: AgentConfigRecord?
    @State private var deletingConversation: ConversationRecord?
    @State private var infoStore = AgentInfoStore()
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system

    var body: some View {
        NavigationStack(path: $path) {
            AgentListView(
                agents: agents,
                infoByAddress: infoStore.infoByAddress,
                onSelectAgent: { path.append(.agentHome($0.address)) },
                onAddAgent: { showingAddAgent = true },
                onSettings: { showingSettings = true },
                onRenameAgent: { renameAgentName($0, to: $1) },
                onDeleteAgent: { deletingAgent = $0 },
                onRefresh: refreshAgentInfo
            )
            .navigationDestination(for: ShellRoute.self) { route in
                destination(for: route)
            }
        }
        .accessibilityIdentifier(AccessibilityID.appShell)
        .sheet(isPresented: $showingAddAgent) {
            AgentEditorView { address, alias, endpoint in
                addAgent(address: address, alias: alias, endpoint: endpoint)
            }        }
        .sheet(item: $editingAgent) { agent in
            AgentEditorView(
                title: "Edit Agent",
                initialAddress: agent.address,
                initialAlias: agent.alias,
                initialEndpoint: agent.preferredEndpoint,
                isAddressEditable: false
            ) { _, alias, endpoint in
                renameAgent(agent, alias: alias, endpoint: endpoint)
            }        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                agents: agents,
                infoByAddress: infoStore.infoByAddress,
                onAddAgent: showAddAgentFromSettings,
                onDeleteAgent: deleteAgent
            )        }
        .confirmationDialog(
            "Delete Agent?",
            isPresented: Binding(
                get: { deletingAgent != nil },
                set: { if !$0 { deletingAgent = nil } }
            ),
            titleVisibility: .visible,
            presenting: deletingAgent
        ) { agent in
            Button("Delete Agent", role: .destructive) {
                deleteAgent(agent)
                deletingAgent = nil
            }
            .accessibilityIdentifier(AccessibilityID.confirmDeleteAgentButton)

            Button("Cancel", role: .cancel) {
                deletingAgent = nil
            }
        }
        .confirmationDialog(
            "Delete Chat?",
            isPresented: Binding(
                get: { deletingConversation != nil },
                set: { if !$0 { deletingConversation = nil } }
            ),
            titleVisibility: .visible,
            presenting: deletingConversation
        ) { conversation in
            Button("Delete Chat", role: .destructive) {
                deleteConversation(conversation)
                deletingConversation = nil
            }
            Button("Cancel", role: .cancel) {
                deletingConversation = nil
            }
        }
        .task {
            applyAppearance(appearance)
            publishWidgetSnapshot()
            consumePendingWidgetRequest()
            configureAgentInfoRefresh()
        }
        .onChange(of: agents.map(\.address)) { _, addresses in
            publishWidgetSnapshot()
            infoStore.setEndpoints(agentEndpointMap)
            infoStore.startAutoRefresh(addresses: addresses, focusedAddress: focusedAgentAddress)
        }
        .onChange(of: agents.map(\.preferredEndpoint)) { _, _ in
            // Re-probe every agent (not just the focused one) so a just-edited endpoint updates its
            // status immediately instead of waiting for the ~60s all-refresh cycle.
            configureAgentInfoRefresh()
            infoStore.refresh(addresses: agentAddresses)
        }
        .onChange(of: agents.map(\.updatedAt)) { _, _ in
            publishWidgetSnapshot()
        }
        .onChange(of: conversations.map(\.updatedAt)) { _, _ in
            publishWidgetSnapshot()
        }
        .onChange(of: infoStore.infoByAddress) { _, _ in
            publishWidgetSnapshot()
        }
        .onChange(of: path) { _, _ in
            configureAgentInfoRefresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                consumePendingWidgetRequest()
                configureAgentInfoRefresh()
            } else {
                infoStore.stopAutoRefresh()
            }
        }
        .onOpenURL { url in
            guard let request = ConnectOnionDeepLink.parse(url) else { return }
            if let conversationID = request.conversationID {
                openConversation(id: conversationID)
            } else {
                handleNewChatRequest(agentAddress: request.agentAddress, suggestion: request.suggestion)
            }
        }
        .onDisappear {
            infoStore.stopAutoRefresh()
        }
        .onChange(of: appearance) { _, mode in
            applyAppearance(mode)
        }
    }

    /// Apply the theme at the window level so it covers the main UI and every presented sheet/popover,
    /// and so switching back to System (.unspecified) cleanly reverts to the device setting — which
    /// `.preferredColorScheme(nil)` fails to do live for an already-presented sheet.
    private func applyAppearance(_ mode: AppearanceMode) {
        let style: UIUserInterfaceStyle =
            switch mode {
            case .system: .unspecified
            case .light: .light
            case .dark: .dark
            }
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }

    @ViewBuilder
    private func destination(for route: ShellRoute) -> some View {
        switch route {
        case .agentHome(let address):
            if let agent = agent(for: address) {
                AgentHomeView(
                    agent: agent,
                    info: infoStore.infoByAddress[address],
                    conversations: conversations(for: address),
                    onNewChat: { path.append(.newChat(address)) },
                    onOpenConversation: { path.append(.conversation($0.id)) },
                    onRenameConversation: { renameConversation($0, to: $1) },
                    onRequestDeleteConversation: { deletingConversation = $0 },
                    onDeleteConversation: deleteConversation
                )
            }

        case .newChat(let address):
            if let agent = agent(for: address) {
                AgentLandingView(
                    agent: agent,
                    info: infoStore.infoByAddress[address],
                    onSend: { input in startConversation(agent: agent, input: input) }
                )
            }

        case .conversation(let id):
            if let conversation = conversations.first(where: { $0.id == id }),
               let agent = agent(for: conversation.agentAddress) {
                ChatScreen(
                    conversation: conversation,
                    agent: agent,
                    info: infoStore.infoByAddress[agent.address],
                    initialInput: pendingInputs[id],
                    onInitialInputConsumed: { pendingInputs[id] = nil }
                )
                .id(id)
            }
        }
    }

    private func conversations(for address: String) -> [ConversationRecord] {
        conversations.filter { $0.agentAddress == address }
    }

    private var agentAddresses: [String] {
        agents.map(\.address)
    }

    private var focusedAgentAddress: String? {
        switch path.last {
        case .agentHome(let address), .newChat(let address):
            return address
        case .conversation(let id):
            return conversations.first { $0.id == id }?.agentAddress
        case nil:
            return nil
        }
    }

    private func refreshAgentInfo() async {
        await infoStore.refreshNow(addresses: agentAddresses)
    }

    private var agentEndpointMap: [String: URL] {
        Dictionary(uniqueKeysWithValues: agents.compactMap { agent in
            agent.preferredEndpoint.map { (agent.address, $0) }
        })
    }

    private func configureAgentInfoRefresh(refreshImmediately: Bool = true) {
        infoStore.setEndpoints(agentEndpointMap)
        infoStore.startAutoRefresh(
            addresses: agentAddresses,
            focusedAddress: focusedAgentAddress,
            refreshImmediately: refreshImmediately
        )
    }

    private func agent(for address: String) -> AgentConfigRecord? {
        agents.first { $0.address == address }
    }

    private func addAgent(address: String, alias: String, endpoint: URL?) {
        guard let validAddress = AgentAddress(rawValue: address) else { return }

        if let existing = agents.first(where: { $0.address == validAddress.rawValue }) {
            existing.alias = alias
            existing.preferredEndpoint = endpoint
            existing.updatedAt = .now
        } else {
            modelContext.insert(AgentConfigRecord(address: validAddress.rawValue, alias: alias, preferredEndpoint: endpoint))
        }

        showingAddAgent = false
        infoStore.refresh(addresses: [validAddress.rawValue])
        path = [.agentHome(validAddress.rawValue)]
    }

    private func renameAgent(_ agent: AgentConfigRecord, alias: String, endpoint: URL?) {
        agent.alias = alias
        agent.preferredEndpoint = endpoint
        agent.updatedAt = .now
        infoStore.refresh(addresses: [agent.address])
    }

    private func showAddAgentFromSettings() {
        showingSettings = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            showingAddAgent = true
        }
    }

    private func deleteAgent(_ agent: AgentConfigRecord) {
        let related = conversations.filter { $0.agentAddress == agent.address }
        let relatedIDs = Set(related.map(\.id))
        related.forEach(modelContext.delete)
        modelContext.delete(agent)

        // If we were viewing (any level of) the deleted agent, pop back to the agent list.
        let referencesDeleted = path.contains { route in
            switch route {
            case .agentHome(let a), .newChat(let a): a == agent.address
            case .conversation(let id): relatedIDs.contains(id)
            }
        }
        if referencesDeleted {
            path.removeAll()
        }
    }

    private func deleteConversation(_ conversation: ConversationRecord) {
        modelContext.delete(conversation)
        // Pop the chat if it's open; a delete from the list (not on the stack) is a no-op here.
        path.removeAll { $0 == .conversation(conversation.id) }
    }

    private func renameAgentName(_ agent: AgentConfigRecord, to name: String) {
        agent.alias = name
        agent.updatedAt = .now
        infoStore.refresh(addresses: [agent.address])
    }

    private func renameConversation(_ conversation: ConversationRecord, to title: String) {
        conversation.title = title
        conversation.updatedAt = .now
    }

    private func newChat(for agent: AgentConfigRecord) {
        path = [.agentHome(agent.address), .newChat(agent.address)]
    }

    private func startConversation(agent: AgentConfigRecord, input: AgentInput) {
        let conversation = ConversationRecord(agentAddress: agent.address, mode: .safe)
        modelContext.insert(conversation)
        pendingInputs[conversation.id] = input
        // From the fresh-chat landing, replace it with the real conversation so Back returns to the
        // agent home; otherwise push onto whatever's showing.
        if case .newChat = path.last {
            path[path.count - 1] = .conversation(conversation.id)
        } else {
            path.append(.conversation(conversation.id))
        }
    }

    private func consumePendingWidgetRequest() {
        if let request = ConnectOnionPendingChatRequestStore.consume() {
            handleNewChatRequest(agentAddress: request.agentAddress, suggestion: request.suggestion)
            return
        }
        // Retry after a short delay to handle the race condition where the widget
        // extension's perform() hasn't finished writing to UserDefaults yet.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard let request = ConnectOnionPendingChatRequestStore.consume() else { return }
            handleNewChatRequest(agentAddress: request.agentAddress, suggestion: request.suggestion)
        }
    }

    private func handleNewChatRequest(agentAddress: String?, suggestion: String?) {
        let agent = agentAddress.flatMap(agent(for:)) ?? agents.first
        guard let agent else {
            showingAddAgent = true
            return
        }

        let trimmedSuggestion = suggestion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedSuggestion.isEmpty {
            newChat(for: agent)
        } else {
            path = [.agentHome(agent.address)]
            startConversation(agent: agent, input: AgentInput(prompt: trimmedSuggestion))
        }
    }

    private func openConversation(id: String) {
        guard let uuid = UUID(uuidString: id),
              let conversation = conversations.first(where: { $0.id == uuid }) else { return }
        path = [.agentHome(conversation.agentAddress), .conversation(uuid)]
    }

    private func publishWidgetSnapshot() {
        let shortcuts = agents
            .map { agent -> ConnectOnionAgentShortcut in
                let latestConversation = conversations.first { $0.agentAddress == agent.address }
                let info = infoStore.infoByAddress[agent.address] ?? agent.cachedInfo
                let lastUsedAt = latestConversation?.updatedAt ?? agent.updatedAt
                return ConnectOnionAgentShortcut(
                    address: agent.address,
                    displayName: agent.displayName(info: info),
                    subtitle: widgetSubtitle(for: latestConversation, info: info),
                    lastUsedAt: lastUsedAt,
                    suggestions: ConnectOnionSharedSuggestions.defaults
                )
            }
            .sorted { $0.lastUsedAt > $1.lastUsedAt }

        ConnectOnionWidgetSnapshotStore.save(
            ConnectOnionWidgetSnapshot(updatedAt: .now, agents: Array(shortcuts.prefix(6)))
        )
        WidgetCenter.shared.reloadTimelines(ofKind: "ConnectOnionWidget")
    }

    private func widgetSubtitle(for conversation: ConversationRecord?, info: AgentInfo?) -> String {
        if let conversation {
            return conversation.title
        }

        if info?.online == true {
            return "Online"
        }

        return "Ready"
    }
}

#Preview("Loaded Shell") {
    let _ = PreviewFixtures.installMockDependencies()
    AppShellView()
        .modelContainer(PreviewFixtures.seededContainer())
}

#Preview("Empty Shell") {
    let _ = PreviewFixtures.installMockDependencies()
    AppShellView()
        .modelContainer(PreviewFixtures.container())
}
