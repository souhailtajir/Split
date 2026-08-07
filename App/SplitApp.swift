//
//  SplitApp.swift
//  Split
//
//  Created by Souhail on 8/3/26.
//

import SwiftUI
import SwiftData

@main
struct SplitApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            Trip.self,
            Participant.self,
            Expense.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(UserProfile.shared)
        }
        .modelContainer(sharedModelContainer)
    }
}
