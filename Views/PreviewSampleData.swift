//
//  PreviewSampleData.swift
//  Split
//
//  Created by Souhail on 8/4/26.
//

import SwiftData
import SwiftUI

// MARK: - Preview Model Container

/// A shared, in-memory `ModelContainer` for Xcode Canvas previews.
///
/// Usage inside any `#Preview`:
/// ```swift
/// #Preview {
///     MyView()
///         .modelContainer(PreviewSampleData.container)
/// }
/// ```
enum PreviewSampleData {

    /// In-memory container with the full schema.
    @MainActor
    static var container: ModelContainer = {
        let schema = Schema([
            Item.self,
            Trip.self,
            Participant.self,
            Expense.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            insertSampleData(into: container.mainContext)
            return container
        } catch {
            fatalError("PreviewSampleData: failed to create ModelContainer – \(error)")
        }
    }()

    /// An empty in-memory container (no sample data).
    @MainActor
    static var emptyContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            Trip.self,
            Participant.self,
            Expense.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("PreviewSampleData: failed to create empty ModelContainer – \(error)")
        }
    }()

    // MARK: - Sample Data

    /// Inserts a representative set of groups, participants, and expenses
    /// so previews look realistic.
    @MainActor
    static func insertSampleData(into context: ModelContext) {
        // Group 1: A trip
        let trip = Trip(name: "Summer in Lisbon", startDate: .now.addingTimeInterval(-86_400 * 5))
        context.insert(trip)

        let alice = Participant(handle: "alice", fullName: "Alice Martin", trip: trip)
        let bob   = Participant(handle: "bob", fullName: "Bob Chen", trip: trip)
        let carol = Participant(handle: "carol", fullName: "Carol Díaz", trip: trip)
        context.insert(alice)
        context.insert(bob)
        context.insert(carol)

        let dinner = Expense(
            title: "Dinner at Time Out Market",
            amount: 87.50,
            currencyCode: "EUR",
            date: .now.addingTimeInterval(-86_400 * 4),
            splitMethod: .equally,
            trip: trip,
            paidBy: alice,
            sharedWith: [alice, bob, carol]
        )
        let taxi = Expense(
            title: "Taxi to Belém",
            amount: 22.00,
            currencyCode: "EUR",
            date: .now.addingTimeInterval(-86_400 * 3),
            splitMethod: .equally,
            trip: trip,
            paidBy: bob,
            sharedWith: [alice, bob, carol]
        )
        let museum = Expense(
            title: "Museum tickets",
            amount: 36.00,
            currencyCode: "EUR",
            date: .now.addingTimeInterval(-86_400 * 2),
            splitMethod: .equally,
            trip: trip,
            paidBy: carol,
            sharedWith: [alice, bob, carol]
        )
        context.insert(dinner)
        context.insert(taxi)
        context.insert(museum)

        // Group 2: A shared house
        let house = Trip(name: "Apartment Q3 2026", startDate: .now.addingTimeInterval(-86_400 * 30))
        context.insert(house)

        let dave = Participant(handle: "dave", fullName: "Dave Kim", trip: house)
        let emma = Participant(handle: "emma", fullName: "Emma Novak", trip: house)
        context.insert(dave)
        context.insert(emma)

        let rent = Expense(
            title: "August Rent",
            amount: 1_400.00,
            currencyCode: "USD",
            date: .now.addingTimeInterval(-86_400),
            splitMethod: .equally,
            trip: house,
            paidBy: dave,
            sharedWith: [dave, emma]
        )
        context.insert(rent)
    }

    // MARK: - Single-Group Preview Helper

    /// Returns the first `Trip` from the sample container, useful for detail-view previews.
    @MainActor
    static var sampleGroup: Trip {
        let descriptor = FetchDescriptor<Trip>(sortBy: [SortDescriptor(\.createdAt)])
        return (try? container.mainContext.fetch(descriptor).first) ?? Trip(name: "Preview Group")
    }
}
