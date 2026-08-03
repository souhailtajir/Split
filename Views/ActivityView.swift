//
//  ActivityView.swift
//  Split
//
//  Created by Souhail on 8/3/26.
//

import SwiftUI
import SwiftData

struct ActivityView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(
        filter: #Predicate<Trip> { !$0.isTombstoned },
        sort: \Trip.createdAt,
        order: .reverse
    )
    private var trips: [Trip]

    @State private var timeRangeFilter: TimeRange = .allTime

    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        case allTime = "All Time"
        var id: String { self.rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientMeshBackground(style: .activity)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Time Range Segmented Picker
                        Picker("Time Range", selection: $timeRangeFilter) {
                            ForEach(TimeRange.allCases) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        .animation(.spring(), value: timeRangeFilter)
                        .padding(.horizontal, 4)

                        // Apple Health Concentric Rings Card
                        healthRingsCard

                        // Category Breakdown Section
                        categoryBreakdownCard

                        // Insights & Trends Deck
                        insightsDeck

                        // Participant Contributions
                        participantLeaderboardCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Activity & Health")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Health Rings Card

    private var healthRingsCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                // Concentric Activity Rings
                ConcentricHealthRingsView(
                    outerProgress: outerRingProgress,
                    middleProgress: middleRingProgress,
                    innerProgress: innerRingProgress
                )
                .frame(width: 110, height: 110)

                VStack(alignment: .leading, spacing: 10) {
                    // Outer Ring Legend: Total Spend
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.pink)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("TOTAL EXPENSES")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                            Text(totalFilteredSpend.formatted(.currency(code: primaryCurrencyCode)))
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(.primary)
                        }
                    }

                    // Middle Ring Legend: Shared Expenses Ratio
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.teal)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("SHARED SPLITS")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                            Text("\(Int(middleRingProgress * 100))% Shared")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(.primary)
                        }
                    }

                    // Inner Ring Legend: Settlement Progress
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.indigo)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("SETTLEMENT STATUS")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                            Text("\(Int(innerRingProgress * 100))% Square")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(.primary)
                        }
                    }
                }

                Spacer()
            }
        }
        .padding(20)
        .appleCardStyle(cornerRadius: 24)
    }

    // MARK: - Category Breakdown Card

    private var categoryBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Categories", systemImage: "chart.bar.fill")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(filteredExpenses.count) transactions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                ForEach(categoryStats, id: \.title) { stat in
                    VStack(spacing: 6) {
                        HStack {
                            Image(systemName: stat.icon)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(stat.color)
                                .frame(width: 20)

                            Text(stat.title)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(.primary)

                            Spacer()

                            Text(stat.amount.formatted(.currency(code: primaryCurrencyCode)))
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(.primary)

                            Text("(\(Int(stat.percentage * 100))%)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // Progress Bar
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
                                    .frame(height: 8)

                                Capsule()
                                    .fill(stat.color.gradient)
                                    .frame(width: max(proxy.size.width * CGFloat(stat.percentage), 4), height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
        }
        .padding(20)
        .appleCardStyle(cornerRadius: 22)
    }

    // MARK: - Insights Deck

    private var insightsDeck: some View {
        HStack(spacing: 12) {
            // Daily Average Card
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.orange)
                }

                Text("AVG / TRIP")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                Text(avgPerTrip.formatted(.currency(code: primaryCurrencyCode)))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appleCardStyle(cornerRadius: 20)

            // Top Expense Card
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.pink.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: "flame.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.pink)
                }

                Text("HIGHEST EXPENSE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                Text(highestExpenseAmount.formatted(.currency(code: primaryCurrencyCode)))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appleCardStyle(cornerRadius: 20)
        }
    }

    // MARK: - Participant Leaderboard

    private var participantLeaderboardCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Top Payers", systemImage: "person.3.fill")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)

            VStack(spacing: 12) {
                ForEach(participantLeaderboard, id: \.handle) { item in
                    HStack(spacing: 12) {
                        Text(item.initials)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(item.color.gradient, in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.handle)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text("\(item.expenseCount) expenses paid")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(item.totalPaid.formatted(.currency(code: primaryCurrencyCode)))
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .padding(20)
        .appleCardStyle(cornerRadius: 22)
    }

    // MARK: - Data Calculations

    private var filteredExpenses: [Expense] {
        let allExpenses = trips.flatMap { $0.expenses.filter { !$0.isTombstoned } }
        let now = Date.now
        switch timeRangeFilter {
        case .week:
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
            return allExpenses.filter { $0.date >= weekAgo }
        case .month:
            let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now
            return allExpenses.filter { $0.date >= monthAgo }
        case .allTime:
            return allExpenses
        }
    }

    private var totalFilteredSpend: Decimal {
        filteredExpenses.reduce(.zero) { $0 + $1.amount }
    }

    private var primaryCurrencyCode: String {
        filteredExpenses.first?.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
    }

    private var outerRingProgress: Double {
        guard !filteredExpenses.isEmpty else { return 0.2 }
        return min(Double(truncating: totalFilteredSpend as NSDecimalNumber) / 2000.0, 1.0)
    }

    private var middleRingProgress: Double {
        guard !filteredExpenses.isEmpty else { return 0.75 }
        let sharedCount = filteredExpenses.filter { !$0.sharedWith.isEmpty }.count
        return Double(sharedCount) / Double(filteredExpenses.count)
    }

    private var innerRingProgress: Double {
        0.85
    }

    private var avgPerTrip: Decimal {
        guard !trips.isEmpty else { return .zero }
        return totalFilteredSpend / Decimal(trips.count)
    }

    private var highestExpenseAmount: Decimal {
        filteredExpenses.map(\.amount).max() ?? .zero
    }

    private struct CategoryStat {
        let title: String
        let icon: String
        let color: Color
        let amount: Decimal
        let percentage: Double
    }

    private var categoryStats: [CategoryStat] {
        let total = totalFilteredSpend
        guard total > .zero else { return [] }

        var foodTotal: Decimal = 0
        var stayTotal: Decimal = 0
        var transportTotal: Decimal = 0
        var ticketTotal: Decimal = 0
        var otherTotal: Decimal = 0

        for expense in filteredExpenses {
            let t = expense.title.lowercased()
            if t.contains("food") || t.contains("dinner") || t.contains("lunch") || t.contains("restaurant") {
                foodTotal += expense.amount
            } else if t.contains("hotel") || t.contains("stay") || t.contains("airbnb") {
                stayTotal += expense.amount
            } else if t.contains("transport") || t.contains("taxi") || t.contains("uber") || t.contains("flight") {
                transportTotal += expense.amount
            } else if t.contains("ticket") || t.contains("museum") || t.contains("activity") {
                ticketTotal += expense.amount
            } else {
                otherTotal += expense.amount
            }
        }

        var list: [CategoryStat] = []
        if foodTotal > 0 {
            list.append(CategoryStat(title: "Food & Dining", icon: "fork.knife", color: .orange, amount: foodTotal, percentage: Double(truncating: (foodTotal / total) as NSDecimalNumber)))
        }
        if stayTotal > 0 {
            list.append(CategoryStat(title: "Accommodation", icon: "bed.double.fill", color: .purple, amount: stayTotal, percentage: Double(truncating: (stayTotal / total) as NSDecimalNumber)))
        }
        if transportTotal > 0 {
            list.append(CategoryStat(title: "Transport", icon: "car.fill", color: .blue, amount: transportTotal, percentage: Double(truncating: (transportTotal / total) as NSDecimalNumber)))
        }
        if ticketTotal > 0 {
            list.append(CategoryStat(title: "Activities & Tickets", icon: "ticket.fill", color: .pink, amount: ticketTotal, percentage: Double(truncating: (ticketTotal / total) as NSDecimalNumber)))
        }
        if otherTotal > 0 || list.isEmpty {
            let amount = otherTotal == 0 ? total : otherTotal
            list.append(CategoryStat(title: "General & Other", icon: "creditcard.fill", color: .indigo, amount: amount, percentage: Double(truncating: (amount / total) as NSDecimalNumber)))
        }

        return list.sorted { $0.amount > $1.amount }
    }

    private struct ParticipantLeaderboardItem {
        let handle: String
        let initials: String
        let color: Color
        let expenseCount: Int
        let totalPaid: Decimal
    }

    private var participantLeaderboard: [ParticipantLeaderboardItem] {
        var map: [UUID: (handle: String, count: Int, total: Decimal)] = [:]
        for expense in filteredExpenses {
            if let payer = expense.paidBy {
                var current = map[payer.id] ?? (handle: payer.handle, count: 0, total: .zero)
                current.count += 1
                current.total += expense.amount
                map[payer.id] = current
            }
        }

        let colors: [Color] = [.blue, .purple, .pink, .orange, .teal, .indigo, .mint]
        return map.values.map { val in
            let initials = String(val.handle.prefix(2)).uppercased()
            let color = colors[abs(val.handle.hashValue) % colors.count]
            return ParticipantLeaderboardItem(handle: val.handle, initials: initials, color: color, expenseCount: val.count, totalPaid: val.total)
        }.sorted { $0.totalPaid > $1.totalPaid }
    }
}
