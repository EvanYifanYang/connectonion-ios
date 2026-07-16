import SwiftData
import SwiftUI
import UIKit
import WidgetKit

struct AppShellView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \AgentConfigRecord.createdAt) private var agents: [AgentConfigRecord]
    @Query(sort: \ConversationRecord.updatedAt, order: .reverse) private var conversations: [ConversationRecord]

    @State private var selectedAgentAddress: String?
    @State private var selectedConversationID: UUID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var preferredCompactColumn: NavigationSplitViewColumn = .sidebar
    @State private var pendingInputs: [UUID: AgentInput] = [:]
    @State private var showingAddAgent = false
    @State private var showingNewConversation = false
    @State private var showingSettings = false
    @State private var editingAgent: AgentConfigRecord?
    @State private var deletingAgent: AgentConfigRecord?
    @State private var deletingConversation: ConversationRecord?
    @State private var infoStore = AgentInfoStore()
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $preferredCompactColumn) {
            SidebarView(
                agents: agents,
                conversations: conversations,
                infoByAddress: infoStore.infoByAddress,
                selectedAgentAddress: $selectedAgentAddress,
                selectedConversationID: $selectedConversationID,
                onNewChat: newChat,
                onNewConversation: { showingNewConversation = true },
                onAddAgent: { showingAddAgent = true },
                onRenameAgent: { renameAgentName($0, to: $1) },
                onDeleteAgent: { deletingAgent = $0 },
                onRenameConversation: { renameConversation($0, to: $1) },
                onRequestDeleteConversation: { deletingConversation = $0 },
                onDeleteConversation: deleteConversation,
                onSettings: { showingSettings = true },
                onOpenDetail: showDetailColumn,
                onRefresh: refreshAgentInfo
            )
        } detail: {
            detailView
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
        .sheet(isPresented: $showingNewConversation) {
            NewConversationSheet(
                agents: agents,
                infoByAddress: infoStore.infoByAddress,
                initialAgentAddress: selectedAgentAddress
            ) { agent, prompt in
                if prompt.isEmpty {
                    newChat(for: agent)
                } else {
                    startConversation(agent: agent, input: AgentInput(prompt: prompt))
                }
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
            restoreInitialSelection()
            publishWidgetSnapshot()
            consumePendingWidgetRequest()
            configureAgentInfoRefresh()
        }
        .onChange(of: agents.map(\.address)) { _, addresses in
            restoreInitialSelection()
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
        .onChange(of: selectedAgentAddress) { _, _ in
            configureAgentInfoRefresh()
        }
        .onChange(of: selectedConversationID) { _, _ in
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
    private var detailView: some View {
        if let conversation = selectedConversation,
           let agent = agent(for: conversation.agentAddress) {
            ChatScreen(
                conversation: conversation,
                agent: agent,
                info: infoStore.infoByAddress[agent.address],
                initialInput: pendingInputs[conversation.id],
                onInitialInputConsumed: { pendingInputs[conversation.id] = nil }
            )
            .id(conversation.id)
        } else if let agent = selectedAgent {
            AgentLandingView(
                agent: agent,
                info: infoStore.infoByAddress[agent.address],
                onSend: { input in startConversation(agent: agent, input: input) }
            )
        } else {
            WelcomeView(onAddAgent: { showingAddAgent = true })
        }
    }

    private var selectedConversation: ConversationRecord? {
        guard let selectedConversationID else { return nil }
        return conversations.first { $0.id == selectedConversationID }
    }

    private var selectedAgent: AgentConfigRecord? {
        guard let selectedAgentAddress else { return agents.first }
        return agents.first { $0.address == selectedAgentAddress }
    }

    private var agentAddresses: [String] {
        agents.map(\.address)
    }

    private var focusedAgentAddress: String? {
        if let selectedConversation {
            return selectedConversation.agentAddress
        }
        return selectedAgent?.address
    }

    private func restoreInitialSelection() {
        if agents.isEmpty {
            selectedAgentAddress = nil
            selectedConversationID = nil
            preferredCompactColumn = .sidebar
            columnVisibility = .automatic
            return
        }

        if selectedConversationID == nil, selectedAgentAddress == nil {
            selectedAgentAddress = agents.first?.address
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

        selectedAgentAddress = validAddress.rawValue
        selectedConversationID = nil
        showingAddAgent = false
        infoStore.refresh(addresses: [validAddress.rawValue])
        showDetailColumn()
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
        related.forEach(modelContext.delete)
        modelContext.delete(agent)

        if selectedAgentAddress == agent.address {
            selectedAgentAddress = agents.first(where: { $0.address != agent.address })?.address
            selectedConversationID = nil
        }
    }

    private func deleteConversation(_ conversation: ConversationRecord) {
        modelContext.delete(conversation)
        if selectedConversationID == conversation.id {
            selectedConversationID = nil
            selectedAgentAddress = conversation.agentAddress
        }
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
        selectedAgentAddress = agent.address
        selectedConversationID = nil
        showDetailColumn()
    }

    private func startConversation(agent: AgentConfigRecord, input: AgentInput) {
        let conversation = ConversationRecord(agentAddress: agent.address, mode: .safe)
        modelContext.insert(conversation)
        pendingInputs[conversation.id] = input
        selectedAgentAddress = agent.address
        selectedConversationID = conversation.id
        showDetailColumn()
    }

    private func showDetailColumn() {
        columnVisibility = .detailOnly
        preferredCompactColumn = .detail
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
        let agent = agentAddress.flatMap(agent(for:)) ?? selectedAgent ?? agents.first
        guard let agent else {
            showingAddAgent = true
            return
        }

        let trimmedSuggestion = suggestion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedSuggestion.isEmpty {
            newChat(for: agent)
        } else {
            startConversation(agent: agent, input: AgentInput(prompt: trimmedSuggestion))
        }
    }

    private func openConversation(id: String) {
        guard let uuid = UUID(uuidString: id),
              let conversation = conversations.first(where: { $0.id == uuid }) else { return }
        selectedAgentAddress = conversation.agentAddress
        selectedConversationID = conversation.id
        showDetailColumn()
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
