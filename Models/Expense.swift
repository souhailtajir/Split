//
//  Expense.swift
//  Split
//
//  Created by Souhail on 8/3/26.
//

import Foundation
import SwiftData

public enum ExpenseSplitMethod: String, Codable, Sendable, CaseIterable {
    case equally
    case byShares // custom weights
    case byExactAmounts
}

@Model
@MainActor
final class Expense: LocalMutationTrackable {
    // MARK: - Identity & sync metadata
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var lastModifiedByDeviceID: String?
    var changeCounter: Int
    var isTombstoned: Bool

    // MARK: - Domain
    var title: String
    var amount: Decimal
    var currencyCode: String
    var date: Date
    var notes: String?
    var splitMethodRaw: String

    var splitMethod: ExpenseSplitMethod {
        get { ExpenseSplitMethod(rawValue: splitMethodRaw) ?? .equally }
        set { splitMethodRaw = newValue.rawValue }
    }

    // Relationships
    var trip: Trip?

    // Payer (one)
    var paidBy: Participant?

    // Shared with (many)
    var sharedWith: [Participant] = []

    // MARK: - Init
    init(
        id: UUID = UUID(),
        title: String,
        amount: Decimal,
        currencyCode: String,
        date: Date = .now,
        notes: String? = nil,
        splitMethod: ExpenseSplitMethod = .equally,
        trip: Trip? = nil,
        paidBy: Participant? = nil,
        sharedWith: [Participant] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now,
        lastModifiedByDeviceID: String? = nil,
        changeCounter: Int = 0,
        isTombstoned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.currencyCode = currencyCode
        self.date = date
        self.notes = notes
        self.splitMethodRaw = splitMethod.rawValue
        self.trip = trip
        self.paidBy = paidBy
        self.sharedWith = sharedWith
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastModifiedByDeviceID = lastModifiedByDeviceID
        self.changeCounter = changeCounter
        self.isTombstoned = isTombstoned
    }
}
