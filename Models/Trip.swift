//
//  Trip.swift
//  Split
//
//  Created by Souhail on 8/3/26.
//

import Foundation
import SwiftData

@Model
@MainActor
final class Trip: LocalMutationTrackable {
    // MARK: - Identity & sync metadata
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var lastModifiedByDeviceID: String?
    var changeCounter: Int
    var isTombstoned: Bool

    // MARK: - Domain
    var name: String
    var startDate: Date?
    var endDate: Date?

    // Participants in the trip
    @Relationship(deleteRule: .cascade, inverse: \Participant.trip)
    var participants: [Participant]

    // Expenses associated with the trip
    @Relationship(deleteRule: .cascade, inverse: \Expense.trip)
    var expenses: [Expense]

    // MARK: - Init
    init(
        id: UUID = UUID(),
        name: String,
        startDate: Date? = nil,
        endDate: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        lastModifiedByDeviceID: String? = nil,
        changeCounter: Int = 0,
        isTombstoned: Bool = false
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastModifiedByDeviceID = lastModifiedByDeviceID
        self.changeCounter = changeCounter
        self.isTombstoned = isTombstoned
        self.participants = []
        self.expenses = []
    }
}
