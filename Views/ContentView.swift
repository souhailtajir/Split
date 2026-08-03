//
//  ContentView.swift
//  Split
//
//  Created by Souhail on 8/3/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: TabDestination = .trips

    enum TabDestination: String, CaseIterable, Identifiable {
        case trips = "Trips"
        case activity = "Activity"
        case settings = "Settings"

        var id: String { self.rawValue }

        var icon: String {
            switch self {
            case .trips: "airplane"
            case .activity: "chart.pie.fill"
            case .settings: "gearshape.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TripsView()
                .tabItem {
                    Label("Trips", systemImage: TabDestination.trips.icon)
                }
                .tag(TabDestination.trips)

            ActivityView()
                .tabItem {
                    Label("Activity", systemImage: TabDestination.activity.icon)
                }
                .tag(TabDestination.activity)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: TabDestination.settings.icon)
                }
                .tag(TabDestination.settings)
        }
        .tint(.indigo)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(for: Trip.self, inMemory: true)
}
