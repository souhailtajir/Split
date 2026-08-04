//
//  GroupsView.swift
//  Split
//
//  Created by Souhail on 8/4/26.
//

import SwiftUI
import SwiftData

struct GroupsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(
        filter: #Predicate<Trip> { !$0.isTombstoned },
        sort: \Trip.createdAt,
        order: .reverse
    )
    private var groups: [Trip]

    @State private var showingNewGroup = false
    @State private var newGroupName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientMeshBackground(style: .groups)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        heroSummaryCard

                        // Section Header
                        HStack {
                            Text("Your Groups")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(.primary)

                            Spacer()

                            GlassActionButton(title: "New", systemImage: "plus", accentColor: .indigo) {
                                showingNewGroup = true
                            }
                        }
                        .padding(.horizontal, 4)

                        // Group Deck
                        if groups.isEmpty {
                            emptyStateCard
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(groups) { group in
                                    NavigationLink {
                                        GroupDetailView(trip: group)
                                    } label: {
                                        GroupCardRow(group: group)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            softDelete(group: group)
                                        } label: {
                                            Label("Delete Group", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Groups")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingNewGroup) {
                newGroupSheet
            }
        }
    }

    // MARK: - Hero Summary Card

    private var heroSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OVERVIEW")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .tracking(1.0)

                    Text(allGroupsTotalSpend.formatted(.currency(code: primaryCurrencyCode)))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "creditcard.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }

            HStack(spacing: 10) {
                StatPill(icon: "rectangle.3.group", value: "\(groups.count) Groups")
                StatPill(icon: "person.2.fill", value: "\(totalUniqueParticipants) Members")
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.indigo,
                            Color.purple.opacity(0.9),
                            Color.blue.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                }
                .shadow(color: Color.indigo.opacity(colorScheme == .dark ? 0.4 : 0.2), radius: 14, x: 0, y: 6)
        }
    }

    // MARK: - Empty State Card

    private var emptyStateCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 44))
                .foregroundStyle(.indigo.gradient)
                .padding(.top, 12)

            VStack(spacing: 6) {
                Text("No Groups Yet")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Create a group to start splitting expenses — whether it's a trip, dinner, shared apartment, or any activity.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            GlassActionButton(title: "Create New Group", systemImage: "plus.circle.fill", accentColor: .indigo) {
                showingNewGroup = true
            }
            .padding(.bottom, 8)
        }
        .padding(24)
        .appleCardStyle()
    }

    // MARK: - New Group Sheet

    private var newGroupSheet: some View {
        NavigationStack {
            ZStack {
                AmbientMeshBackground(style: .groups)

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GROUP NAME")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)

                        TextField("e.g. Summer in Lisbon, Friday Dinner, Roommates", text: $newGroupName)
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .padding()
                            .glassEffect(.regular, in: .rect(cornerRadius: 16))
                    }

                    Spacer()

                    Button {
                        createGroup()
                    } label: {
                        Text("Create Group")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                newGroupName.trimmingCharacters(in: .whitespaces).isEmpty
                                ? AnyShapeStyle(Color.gray.opacity(0.4))
                                : AnyShapeStyle(Color.indigo.gradient),
                                in: RoundedRectangle(cornerRadius: 18)
                            )
                    }
                    .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(24)
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newGroupName = ""
                        showingNewGroup = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Computed Properties

    private var allGroupsTotalSpend: Decimal {
        groups.reduce(.zero) { sum, group in
            sum + group.expenses.filter { !$0.isTombstoned }.reduce(.zero) { $0 + $1.amount }
        }
    }

    private var totalUniqueParticipants: Int {
        Set(groups.flatMap { $0.participants.filter { !$0.isTombstoned }.map(\.id) }).count
    }

    private var primaryCurrencyCode: String {
        groups.flatMap(\.expenses).first(where: { !$0.isTombstoned })?.currencyCode
            ?? Locale.current.currency?.identifier ?? "USD"
    }

    // MARK: - Actions

    private func createGroup() {
        let name = newGroupName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            let group = Trip(name: name, startDate: .now)
            modelContext.insert(group)
        }
        newGroupName = ""
        showingNewGroup = false
    }

    private func softDelete(group: Trip) {
        withAnimation(.smooth) {
            group.isTombstoned = true
            group.updatedAt = .now
        }
    }
}

// MARK: - Hero Stat Pill

private struct StatPill: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.white.opacity(0.15), in: .capsule)
    }
}

// MARK: - Premium Group Card Row

struct GroupCardRow: View {
    let group: Trip

    @Environment(\.colorScheme) private var colorScheme

    private var activeExpenses: [Expense] {
        group.expenses.filter { !$0.isTombstoned }
    }

    private var activeParticipants: [Participant] {
        group.participants.filter { !$0.isTombstoned }
    }

    private var totalSpend: Decimal {
        activeExpenses.reduce(.zero) { $0 + $1.amount }
    }

    private var currencyCode: String {
        activeExpenses.first?.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top: Icon + Name + Amount
            HStack(spacing: 14) {
                // Gradient Icon Badge
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [cardAccentColor, cardAccentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: groupIcon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(group.name)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let start = group.startDate {
                        Text(start.formatted(.dateTime.month(.wide).day().year()))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(totalSpend.formatted(.currency(code: currencyCode)))
                        .font(.system(.callout, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }

            // Divider
            Rectangle()
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                .frame(height: 1)
                .padding(.vertical, 12)

            // Bottom: Metadata chips
            HStack(spacing: 8) {
                MetadataChip(icon: "person.2.fill", value: "\(activeParticipants.count)", label: "members")
                MetadataChip(icon: "receipt", value: "\(activeExpenses.count)", label: "expenses")

                Spacer()

                // Per-person breakdown
                if !activeParticipants.isEmpty && totalSpend > .zero {
                    let perPerson = totalSpend / Decimal(activeParticipants.count)
                    Text("~\(perPerson.formatted(.currency(code: currencyCode)))/person")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .appleCardStyle(cornerRadius: 20)
    }

    /// Context-aware icon based on group name keywords.
    private var groupIcon: String {
        let name = group.name.lowercased()
        if name.contains("trip") || name.contains("travel") || name.contains("vacation") || name.contains("flight") {
            return "airplane"
        } else if name.contains("dinner") || name.contains("lunch") || name.contains("brunch") || name.contains("meal") || name.contains("food") {
            return "fork.knife"
        } else if name.contains("apartment") || name.contains("house") || name.contains("room") || name.contains("rent") {
            return "house.fill"
        } else if name.contains("event") || name.contains("party") || name.contains("concert") || name.contains("festival") {
            return "party.popper.fill"
        } else if name.contains("office") || name.contains("work") || name.contains("team") {
            return "briefcase.fill"
        }
        return "rectangle.3.group"
    }

    private var cardAccentColor: Color {
        let colors: [Color] = [.indigo, .blue, .purple, .teal, .orange]
        return colors[abs(group.id.hashValue) % colors.count]
    }
}

// MARK: - Metadata Chip

private struct MetadataChip: View {
    let icon: String
    let value: String
    let label: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04), in: .capsule)
    }
}

// MARK: - Preview

#Preview("Groups — With Data") {
    GroupsView()
        .modelContainer(PreviewSampleData.container)
}

#Preview("Groups — Empty") {
    GroupsView()
        .modelContainer(PreviewSampleData.emptyContainer)
}
