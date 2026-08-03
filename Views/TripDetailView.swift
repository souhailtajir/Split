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
    @Bindable var trip: Trip

    @State private var showingAddExpense = false

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

    private var primaryCurrencyCode: String {
        activeExpenses.first?.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
    }

    // MARK: - Body

    var body: some View {
        List {
            headerSection
            expensesSection
            summarySection
        }
        .listStyle(.plain)
        .navigationTitle(trip.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddExpense = true
                } label: {
                    Label("Add Expense", systemImage: "plus.circle.fill")
                }
                .glassEffect()
            }

            ToolbarItem(placement: .automatic) {
                NavigationLink {
                    SettlementView(trip: trip)
                } label: {
                    Label("Settle Up", systemImage: "arrow.triangle.swap")
                }
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView(trip: trip)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        Section {
            VStack(spacing: 16) {
                // Date range
                if let start = trip.startDate {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        Text(dateRangeText(start: start, end: trip.endDate))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Participant avatars
                if !activeParticipants.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Participants")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: -8) {
                                ForEach(activeParticipants) { participant in
                                    ParticipantAvatarView(participant: participant)
                                }
                            }
                        }
                    }
                }

                // Total spend
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total Spent")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        Text(totalSpend.formatted(.currency(code: primaryCurrencyCode)))
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Expenses")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        Text("\(activeExpenses.count)")
                            .font(.system(.title2, design: .rounded, weight: .semibold))
                            .contentTransition(.numericText())
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .glassEffect()
        )
    }

    // MARK: - Expenses Section

    private var expensesSection: some View {
        Section {
            if activeExpenses.isEmpty {
                emptyExpensesView
            } else {
                ForEach(activeExpenses) { expense in
                    ExpenseRowView(expense: expense)
                }
                .onDelete(perform: softDeleteExpenses)
            }
        } header: {
            Label("Expenses", systemImage: "list.bullet.rectangle.portrait")
        }
    }

    private var emptyExpensesView: some View {
        ContentUnavailableView {
            Label("No Expenses Yet", systemImage: "creditcard")
        } description: {
            Text("Tap the + button to add your first expense to this trip.")
        } actions: {
            Button {
                showingAddExpense = true
            } label: {
                Text("Add Expense")
            }
            .buttonStyle(.borderedProminent)
        }
        .listRowBackground(Color.clear)
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        Section {
            HStack {
                Label {
                    Text("\(activeParticipants.count) participants")
                } icon: {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(.teal)
                }
                Spacer()
                if !activeExpenses.isEmpty {
                    Text(perPersonAverage.formatted(.currency(code: primaryCurrencyCode)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("avg/person")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            Label("Summary", systemImage: "chart.pie.fill")
        }
    }

    private var perPersonAverage: Decimal {
        guard !activeParticipants.isEmpty else { return .zero }
        return totalSpend / Decimal(activeParticipants.count)
    }

    // MARK: - Actions

    private func softDeleteExpenses(at offsets: IndexSet) {
        withAnimation(.smooth) {
            let expenses = activeExpenses
            for index in offsets {
                expenses[index].isTombstoned = true
                expenses[index].updatedAt = .now
            }
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

// MARK: - Expense Row

private struct ExpenseRowView: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            ZStack {
                Circle()
                    .fill(categoryColor.gradient)
                    .frame(width: 40, height: 40)
                Image(systemName: categoryIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            // Details
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let payer = expense.paidBy {
                        Text("Paid by \(payer.handle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("·")
                        .foregroundStyle(.quaternary)
                    Text(splitMethodBadge)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: .capsule)
                }
            }

            Spacer()

            // Amount and date
            VStack(alignment: .trailing, spacing: 3) {
                Text(expense.amount.formatted(.currency(code: expense.currencyCode)))
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                Text(expense.date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
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
        } else if title.contains("hotel") || title.contains("stay") || title.contains("accommodation") {
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
        } else if title.contains("hotel") || title.contains("stay") || title.contains("accommodation") {
            return .purple
        } else if title.contains("transport") || title.contains("taxi") || title.contains("uber") || title.contains("flight") {
            return .blue
        } else if title.contains("ticket") || title.contains("museum") || title.contains("activity") {
            return .pink
        }
        return .indigo
    }
}

// MARK: - Participant Avatar

struct ParticipantAvatarView: View {
    let participant: Participant

    var body: some View {
        ZStack {
            Circle()
                .fill(avatarColor.gradient)
                .frame(width: 38, height: 38)
            Circle()
                .strokeBorder(.background, lineWidth: 2)
                .frame(width: 38, height: 38)
            Text(initials)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .help(participant.fullName ?? participant.handle)
    }

    private var initials: String {
        if let fullName = participant.fullName, !fullName.isEmpty {
            let components = fullName.split(separator: " ")
            return components.prefix(2).map { String($0.prefix(1)) }.joined().uppercased()
        }
        return String(participant.handle.prefix(2)).uppercased()
    }

    private var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .pink, .orange, .teal, .indigo, .mint, .cyan]
        let index = abs(participant.id.hashValue) % colors.count
        return colors[index]
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TripDetailView(trip: Trip(name: "Lisbon 2026"))
    }
    .modelContainer(for: Trip.self, inMemory: true)
}
