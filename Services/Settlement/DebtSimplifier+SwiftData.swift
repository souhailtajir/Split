//
//  DebtSimplifier+SwiftData.swift
//  Split
//
//  Created by Souhail on 8/3/26.
//

import Foundation
import SwiftData

// MARK: - SwiftData ↔ Settlement Bridge

/// Convenience extensions to convert SwiftData `@Model` objects into the pure
/// value types consumed by `DebtSimplifier`, and to run the simplification
/// directly from a `Trip`.
extension DebtSimplifier {

    /// Converts a SwiftData `Participant` to a `SettlementParticipant`.
    @MainActor
    static func settlementParticipant(from model: Participant) -> SettlementParticipant {
        SettlementParticipant(id: model.id, handle: model.handle)
    }

    /// Converts a SwiftData `Expense` to a `SettlementExpense`.
    @MainActor
    static func settlementExpense(from model: Expense) -> SettlementExpense? {
        guard let payer = model.paidBy else { return nil }
        let sharedIDs = model.sharedWith.map(\.id)

        let method: SettlementSplitMethod
        switch model.splitMethod {
        case .equally:
            method = .equally
        case .byShares:
            // TODO: When custom share weights are stored on the model, map them here.
            // For now, default to equal weight (1) per participant.
            method = .byShares(Dictionary(uniqueKeysWithValues: sharedIDs.map { ($0, 1) }))
        case .byExactAmounts:
            // TODO: When exact per-person amounts are stored on the model, map them here.
            // Falls back to equal split as a safety net.
            method = .equally
        }

        return SettlementExpense(
            amount: model.amount,
            paidByID: payer.id,
            sharedWithIDs: sharedIDs,
            splitMethod: method
        )
    }

    /// Computes minimal settlements for an entire `Trip`.
    ///
    /// - Parameter trip: A SwiftData `Trip` with its participants and expenses loaded.
    /// - Returns: An array of `Settlement` directives.
    @MainActor
    static func simplify(trip: Trip) -> [Settlement] {
        let participants = trip.participants
            .filter { !$0.isTombstoned }
            .map { settlementParticipant(from: $0) }

        let expenses = trip.expenses
            .filter { !$0.isTombstoned }
            .compactMap { settlementExpense(from: $0) }

        return simplify(participants: participants, expenses: expenses)
    }
}
