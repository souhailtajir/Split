//
//  TripDetailView.swift
//  Split
//
//  Created by Souhail on 8/3/26.
//

import SwiftUI
import SwiftData

struct TripDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var trip: Trip

    @State private var showingAddExpense = false
    @State private var selectedExpense: Expense?

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
            AmbientMeshBackground(style: .trips)

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
            ToolbarItem(placement: .primaryAction) {
                GlassActionButton(title: "Add", systemImage: "plus", accentColor: .indigo) {
                    showingAddExpense = true
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettlementView(trip: trip)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.caption.weight(.bold))
                        Text("Settle Up")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial, in: .capsule)
                    .overlay {
                        Capsule().stroke(colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.1), lineWidth: 1)
                    }
                }
                .buttonStyle(.appleCard)
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView(trip: trip)
        }
    }

    // MARK: - Header Hero Card

    private var headerHeroCard: some View {
        VStack(spacing: 16) {
            // Date Range Capsule
            if let start = trip.startDate {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(dateRangeText(start: start, end: trip.endDate))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.95))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(.white.opacity(0.15), in: .capsule)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Total Spend Counter
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL SPENT")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .tracking(1.0)

                    Text(totalSpend.formatted(.currency(code: primaryCurrencyCode)))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("AVG / MEMBER")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(perPersonAverage.formatted(.currency(code: primaryCurrencyCode)))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.indigo, .purple, .blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.25), lineWidth: 1)
                }
                .shadow(color: .indigo.opacity(colorScheme == .dark ? 0.35 : 0.2), radius: 14, x: 0, y: 6)
        }
    }

    // MARK: - Participants Card

    private var participantsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Trip Members", systemImage: "person.2.fill")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(activeParticipants.count) active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if activeParticipants.isEmpty {
                Text("No participants added yet.")
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
                            .background(colorScheme == .dark ? .white.opacity(0.06) : .black.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
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

                Button {
                    showingAddExpense = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.indigo)
                }
                .buttonStyle(.appleCard)
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
            Text("Tap the + button to log shared payments for this trip.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func softDeleteExpense(_ expense: Expense) {
        withAnimation(.smooth) {
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

    @Environment(\.colorScheme) private var colorScheme

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
                        .background(colorScheme == .dark ? .white.opacity(0.12) : .black.opacity(0.06), in: .capsule)
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
        .background(colorScheme == .dark ? .white.opacity(0.05) : .black.opacity(0.03), in: RoundedRectangle(cornerRadius: 16))
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
