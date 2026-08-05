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
        ZStack {
            TopGradientWash(tint: .teal, secondaryTint: .emerald)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    if settlements.isEmpty {
                        allSettledCard
                    } else {
                        // Progress Health Ring Section
                        progressRingCard

                        // Balance Pills Deck
                        balanceOverviewCard

                        // Transaction Cards List
                        transactionsCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("Settlements")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { computeSettlements() }
        .animation(.spring(.bouncy), value: settledIDs)
    }

    // MARK: - All Settled Card

    private var allSettledCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green.gradient)

            VStack(spacing: 6) {
                Text("All Settled!")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                Text("No outstanding balances. Everyone is square.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(28)
        .appleCardStyle(cornerRadius: 24)
    }

    // MARK: - Progress Ring Card

    private var progressRingCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                // Health Ring
                HealthRingView(
                    progress: settledFraction,
                    ringColor: settledFraction >= 1.0 ? .green : .teal,
                    lineWidth: 10
                )
                .frame(width: 84, height: 84)

                VStack(alignment: .leading, spacing: 4) {
                    Text("SETTLEMENT PROGRESS")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)

                    Text("\(settledIDs.count) of \(settlements.count) Settled")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)

                    Group {
                        if pendingCount == 0 {
                            Text("Everyone is square!")
                                .foregroundStyle(.green)
                        } else {
                            Text("\(pendingCount) transaction\(pendingCount == 1 ? "" : "s") pending")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption.weight(.medium))
                }

                Spacer()
            }
        }
        .padding(20)
        .appleCardStyle(cornerRadius: 22)
    }

    private var settledFraction: Double {
        guard !settlements.isEmpty else { return 1.0 }
        return Double(settledIDs.count) / Double(settlements.count)
    }

    // MARK: - Balance Overview Card

    private var balanceOverviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Member Balances", systemImage: "chart.bar.fill")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(activeParticipants) { participant in
                        let balance = balances[participant.id] ?? .zero
                        AppleCardBalancePill(
                            participant: participant,
                            balance: balance,
                            currencyCode: primaryCurrencyCode
                        )
                    }
                }
            }
        }
        .padding(20)
        .appleCardStyle(cornerRadius: 22)
    }

    // MARK: - Transactions Card

    private var transactionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Suggested Transfers", systemImage: "arrow.left.arrow.right")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)

            LazyVStack(spacing: 12) {
                ForEach(Array(settlements.enumerated()), id: \.offset) { index, settlement in
                    AppleCardSettlementRow(
                        settlement: settlement,
                        currencyCode: primaryCurrencyCode,
                        isSettled: settledIDs.contains(settlementID(index)),
                        onToggle: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                toggleSettled(index)
                            }
                        }
                    )
                }
            }
        }
        .padding(20)
        .appleCardStyle(cornerRadius: 22)
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

// MARK: - Apple Card Settlement Row

private struct AppleCardSettlementRow: View {
    let settlement: Settlement
    let currencyCode: String
    let isSettled: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // From Avatar
            VStack(spacing: 3) {
                initialsAvatar(for: settlement.from)
                Text(settlement.from.handle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(width: 48)

            // Arrow & Amount
            VStack(spacing: 2) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isSettled ? .green : .teal)
                Text(settlement.amount.formatted(.currency(code: currencyCode)))
                    .font(.system(.callout, design: .rounded, weight: .bold))
                    .foregroundStyle(isSettled ? .secondary : .primary)
            }
            .frame(maxWidth: .infinity)

            // To Avatar
            VStack(spacing: 3) {
                initialsAvatar(for: settlement.to)
                Text(settlement.to.handle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(width: 48)

            // Checkmark Toggle Button
            Button {
                onToggle()
            } label: {
                Image(systemName: isSettled ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSettled ? .green : .secondary)
                    .frame(width: 36, height: 36)
                    .glassEffect(.clear, in: .circle)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .clearGlassCard(cornerRadius: 16)
        .opacity(isSettled ? 0.6 : 1.0)
    }

    private func initialsAvatar(for participant: SettlementParticipant) -> some View {
        let initials = String(participant.handle.prefix(2)).uppercased()
        let colors: [Color] = [.blue, .purple, .pink, .orange, .teal, .indigo, .mint]
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

// MARK: - Apple Card Balance Pill

private struct AppleCardBalancePill: View {
    let participant: Participant
    let balance: Decimal
    let currencyCode: String

    private var isCreditor: Bool { balance > .zero }

    var body: some View {
        VStack(spacing: 6) {
            ParticipantAvatarView(participant: participant)

            Text(participant.handle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            if balance != .zero {
                Text(formattedBalance)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(isCreditor ? .green : .pink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(isCreditor ? Color.green.opacity(0.15) : Color.pink.opacity(0.15))
                    )
            } else {
                Text("Settled")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .clearGlassCard(cornerRadius: 16)
    }

    private var formattedBalance: String {
        let sign = isCreditor ? "+" : ""
        return sign + balance.formatted(.currency(code: currencyCode))
    }
}

// MARK: - Preview

#Preview("Settlements") {
    NavigationStack {
        SettlementView(trip: PreviewSampleData.sampleGroup)
    }
    .modelContainer(PreviewSampleData.container)
}
