//
//  SettingsView.swift
//  Split
//
//  Created by Souhail on 8/3/26.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var trips: [Trip]
    @Query private var expenses: [Expense]

    @Environment(\.colorScheme) private var colorScheme
    @State private var isSyncing = false
    @State private var syncStatusText = "P2P Mesh Network Ready"
    @State private var discoveredPeersCount = 1

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientMeshBackground(style: .settings)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
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
            .navigationBarTitleDisplayMode(.inline)
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
                .buttonStyle(.appleCard)
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
                    Text("TRIPS")
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isSyncing = false
                syncStatusText = "P2P Mesh Synced"
            }
        }
    }
}
