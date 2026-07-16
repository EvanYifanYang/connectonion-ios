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
            AppShellView()
        }
        .modelContainer(sharedModelContainer)
    }
}
