//
//  GroupDetailView.swift
//  Split
//
//  Created by Souhail on 8/4/26.
//

import SwiftUI
import SwiftData

struct GroupDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var trip: Trip

    // MARK: - Computed Properties

    private var activeExpenses: [Expense] {
        trip.expenses
            .filter { !$0.isTombstoned }
            .sorted { $0.date > $1.date }
    }

    private var activeParticipants: [Participant] {
        trip.participants.filter { !$0.isTombstoned }
    }

    private var totalSpend: Decimal {
        activeExpenses.reduce(.zero) { $0 + $1.amount }
    }

    private var perPersonAverage: Decimal {
        guard !activeParticipants.isEmpty else { return .zero }
        return totalSpend / Decimal(activeParticipants.count)
    }

    private var primaryCurrencyCode: String {
        activeExpenses.first?.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            TopGradientWash(tint: .indigo, secondaryTint: .purple)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header Hero Glass Card
                    headerHeroCard

                    // Participants Deck Card
                    participantsCard

                    // Expenses Deck
                    expensesSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink {
                    SettlementView(trip: trip)
                } label: {
                    Image(systemName: "arrow.triangle.swap")
                }

                NavigationLink {
                    AddExpenseView(trip: trip)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    // MARK: - Header Hero Card (Liquid Glass)

    private var headerHeroCard: some View {
        VStack(spacing: 16) {
            // Date Range Capsule
            if let start = trip.startDate {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(dateRangeText(start: start, end: trip.endDate))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .clearGlassCapsule()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Total Spend Counter
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL SPENT")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .tracking(1.0)

                    Text(totalSpend.formatted(.currency(code: primaryCurrencyCode)))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("AVG / MEMBER")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(perPersonAverage.formatted(.currency(code: primaryCurrencyCode)))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(20)
        .appleCardStyle(cornerRadius: 24)
    }

    // MARK: - Participants Card

    private var participantsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Members", systemImage: "person.2.fill")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(activeParticipants.count) active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if activeParticipants.isEmpty {
                Text("No members added yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(activeParticipants) { participant in
                            VStack(spacing: 6) {
                                ParticipantAvatarView(participant: participant)
                                Text(participant.handle)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .clearGlassCard(cornerRadius: 14)
                        }
                    }
                }
            }
        }
        .padding(18)
        .appleCardStyle(cornerRadius: 22)
    }

    // MARK: - Expenses Section

    private var expensesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Expenses", systemImage: "receipt.fill")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()

                NavigationLink {
                    AddExpenseView(trip: trip)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.indigo)
                }
            }

            if activeExpenses.isEmpty {
                emptyExpensesView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(activeExpenses) { expense in
                        AppleCardExpenseRow(expense: expense)
                            .contextMenu {
                                Button(role: .destructive) {
                                    softDeleteExpense(expense)
                                } label: {
                                    Label("Delete Expense", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .padding(18)
        .appleCardStyle(cornerRadius: 22)
    }

    private var emptyExpensesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "creditcard")
                .font(.system(size: 36))
                .foregroundStyle(.indigo)

            Text("No Expenses Recorded")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Tap the + button to log shared payments.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func softDeleteExpense(_ expense: Expense) {
        withAnimation(.spring(.bouncy)) {
            expense.isTombstoned = true
            expense.updatedAt = .now
        }
    }

    private func dateRangeText(start: Date, end: Date?) -> String {
        let formatter = Date.FormatStyle().month(.abbreviated).day()
        if let end {
            return "\(start.formatted(formatter)) – \(end.formatted(formatter))"
        }
        return start.formatted(formatter.year())
    }
}

// MARK: - Apple Card Expense Row

struct AppleCardExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: 14) {
            // Category Icon Badge
            ZStack {
                Circle()
                    .fill(categoryColor.gradient)
                    .frame(width: 42, height: 42)
                    .shadow(color: categoryColor.opacity(0.35), radius: 5, x: 0, y: 2)

                Image(systemName: categoryIcon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }

            // Details
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let payer = expense.paidBy {
                        Text("Paid by \(payer.handle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("•")
                        .foregroundStyle(.quaternary)
                    Text(splitMethodBadge)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .clearGlassCapsule()
                }
            }

            Spacer()

            // Amount & Date
            VStack(alignment: .trailing, spacing: 3) {
                Text(expense.amount.formatted(.currency(code: expense.currencyCode)))
                    .font(.system(.callout, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)

                Text(expense.date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .clearGlassCard(cornerRadius: 16)
    }

    private var splitMethodBadge: String {
        switch expense.splitMethod {
        case .equally: "Equal"
        case .byShares: "Shares"
        case .byExactAmounts: "Exact"
        }
    }

    private var categoryIcon: String {
        let title = expense.title.lowercased()
        if title.contains("food") || title.contains("dinner") || title.contains("lunch") || title.contains("restaurant") {
            return "fork.knife"
        } else if title.contains("hotel") || title.contains("stay") || title.contains("airbnb") {
            return "bed.double.fill"
        } else if title.contains("transport") || title.contains("taxi") || title.contains("uber") || title.contains("flight") {
            return "car.fill"
        } else if title.contains("ticket") || title.contains("museum") || title.contains("activity") {
            return "ticket.fill"
        }
        return "creditcard.fill"
    }

    private var categoryColor: Color {
        let title = expense.title.lowercased()
        if title.contains("food") || title.contains("dinner") || title.contains("lunch") || title.contains("restaurant") {
            return .orange
        } else if title.contains("hotel") || title.contains("stay") || title.contains("airbnb") {
            return .purple
        } else if title.contains("transport") || title.contains("taxi") || title.contains("uber") || title.contains("flight") {
            return .blue
        } else if title.contains("ticket") || title.contains("museum") || title.contains("activity") {
            return .pink
        }
        return .indigo
    }
}

// MARK: - Preview

#Preview("Group Detail") {
    NavigationStack {
        GroupDetailView(trip: PreviewSampleData.sampleGroup)
    }
    .modelContainer(PreviewSampleData.container)
}
