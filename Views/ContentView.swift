//
//  ContentView.swift
//  Split
//
//  Created by Souhail on 8/3/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: TabDestination = .groups

    enum TabDestination: String, CaseIterable, Identifiable {
        case groups = "Groups"
        case activity = "Activity"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .groups: "rectangle.3.group"
            case .activity: "chart.pie.fill"
            case .settings: "gearshape.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Groups", systemImage: TabDestination.groups.icon, value: .groups) {
                GroupsView()
            }

            Tab("Activity", systemImage: TabDestination.activity.icon, value: .activity) {
                ActivityView()
            }

            Tab("Settings", systemImage: TabDestination.settings.icon, value: .settings) {
                SettingsView()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
