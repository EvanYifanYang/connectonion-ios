//
//  ConnectOnion_iOSApp.swift
//  ConnectOnion iOS
//
//  Created by Junhua Di on 2026/6/12.
//

import SwiftUI
import SwiftData

@main
struct ConnectOnion_iOSApp: App {
    let sharedModelContainer: ModelContainer

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-testing") {
            let scenario = PreviewFixtures.scenario(from: arguments)
            PreviewFixtures.installMockDependencies(scenario: scenario)
            sharedModelContainer = PreviewFixtures.seededContainer(scenario: scenario)
        } else {
            sharedModelContainer = Self.persistentContainer()
        }
    }

    private static func persistentContainer() -> ModelContainer {
        let schema = Schema([
            AgentConfigRecord.self,
            ConversationRecord.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            try FileManager.default.createDirectory(
                at: .applicationSupportDirectory,
                withIntermediateDirectories: true
            )
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

/// Hosts the app with the launch splash overlaid on top (option B: the app sits behind and is
/// revealed as the splash's backdrop fades during disassembly). The splash is for returning users:
/// with no agents the app lands on the welcome empty-state (which is its own entrance), so the splash
/// is skipped — no double welcome. Also skipped under UI testing so element queries aren't delayed.
private struct RootView: View {
    @Query private var agents: [AgentConfigRecord]
    @State private var splashDismissed = ProcessInfo.processInfo.arguments.contains("--ui-testing")

    private var showSplash: Bool { !splashDismissed && !agents.isEmpty }

    var body: some View {
        ZStack {
            AppShellView()

            if showSplash {
                LaunchSplashView {
                    withAnimation(.easeOut(duration: 0.25)) { splashDismissed = true }
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            // The splash is a launch-only decision. If this launch starts in the first-run state,
            // keep it dismissed even after the user adds their first agent later in the session.
            if agents.isEmpty {
                splashDismissed = true
            }
        }
    }
}
