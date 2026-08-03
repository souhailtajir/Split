//
//  SettlementView.swift
//  Split
//
//  Created by Souhail on 8/3/26.
//

import SwiftUI
import SwiftData

struct SettlementView: View {
    let trip: Trip

    @State private var settlements: [Settlement] = []
    @State private var settledIDs: Set<String> = []
    @State private var balances: [UUID: Decimal] = [:]

    private var activeParticipants: [Participant] {
        trip.participants.filter { !$0.isTombstoned }
    }

    private var pendingCount: Int {
        settlements.count - settledIDs.count
    }

    private var primaryCurrencyCode: String {
        trip.expenses.first(where: { !$0.isTombstoned })?.currencyCode
            ?? Locale.current.currency?.identifier ?? "USD"
    }

    // MARK: - Body

    var body: some View {
        List {
            if settlements.isEmpty {
                allSettledView
            } else {
                statusSection
                balanceOverviewSection
                settlementsListSection
            }
        }
        .listStyle(.plain)
        .navigationTitle("Settlements")
        .onAppear { computeSettlements() }
        .animation(.smooth, value: settledIDs)
    }

    // MARK: - All Settled (Empty State)

    private var allSettledView: some View {
        ContentUnavailableView {
            Label("All Settled!", systemImage: "checkmark.seal.fill")
        } description: {
            Text("There are no outstanding debts for this trip. Everyone is square.")
        }
        .listRowBackground(Color.clear)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        Section {
            VStack(spacing: 12) {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(.quaternary, lineWidth: 6)
                        .frame(width: 72, height: 72)
                    Circle()
                        .trim(from: 0, to: settledFraction)
                        .stroke(
                            settledFraction >= 1.0 ? Color.green : Color.accentColor,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(settledIDs.count)")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                        Text("of \(settlements.count)")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .animation(.spring(duration: 0.5), value: settledIDs.count)

                // Status text
                Group {
                    if pendingCount == 0 {
                        Label("All debts settled!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Text("\(pendingCount) transaction\(pendingCount == 1 ? "" : "s") needed")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline.weight(.medium))
                .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .listRowBackground(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .glassEffect()
        )
    }

    private var settledFraction: Double {
        guard !settlements.isEmpty else { return 1.0 }
        return Double(settledIDs.count) / Double(settlements.count)
    }

    // MARK: - Balance Overview Section

    private var balanceOverviewSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(activeParticipants) { participant in
                        let balance = balances[participant.id] ?? .zero
                        BalancePillView(
                            participant: participant,
                            balance: balance,
                            currencyCode: primaryCurrencyCode
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Label("Balances", systemImage: "chart.bar.fill")
        }
        .listRowBackground(Color.clear)
    }

    // MARK: - Settlements List Section

    private var settlementsListSection: some View {
        Section {
            ForEach(Array(settlements.enumerated()), id: \.offset) { index, settlement in
                SettlementCardView(
                    settlement: settlement,
                    currencyCode: primaryCurrencyCode,
                    isSettled: settledIDs.contains(settlementID(index)),
                    onToggle: {
                        withAnimation(.spring(duration: 0.35)) {
                            toggleSettled(index)
                        }
                    }
                )
            }
        } header: {
            Label("Transactions", systemImage: "arrow.left.arrow.right")
        }
    }

    // MARK: - Settlement Logic

    private func computeSettlements() {
        let participantValues = activeParticipants
            .map { DebtSimplifier.settlementParticipant(from: $0) }

        let expenseValues = trip.expenses
            .filter { !$0.isTombstoned }
            .compactMap { DebtSimplifier.settlementExpense(from: $0) }

        balances = DebtSimplifier.computeNetBalances(
            participants: participantValues,
            expenses: expenseValues
        )

        settlements = DebtSimplifier.simplify(
            participants: participantValues,
            expenses: expenseValues
        )
    }

    private func settlementID(_ index: Int) -> String {
        let s = settlements[index]
        return "\(s.from.id)-\(s.to.id)"
    }

    private func toggleSettled(_ index: Int) {
        let id = settlementID(index)
        if settledIDs.contains(id) {
            settledIDs.remove(id)
        } else {
            settledIDs.insert(id)
        }
    }
}

// MARK: - Settlement Card

private struct SettlementCardView: View {
    let settlement: Settlement
    let currencyCode: String
    let isSettled: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // From avatar
            VStack(spacing: 4) {
                initialsAvatar(for: settlement.from)
                Text(settlement.from.handle)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(width: 52)

            // Arrow with amount
            VStack(spacing: 2) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSettled ? .green : .primary)
                Text(settlement.amount.formatted(.currency(code: currencyCode)))
                    .font(.system(.callout, design: .rounded, weight: .bold))
                    .foregroundStyle(isSettled ? .secondary : .primary)
            }
            .frame(maxWidth: .infinity)

            // To avatar
            VStack(spacing: 4) {
                initialsAvatar(for: settlement.to)
                Text(settlement.to.handle)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(width: 52)

            // Settled toggle
            Button {
                onToggle()
            } label: {
                Image(systemName: isSettled ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSettled ? .green : .secondary)
                    .symbolEffect(.bounce, value: isSettled)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSettled ? "Mark as unsettled" : "Mark as settled")
        }
        .padding(.vertical, 8)
        .opacity(isSettled ? 0.5 : 1.0)
        .strikethrough(isSettled, color: .green)
    }

    private func initialsAvatar(for participant: SettlementParticipant) -> some View {
        let initials = String(participant.handle.prefix(2)).uppercased()
        let colors: [Color] = [.blue, .purple, .pink, .orange, .teal, .indigo, .mint, .cyan]
        let color = colors[abs(participant.id.hashValue) % colors.count]

        return ZStack {
            Circle()
                .fill(color.gradient)
                .frame(width: 36, height: 36)
            Text(initials)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Balance Pill

private struct BalancePillView: View {
    let participant: Participant
    let balance: Decimal
    let currencyCode: String

    private var isCreditor: Bool { balance > .zero }
    private var isDebtor: Bool { balance < .zero }

    var body: some View {
        VStack(spacing: 6) {
            ParticipantAvatarView(participant: participant)

            Text(participant.handle)
                .font(.caption2)
                .lineLimit(1)

            if balance != .zero {
                Text(formattedBalance)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(isCreditor ? .green : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(isCreditor ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                    )
            } else {
                Text("settled")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 72)
    }

    private var formattedBalance: String {
        let sign = isCreditor ? "+" : ""
        return sign + balance.formatted(.currency(code: currencyCode))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettlementView(trip: Trip(name: "Lisbon 2026"))
    }
    .modelContainer(for: Trip.self, inMemory: true)
}
