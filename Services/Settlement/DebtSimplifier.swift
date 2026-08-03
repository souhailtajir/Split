//
//  DebtSimplifier.swift
//  Split
//
//  Created by Souhail on 8/3/26.
//

import Foundation

// MARK: - Pure Value Types (decoupled from SwiftData)

/// Lightweight representation of a participant for the settlement engine.
struct SettlementParticipant: Hashable, Identifiable, Sendable {
    let id: UUID
    let handle: String
}

/// Describes how a single expense is split among participants.
enum SettlementSplitMethod: Sendable {
    /// Equal split across all `sharedWith` participants.
    case equally
    /// Each participant has a relative weight (share count).
    /// Keys must be a subset of `sharedWith` participant IDs.
    case byShares([UUID: Int])
    /// Each participant owes a fixed amount.
    /// Keys must be a subset of `sharedWith` participant IDs.
    /// Values should sum to the expense's total `amount`.
    case byExactAmounts([UUID: Decimal])
}

/// A self-contained expense record the engine can process without touching SwiftData.
struct SettlementExpense: Sendable {
    let amount: Decimal
    let paidByID: UUID
    let sharedWithIDs: [UUID]
    let splitMethod: SettlementSplitMethod
}

/// A single "X pays Y" directive that settles debt.
struct Settlement: Sendable, Equatable {
    /// The participant who owes money.
    let from: SettlementParticipant
    /// The participant who is owed money.
    let to: SettlementParticipant
    /// The positive amount `from` should pay `to`.
    let amount: Decimal
}

// MARK: - Engine

/// A pure, stateless debt-simplification engine.
///
/// Given a list of participants and expenses with varying split configurations,
/// it computes each person's net balance and then minimizes the number of
/// direct settlement transactions using a greedy max-heap approach.
///
/// **Complexity**: O(E·P) for balance computation + O(P log P) for minimization,
/// where E = number of expenses and P = number of participants.
enum DebtSimplifier {

    // MARK: - Public API

    /// Computes the minimal set of settlement transactions for the given
    /// participants and expenses.
    ///
    /// - Parameters:
    ///   - participants: All participants in the group/trip.
    ///   - expenses: All expenses to settle.
    /// - Returns: An array of `Settlement` values representing the fewest
    ///   possible direct payments needed to settle all debts.
    static func simplify(
        participants: [SettlementParticipant],
        expenses: [SettlementExpense]
    ) -> [Settlement] {
        let balances = computeNetBalances(participants: participants, expenses: expenses)
        return minimizeTransactions(balances: balances, participants: participants)
    }

    /// Computes the net balance for every participant.
    ///
    /// A **positive** balance means the participant is owed money (creditor).
    /// A **negative** balance means the participant owes money (debtor).
    ///
    /// - Returns: A dictionary mapping participant IDs to their net balance.
    static func computeNetBalances(
        participants: [SettlementParticipant],
        expenses: [SettlementExpense]
    ) -> [UUID: Decimal] {
        // Start everyone at zero.
        var balances: [UUID: Decimal] = Dictionary(
            uniqueKeysWithValues: participants.map { ($0.id, Decimal.zero) }
        )

        for expense in expenses {
            let shares = splitAmounts(for: expense)
            // The payer fronted the whole bill → credit them.
            balances[expense.paidByID, default: .zero] += expense.amount
            // Each participant that shared the expense is debited their portion.
            for (participantID, owed) in shares {
                balances[participantID, default: .zero] -= owed
            }
        }

        return balances
    }

    // MARK: - Split Logic

    /// Calculates how much each participant owes for a single expense
    /// according to its split method.
    ///
    /// - Returns: A dictionary mapping participant ID → amount owed.
    static func splitAmounts(for expense: SettlementExpense) -> [UUID: Decimal] {
        switch expense.splitMethod {
        case .equally:
            return splitEqually(amount: expense.amount, among: expense.sharedWithIDs)

        case .byShares(let shareMap):
            return splitByShares(
                amount: expense.amount,
                among: expense.sharedWithIDs,
                shares: shareMap
            )

        case .byExactAmounts(let exactMap):
            return splitByExactAmounts(among: expense.sharedWithIDs, amounts: exactMap)
        }
    }

    // MARK: - Private Helpers

