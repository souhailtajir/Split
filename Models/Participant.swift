//
//  Participant.swift
//  Split
//
//  Created by Souhail on 8/3/26.
//

import Foundation
import SwiftData

@Model
@MainActor
final class Participant: LocalMutationTrackable {
    // MARK: - Identity & sync metadata
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var lastModifiedByDeviceID: String?
    var changeCounter: Int
    var isTombstoned: Bool

    // MARK: - Domain
    @Attribute(.unique) var handle: String // display name or unique handle within app
    var fullName: String?

    // Owning trip
    var trip: Trip?

    // Expenses this participant paid or is involved in
    var expensesPaid: [Expense] = []

    var expensesShared: [Expense] = []

    // MARK: - Init
    init(
        id: UUID = UUID(),
        handle: String,
        fullName: String? = nil,
        trip: Trip? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        lastModifiedByDeviceID: String? = nil,
        changeCounter: Int = 0,
        isTombstoned: Bool = false
    ) {
        self.id = id
        self.handle = handle
        self.fullName = fullName
        self.trip = trip
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastModifiedByDeviceID = lastModifiedByDeviceID
        self.changeCounter = changeCounter
        self.isTombstoned = isTombstoned
        self.expensesPaid = []
        self.expensesShared = []
    }
}
