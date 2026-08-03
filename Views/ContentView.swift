//
//  ContentView.swift
//  Split
//
//  Created by Souhail on 8/3/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
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
            Group {
                if trips.isEmpty {
                    emptyStateView
                } else {
                    tripListView
                }
            }
            .navigationTitle("Trips")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewTrip = true
                    } label: {
                        Label("New Trip", systemImage: "plus.circle.fill")
                    }
                    .glassEffect()
                }
            }
            .alert("New Trip", isPresented: $showingNewTrip) {
                TextField("Trip name", text: $newTripName)
                Button("Create") { createTrip() }
                    .disabled(newTripName.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Cancel", role: .cancel) { newTripName = "" }
            } message: {
                Text("Enter a name for your new trip.")
            }
        }
    }

    // MARK: - Trip List

    private var tripListView: some View {
        List {
            ForEach(trips) { trip in
                NavigationLink {
                    TripDetailView(trip: trip)
                } label: {
                    TripRowView(trip: trip)
                }
            }
            .onDelete(perform: softDeleteTrips)
        }
        .listStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Trips", systemImage: "airplane.departure")
        } description: {
            Text("Create your first trip to start tracking shared expenses.")
        } actions: {
            Button {
                showingNewTrip = true
            } label: {
                Text("Create Trip")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Actions

    private func createTrip() {
        let name = newTripName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        withAnimation(.smooth) {
            let trip = Trip(name: name, startDate: .now)
            modelContext.insert(trip)
        }
        newTripName = ""
    }

    private func softDeleteTrips(at offsets: IndexSet) {
        withAnimation(.smooth) {
            for index in offsets {
                trips[index].isTombstoned = true
                trips[index].updatedAt = .now
            }
        }
    }
}

// MARK: - Trip Row

private struct TripRowView: View {
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
        HStack(spacing: 14) {
            // Trip icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor.gradient)
                    .frame(width: 44, height: 44)
                Image(systemName: "airplane")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(trip.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let start = trip.startDate {
                        Label(start.formatted(.dateTime.month(.abbreviated).day()), systemImage: "calendar")
                    }
                    if !activeParticipants.isEmpty {
                        Label("\(activeParticipants.count)", systemImage: "person.2")
                    }
                    if !activeExpenses.isEmpty {
                        Label("\(activeExpenses.count)", systemImage: "list.bullet")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if !activeExpenses.isEmpty {
                Text(totalSpend.formatted(.currency(code: currencyCode)))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(for: Trip.self, inMemory: true)
}