    /// Equal split with banker's rounding.
    /// Any leftover cents from rounding are assigned to the first participant
    /// to guarantee the amounts sum exactly to `amount`.
    private static func splitEqually(
        amount: Decimal,
        among participantIDs: [UUID]
    ) -> [UUID: Decimal] {
        guard !participantIDs.isEmpty else { return [:] }
        let count = Decimal(participantIDs.count)
        var perPerson = amount / count

        // Round to 2 decimal places (cents).
        var rounded = Decimal()
        NSDecimalRound(&rounded, &perPerson, 2, .bankers)
        perPerson = rounded

        var result: [UUID: Decimal] = [:]
        for id in participantIDs {
            result[id] = perPerson
        }

        // Distribute rounding remainder to the first participant.
        let distributed = perPerson * count
        let remainder = amount - distributed
        if remainder != .zero, let firstID = participantIDs.first {
            result[firstID, default: .zero] += remainder
        }

        return result
    }

    /// Weighted share split. Each participant's weight defaults to 1 if absent
    /// from the share map.
    private static func splitByShares(
        amount: Decimal,
        among participantIDs: [UUID],
        shares: [UUID: Int]
    ) -> [UUID: Decimal] {
        guard !participantIDs.isEmpty else { return [:] }

        let weights: [(UUID, Decimal)] = participantIDs.map { id in
            let w = shares[id] ?? 1
            return (id, Decimal(w))
        }
        let totalWeight = weights.reduce(Decimal.zero) { $0 + $1.1 }
        guard totalWeight > .zero else { return [:] }

        var result: [UUID: Decimal] = [:]
        var allocated = Decimal.zero

        for (index, (id, weight)) in weights.enumerated() {
            if index == weights.count - 1 {
                // Last person gets the remainder to avoid rounding drift.
                result[id] = amount - allocated
            } else {
                var portion = (weight / totalWeight) * amount
                var rounded = Decimal()
                NSDecimalRound(&rounded, &portion, 2, .bankers)
                result[id] = rounded
                allocated += rounded
            }
        }

        return result
    }

    /// Exact-amount split — the caller has already specified each person's share.
    private static func splitByExactAmounts(
        among participantIDs: [UUID],
        amounts: [UUID: Decimal]
    ) -> [UUID: Decimal] {
        var result: [UUID: Decimal] = [:]
        for id in participantIDs {
            result[id] = amounts[id] ?? .zero
        }
        return result
    }

    // MARK: - Transaction Minimization

    /// Greedy algorithm that minimizes the number of settlements.
    ///
    /// 1. Separate non-zero balances into **debtors** (negative balance)
    ///    and **creditors** (positive balance).
    /// 2. Sort both lists by absolute value (descending).
    /// 3. Repeatedly match the largest debtor with the largest creditor,
    ///    settling the minimum of the two absolute amounts.
    ///
    /// This greedy approach is optimal when the goal is simply to minimize
    /// the total number of transactions (not the total amount transferred,
    /// which is fixed regardless of strategy).
    private static func minimizeTransactions(
        balances: [UUID: Decimal],
        participants: [SettlementParticipant]
    ) -> [Settlement] {
        let lookup = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, $0) })

        // Filter out zero-balance participants and split into debtors/creditors.
        // Debtors: store positive magnitude for easier math.
        var debtors: [(participant: SettlementParticipant, amount: Decimal)] = []
        var creditors: [(participant: SettlementParticipant, amount: Decimal)] = []

        let epsilon = Decimal(string: "0.005")! // half-cent threshold

        for (id, balance) in balances {
            guard let participant = lookup[id] else { continue }
            if balance < -epsilon {
                debtors.append((participant, -balance)) // store as positive
            } else if balance > epsilon {
                creditors.append((participant, balance))
            }
        }

        // Sort descending by amount for greedy matching.
        debtors.sort { $0.amount > $1.amount }
        creditors.sort { $0.amount > $1.amount }

        var settlements: [Settlement] = []
        var di = 0, ci = 0

        while di < debtors.count && ci < creditors.count {
            let debtAmount = debtors[di].amount
            let creditAmount = creditors[ci].amount
            let settledAmount = min(debtAmount, creditAmount)

            // Round settlement to 2 decimal places.
            var rounded = settledAmount
            var result = Decimal()
            NSDecimalRound(&result, &rounded, 2, .bankers)

            if result > .zero {
                settlements.append(Settlement(
                    from: debtors[di].participant,
                    to: creditors[ci].participant,
                    amount: result
                ))
            }

            debtors[di].amount -= settledAmount
            creditors[ci].amount -= settledAmount

            if debtors[di].amount < epsilon { di += 1 }
            if creditors[ci].amount < epsilon { ci += 1 }
        }

        return settlements
    }
}
