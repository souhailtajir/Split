//
//  ContentView.swift
//  Split
//
//  Created by Souhail on 8/3/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(UserProfile.self) private var userProfile
    @State private var selectedTab: TabDestination = .groups
    @State private var showOnboarding = false

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
        .onAppear {
            if !userProfile.isProfileSetUp {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            ProfileOnboardingSheet()
                .interactiveDismissDisabled()
        }
    }
}

// MARK: - Profile Onboarding Sheet

private struct ProfileOnboardingSheet: View {
    @Environment(UserProfile.self) private var userProfile
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @FocusState private var isNameFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TopGradientWash(tint: .indigo, secondaryTint: .purple)

                VStack(spacing: 32) {
                    Spacer()

                    // Icon
                    ZStack {
                        Circle()
                            .fill(.indigo.gradient)
                            .frame(width: 88, height: 88)
                            .shadow(color: .indigo.opacity(0.4), radius: 20, y: 8)

                        Image(systemName: "person.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 8) {
                        Text("Welcome to Split")
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(.primary)

                        Text("Enter your name so group members\nknow who you are.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Name Field
                    TextField("Your name", text: $name)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .padding(16)
                        .appleCardStyle(cornerRadius: 16)
                        .padding(.horizontal, 32)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                        .onSubmit { completeSetup() }

                    Spacer()

                    // Get Started Button
                    GlassProminentActionButton(
                        title: "Get Started",
                        systemImage: "arrow.right",
                        accentColor: .indigo,
                        isDisabled: trimmedName.isEmpty
                    ) {
                        completeSetup()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isNameFocused = true
                }
            }
        }
    }

    private func completeSetup() {
        guard !trimmedName.isEmpty else { return }
        userProfile.displayName = trimmedName
        userProfile.handle = trimmedName.lowercased().replacingOccurrences(of: " ", with: "")
        userProfile.isProfileSetUp = true
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
        .environment(UserProfile.shared)
}
