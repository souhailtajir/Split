//
//  AddExpenseView.swift
//  Split
//
//  Created by Souhail on 8/3/26.
//

import SwiftUI
import SwiftData

struct AddExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let trip: Trip

    // MARK: - Form State

    @State private var title = ""
    @State private var amountText = ""
    @State private var date = Date.now
    @State private var selectedPayerID: UUID?
    @State private var splitMethod: ExpenseSplitMethod = .equally
    @State private var includedParticipantIDs: Set<UUID> = []
    @State private var shareWeights: [UUID: Int] = [:]
    @State private var exactAmountTexts: [UUID: String] = [:]
    @State private var notes = ""
    @State private var currencyCode: String = Locale.current.currency?.identifier ?? "USD"
    
    @FocusState private var focusedField: Field?
    
    private enum Field: Hashable {
        case amount
        case exactAmount(UUID)
    }

    // MARK: - Computed

    private var participants: [Participant] {
        trip.participants
            .filter { !$0.isTombstoned }
            .sorted { $0.isOwner && !$1.isOwner }
    }

    private var amount: Decimal? {
        Decimal(string: amountText)
    }

    private var includedParticipants: [Participant] {
        participants.filter { includedParticipantIDs.contains($0.id) }
    }

    private var perPersonAmount: Decimal? {
        guard let amount, !includedParticipants.isEmpty else { return nil }
        return amount / Decimal(includedParticipants.count)
    }

    private var exactAmountsTotal: Decimal {
        exactAmountTexts.values.compactMap { Decimal(string: $0) }.reduce(.zero, +)
    }

    private var exactAmountsRemaining: Decimal {
        (amount ?? .zero) - exactAmountsTotal
    }

    private var isValid: Bool {
        guard let amount, amount > .zero else { return false }
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard selectedPayerID != nil else { return false }
        guard !includedParticipantIDs.isEmpty else { return false }

        if splitMethod == .byExactAmounts {
            return abs(exactAmountsRemaining) < Decimal(string: "0.01")!
        }
        return true
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            TopGradientWash(tint: .indigo, secondaryTint: .purple)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Hero Amount Input Card
                    heroAmountCard

                    // Title & Date Card
                    detailsCard

                    // Payer Chip Selector Card
                    payerCard

                    // Split Method Card
                    splitMethodCard

                    // Split Distribution Details Card
                    splitDistributionCard

                    // Notes Card
                    notesCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("New Expense")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveExpense() }
                    .fontWeight(.bold)
                    .disabled(!isValid)
            }
        }
        .onAppear { initializeDefaults() }
        .onAppear { focusedField = .amount }
    }

    // MARK: - Hero Amount Card (Liquid Glass)

    private var heroAmountCard: some View {
        VStack(spacing: 8) {
            Text("ENTER AMOUNT")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(1.0)

            HStack(spacing: 4) {
                Text(currencySymbol)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.6))

                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .focused($focusedField, equals: .amount)
                    .submitLabel(.done)
                    .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focusedField = nil } } }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(24)
        .appleCardStyle(cornerRadius: 24)
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Details", systemImage: "pencil.line")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)

            VStack(spacing: 12) {
                TextField("What was this expense for?", text: $title)
                    .font(.system(.body, design: .rounded))
                    .padding(12)
                    .clearGlassCard(cornerRadius: 12)

                DatePicker("Expense Date", selection: $date, displayedComponents: .date)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(8)
            }
        }
        .padding(18)
        .appleCardStyle(cornerRadius: 22)
    }

    // MARK: - Payer Card

    private var payerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Who Paid?", systemImage: "creditcard.fill")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(participants) { participant in
                        let isSelected = selectedPayerID == participant.id
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                selectedPayerID = participant.id
                            }
                        } label: {
                            VStack(spacing: 6) {
                                ParticipantAvatarView(participant: participant)
                                Text(participant.handle)
                                    .font(.caption.weight(isSelected ? .bold : .regular))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .glassEffect(
                                isSelected ? .regular : .clear,
                                in: .rect(cornerRadius: 16)
                            )
                            .overlay {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(.indigo, lineWidth: 1.5)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(18)
        .appleCardStyle(cornerRadius: 22)
    }

    // MARK: - Split Method Card

    private var splitMethodCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Split Method", systemImage: "divide")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)

            Picker("Split Method", selection: $splitMethod) {
                Text("Equal").tag(ExpenseSplitMethod.equally)
                Text("Shares").tag(ExpenseSplitMethod.byShares)
                Text("Exact").tag(ExpenseSplitMethod.byExactAmounts)
            }
            .pickerStyle(.segmented)
            .animation(.spring(.bouncy), value: splitMethod)
        }
        .padding(18)
        .appleCardStyle(cornerRadius: 22)
    }

    // MARK: - Split Distribution Card

    private var splitDistributionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Split Between", systemImage: "person.2.fill")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()

                if splitMethod == .equally, let perPerson = perPersonAmount {
                    Text("\(perPerson.formatted(.currency(code: currencyCode))) / person")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.indigo)
                }
            }

            VStack(spacing: 10) {
                ForEach(participants) { participant in
                    HStack {
                        Toggle(isOn: participantBinding(for: participant.id)) {
                            HStack(spacing: 10) {
                                ParticipantAvatarView(participant: participant)
                                Text(participant.handle)
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .tint(.indigo)

                        Spacer()

                        if includedParticipantIDs.contains(participant.id) {
                            if splitMethod == .byShares {
                                Stepper(
                                    value: shareBinding(for: participant.id),
                                    in: 1...99
                                ) {
                                    Text("\(shareWeights[participant.id, default: 1]) sh")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: 130)
                            } else if splitMethod == .byExactAmounts {
                                HStack(spacing: 2) {
                                    Text(currencySymbol)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    TextField("0.00", text: exactAmountBinding(for: participant.id))
                                        .keyboardType(.decimalPad)
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(.primary)
                                        .frame(width: 60)
                                        .multilineTextAlignment(.trailing)
                                        .focused($focusedField, equals: .exactAmount(participant.id))
                                        .submitLabel(.done)
                                }
                            }
                        }
                    }
                    .padding(8)
                    .clearGlassCard(cornerRadius: 12)
                }
            }
        }
        .padding(18)
        .appleCardStyle(cornerRadius: 22)
    }

    // MARK: - Notes Card

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Notes & Remarks", systemImage: "note.text")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)

            TextField("Add optional notes...", text: $notes, axis: .vertical)
                .font(.subheadline)
                .lineLimit(2...4)
                .padding(12)
                .clearGlassCard(cornerRadius: 14)
        }
        .padding(18)
        .appleCardStyle(cornerRadius: 22)
    }

    // MARK: - Bindings

    private func participantBinding(for id: UUID) -> Binding<Bool> {
        Binding {
            includedParticipantIDs.contains(id)
        } set: { included in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                if included {
                    includedParticipantIDs.insert(id)
                } else {
                    includedParticipantIDs.remove(id)
                }
            }
        }
    }

    private func shareBinding(for id: UUID) -> Binding<Int> {
        Binding {
            shareWeights[id, default: 1]
        } set: { newValue in
            shareWeights[id] = newValue
        }
    }

    private func exactAmountBinding(for id: UUID) -> Binding<String> {
        Binding {
            exactAmountTexts[id, default: ""]
        } set: { newValue in
            exactAmountTexts[id] = newValue
        }
    }

    // MARK: - Initialization

    private func initializeDefaults() {
        includedParticipantIDs = Set(participants.map(\.id))
        // Pre-select the group owner (creator) as the default payer
        selectedPayerID = participants.first(where: \.isOwner)?.id ?? participants.first?.id
        for p in participants {
            shareWeights[p.id] = 1
        }
    }

    // MARK: - Save

    private func saveExpense() {
        guard let amount, let payerID = selectedPayerID else { return }
        guard let payer = participants.first(where: { $0.id == payerID }) else { return }
        
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        #endif

        let sharedWith = participants.filter { includedParticipantIDs.contains($0.id) }

        let expense = Expense(
            title: title.trimmingCharacters(in: .whitespaces),
            amount: amount,
            currencyCode: currencyCode,
            date: date,
            notes: notes.isEmpty ? nil : notes,
            splitMethod: splitMethod,
            trip: trip,
            paidBy: payer,
            sharedWith: sharedWith
        )

        modelContext.insert(expense)
        dismiss()
    }

    private var currencySymbol: String {
        let locale = Locale(identifier: Locale.identifier(fromComponents: [
            NSLocale.Key.currencyCode.rawValue: currencyCode
        ]))
        return locale.currencySymbol ?? currencyCode
    }
}

// MARK: - Preview

#Preview("Add Expense") {
    NavigationStack {
        AddExpenseView(trip: PreviewSampleData.sampleGroup)
    }
    .modelContainer(PreviewSampleData.container)
}
