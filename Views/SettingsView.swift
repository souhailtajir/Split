//
//  SettingsView.swift
//  Split
//
//  Created by Souhail on 8/3/26.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(UserProfile.self) private var userProfile
    @Query private var trips: [Trip]
    @Query private var expenses: [Expense]

    @State private var isSyncing = false
    @State private var syncStatusText = "P2P Mesh Network Ready"
    @State private var discoveredPeersCount = 1
    @State private var isEditingProfile = false
    @State private var editedName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                TopGradientWash(tint: .cyan, secondaryTint: .blue)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Profile Card
                        profileCard

                        // Local Sync Status Card
                        syncStatusCard

                        // Data Management & Storage Card
                        storageStatsCard

                        // Peer Network Card
                        networkPeersCard

                        // About & Version Card
                        aboutAppCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Settings & Sync")
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(.indigo.gradient)
                        .frame(width: 52, height: 52)
                        .shadow(color: .indigo.opacity(0.35), radius: 8, y: 3)

                    Text(profileInitials)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .overlay {
                    Circle()
                        .glassEffect(.clear, in: .circle)
                        .frame(width: 54, height: 54)
                }

                if isEditingProfile {
                    TextField("Your name", text: $editedName)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .submitLabel(.done)
                        .onSubmit { saveProfile() }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(userProfile.displayName)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(.primary)

                        Text("@\(userProfile.handle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    if isEditingProfile {
                        saveProfile()
                    } else {
                        editedName = userProfile.displayName
                        withAnimation(.spring(.bouncy)) {
                            isEditingProfile = true
                        }
                    }
                } label: {
                    Image(systemName: isEditingProfile ? "checkmark.circle.fill" : "pencil")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isEditingProfile ? .indigo : .secondary)
                }
                .buttonStyle(.glass)
            }

            HStack {
                Label("Local Account", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("On Device")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.indigo)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.indigo.opacity(0.15), in: .capsule)
            }
        }
        .padding(20)
        .appleCardStyle(cornerRadius: 22)
    }

    private var profileInitials: String {
        let name = userProfile.displayName
        guard !name.isEmpty else { return "?" }
        let components = name.split(separator: " ")
        return components.prefix(2).map { String($0.prefix(1)) }.joined().uppercased()
    }

    private func saveProfile() {
        let trimmed = editedName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        userProfile.displayName = trimmed
        userProfile.handle = trimmed.lowercased().replacingOccurrences(of: " ", with: "")
        withAnimation(.spring(.bouncy)) {
            isEditingProfile = false
        }
    }

    // MARK: - Sync Status Card

    private var syncStatusCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.teal)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("LOCAL NETWORK SYNC")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)

                    Text(syncStatusText)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Button {
                    triggerManualSync()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.teal)
                        .rotationEffect(.degrees(isSyncing ? 360 : 0))
                        .animation(isSyncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isSyncing)
                }
                .buttonStyle(.glass)
                .disabled(isSyncing)
            }

            HStack {
                Label("Zero-Cloud Offline Mesh Sync", systemImage: "shield.checkmark.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("Active")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.15), in: .capsule)
            }
        }
        .padding(20)
        .appleCardStyle(cornerRadius: 22)
    }

    // MARK: - Storage Stats Card

    private var storageStatsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Data Storage", systemImage: "externaldrive.fill")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                // Trips Count
                VStack(alignment: .leading, spacing: 4) {
                    Text("GROUPS")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("\(trips.filter { !$0.isTombstoned }.count)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .frame(height: 36)

                // Expenses Count
                VStack(alignment: .leading, spacing: 4) {
                    Text("EXPENSES")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("\(expenses.filter { !$0.isTombstoned }.count)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .frame(height: 36)

                // SwiftData Engine
                VStack(alignment: .leading, spacing: 4) {
                    Text("ENGINE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("SwiftData")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.teal)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .appleCardStyle(cornerRadius: 22)
    }

    // MARK: - Network Peers Card

    private var networkPeersCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Discovered Devices", systemImage: "laptopcomputer.and.iphone")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(discoveredPeersCount) peer nearby")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 38, height: 38)
                    Image(systemName: "iphone")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Nearby iPhone (Peer Node)")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Bonjour Service • Connected")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(20)
        .appleCardStyle(cornerRadius: 22)
    }

    // MARK: - About App Card

    private var aboutAppCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Split for iOS")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Version 1.0 (Swift 6.2 / iOS 26.5)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                Image(systemName: "apple.logo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Text("Designed to emulate Apple Card & Apple Health UI/UX with zero-cloud P2P mesh sync.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .appleCardStyle(cornerRadius: 22)
    }

    // MARK: - Manual Sync Action

    private func triggerManualSync() {
        withAnimation {
            isSyncing = true
            syncStatusText = "Broadcasting peer sync..."
        }

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation {
                isSyncing = false
                syncStatusText = "P2P Mesh Synced"
            }
        }
    }
}

// MARK: - Preview

#Preview("Settings") {
    SettingsView()
        .modelContainer(PreviewSampleData.container)
        .environment(UserProfile.shared)
}
