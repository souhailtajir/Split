//
//  TripsView.swift
//  Split
//
//  Created by Souhail on 8/3/26.
//

import SwiftUI
import SwiftData

struct TripsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(
        filter: #Predicate<Trip> { !$0.isTombstoned },
        sort: \Trip.createdAt,
        order: .reverse
    )
    private var trips: [Trip]

    @State private var showingNewTrip = false
    @State private var newTripName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientMeshBackground(style: .trips)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Hero Summary Card (Apple Card style)
                        heroSummaryCard

                        // Section Header
                        HStack {
                            Text("Your Trips")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(.primary)

                            Spacer()

                            GlassActionButton(title: "New Trip", systemImage: "plus", accentColor: .indigo) {
                                showingNewTrip = true
                            }
                        }
                        .padding(.horizontal, 4)

                        // Trip Deck
                        if trips.isEmpty {
                            emptyStateCard
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(trips) { trip in
                                    NavigationLink {
                                        TripDetailView(trip: trip)
                                    } label: {
                                        AppleCardTripRow(trip: trip)
                                    }
                                    .buttonStyle(.appleCard)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            softDelete(trip: trip)
                                        } label: {
                                            Label("Delete Trip", systemImage: "trash")
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
            .navigationTitle("Trips")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingNewTrip) {
                newTripSheet
            }
        }
    }

    // MARK: - Hero Summary Card

    private var heroSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PORTFOLIO OVERVIEW")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .tracking(1.0)

                    Text(allTripsTotalSpend.formatted(.currency(code: primaryCurrencyCode)))
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

            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "airplane")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    Text("\(trips.count) Trips")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.white.opacity(0.15), in: .capsule)

                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    Text("\(totalUniqueParticipants) Members")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.white.opacity(0.15), in: .capsule)
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
            Image(systemName: "airplane.departure")
                .font(.system(size: 44))
                .foregroundStyle(.indigo.gradient)
                .padding(.top, 12)

            VStack(spacing: 6) {
                Text("No Active Trips")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Create your first trip to start splitting shared expenses with clear glass styling.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            GlassActionButton(title: "Create New Trip", systemImage: "plus.circle.fill", accentColor: .indigo) {
                showingNewTrip = true
            }
            .padding(.bottom, 8)
        }
        .padding(24)
        .appleCardStyle()
    }

    // MARK: - New Trip Sheet

    private var newTripSheet: some View {
        NavigationStack {
            ZStack {
                AmbientMeshBackground(style: .trips)

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TRIP NAME")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)

                        TextField("e.g. Summer in Lisbon, Tokyo 2026", text: $newTripName)
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .padding()
                            .background(colorScheme == .dark ? .ultraThinMaterial : .regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.1), lineWidth: 1)
                            }
                    }

                    Spacer()

                    Button {
                        createTrip()
                    } label: {
                        Text("Create Trip")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                newTripName.trimmingCharacters(in: .whitespaces).isEmpty
                                ? AnyShapeStyle(Color.gray.opacity(0.4))
                                : AnyShapeStyle(Color.indigo.gradient),
                                in: RoundedRectangle(cornerRadius: 18)
                            )
                    }
                    .disabled(newTripName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .buttonStyle(.appleCard)
                }
                .padding(24)
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newTripName = ""
                        showingNewTrip = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Computed Properties

    private var allTripsTotalSpend: Decimal {
        trips.reduce(.zero) { sum, trip in
            sum + trip.expenses.filter { !$0.isTombstoned }.reduce(.zero) { $0 + $1.amount }
        }
    }

    private var totalUniqueParticipants: Int {
        Set(trips.flatMap { $0.participants.filter { !$0.isTombstoned }.map(\.id) }).count
    }

    private var primaryCurrencyCode: String {
        trips.flatMap(\.expenses).first(where: { !$0.isTombstoned })?.currencyCode
            ?? Locale.current.currency?.identifier ?? "USD"
    }

    // MARK: - Actions

    private func createTrip() {
        let name = newTripName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            let trip = Trip(name: name, startDate: .now)
            modelContext.insert(trip)
        }
        newTripName = ""
        showingNewTrip = false
    }

    private func softDelete(trip: Trip) {
        withAnimation(.smooth) {
            trip.isTombstoned = true
            trip.updatedAt = .now
        }
    }
}

// MARK: - Apple Card Trip Row Component

struct AppleCardTripRow: View {
    let trip: Trip

    private var activeExpenses: [Expense] {
        trip.expenses.filter { !$0.isTombstoned }
    }

    private var activeParticipants: [Participant] {
        trip.participants.filter { !$0.isTombstoned }
    }

    private var totalSpend: Decimal {
        activeExpenses.reduce(.zero) { $0 + $1.amount }
    }

    private var currencyCode: String {
        activeExpenses.first?.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon Badge
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(cardAccentColor.gradient)
                    .frame(width: 52, height: 52)
                    .shadow(color: cardAccentColor.opacity(0.35), radius: 6, x: 0, y: 3)

                Image(systemName: "airplane")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(trip.name)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    if let start = trip.startDate {
                        Label(start.formatted(.dateTime.month(.abbreviated).day()), systemImage: "calendar")
                    }
                    Label("\(activeParticipants.count)", systemImage: "person.2.fill")
                    Label("\(activeExpenses.count)", systemImage: "receipt")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(totalSpend.formatted(.currency(code: currencyCode)))
                    .font(.system(.callout, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .appleCardStyle(cornerRadius: 20)
    }

    private var cardAccentColor: Color {
        let colors: [Color] = [.indigo, .blue, .purple, .teal, .orange]
        return colors[abs(trip.id.hashValue) % colors.count]
    }
}
