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

    // MARK: - Computed

    private var participants: [Participant] {
        trip.participants.filter { !$0.isTombstoned }
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
            // Exact amounts must sum to the total (within 1 cent tolerance)
            return abs(exactAmountsRemaining) < Decimal(string: "0.01")!
        }
        return true
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                payerSection
                splitMethodSection
                splitDistributionSection
                notesSection
            }
            .navigationTitle("New Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveExpense() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.large])
        .onAppear { initializeDefaults() }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        Section {
            HStack {
                Image(systemName: "pencil.line")
                    .foregroundStyle(.secondary)
                TextField("What was this for?", text: $title)
            }

            HStack {
                Text(currencySymbol)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.secondary)
                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(.system(.title2, design: .rounded, weight: .semibold))
            }

            DatePicker("Date", selection: $date, displayedComponents: .date)
        } header: {
            Label("Details", systemImage: "doc.text")
        }
    }

    // MARK: - Payer Section

    private var payerSection: some View {
        Section {
            if participants.count <= 4 {
                // Segmented-style for small groups
                HStack(spacing: 8) {
                    ForEach(participants) { participant in
                        payerChip(for: participant)
                    }
                }
                .listRowBackground(Color.clear)
            } else {
                Picker("Paid by", selection: $selectedPayerID) {
                    Text("Select...").tag(nil as UUID?)
                    ForEach(participants) { participant in
                        Text(participant.handle).tag(participant.id as UUID?)
                    }
                }
            }
        } header: {
            Label("Paid By", systemImage: "person.fill")
        }
    }

    private func payerChip(for participant: Participant) -> some View {
        let isSelected = selectedPayerID == participant.id
        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                selectedPayerID = participant.id
            }
        } label: {
            VStack(spacing: 6) {
                ParticipantAvatarView(participant: participant)
                Text(participant.handle)
                    .font(.caption2)
                    .fontWeight(isSelected ? .bold : .regular)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.tint.opacity(0.15))
                        .glassEffect()
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Paid by \(participant.handle)")
    }

    // MARK: - Split Method Section

    private var splitMethodSection: some View {
        Section {
            Picker("Method", selection: $splitMethod.animation(.smooth)) {
                ForEach(ExpenseSplitMethod.allCases, id: \.self) { method in
                    Text(method.displayName).tag(method)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Label("Split Method", systemImage: "divide")
        }
    }

    // MARK: - Split Distribution Section

    @ViewBuilder
    private var splitDistributionSection: some View {
        Section {
            switch splitMethod {
            case .equally:
                equalSplitView
            case .byShares:
                sharesSplitView
            case .byExactAmounts:
                exactAmountsSplitView
            }
        } header: {
            Label("Split Between", systemImage: "person.2.fill")
        } footer: {
            if splitMethod == .equally, let perPerson = perPersonAmount {
                Text("\(perPerson.formatted(.currency(code: currencyCode))) per person")
                    .contentTransition(.numericText())
            }
        }
    }

    // Equal split: toggle participants in/out
    private var equalSplitView: some View {
        ForEach(participants) { participant in
            HStack {
                Toggle(isOn: participantBinding(for: participant.id)) {
                    HStack(spacing: 10) {
                        ParticipantAvatarView(participant: participant)
                        Text(participant.handle)
                            .font(.body)
                    }
                }
                .tint(.accentColor)

                Spacer()

                if includedParticipantIDs.contains(participant.id), let perPerson = perPersonAmount {
                    Text(perPerson.formatted(.currency(code: currencyCode)))
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }
        }
    }

    // Shares split: stepper per participant
    private var sharesSplitView: some View {
        ForEach(participants) { participant in
            HStack {
                Toggle(isOn: participantBinding(for: participant.id)) {
                    HStack(spacing: 10) {
                        ParticipantAvatarView(participant: participant)
                        Text(participant.handle)
                    }
                }
                .tint(.accentColor)

                Spacer()

                if includedParticipantIDs.contains(participant.id) {
                    Stepper(
                        value: shareBinding(for: participant.id),
                        in: 1...99
                    ) {
                        Text("\(shareWeights[participant.id, default: 1]) share\(shareWeights[participant.id, default: 1] == 1 ? "" : "s")")
                            .font(.system(.callout, design: .rounded))
                            .monospacedDigit()
                    }
                    .frame(maxWidth: 180)
                }
            }
        }
    }

    // Exact amounts split: text field per participant
    private var exactAmountsSplitView: some View {
        Group {
            ForEach(participants) { participant in
                HStack {
                    Toggle(isOn: participantBinding(for: participant.id)) {
                        HStack(spacing: 10) {
                            ParticipantAvatarView(participant: participant)
                            Text(participant.handle)
                        }
                    }
                    .tint(.accentColor)

                    Spacer()

                    if includedParticipantIDs.contains(participant.id) {
                        HStack(spacing: 4) {
                            Text(currencySymbol)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            TextField("0.00", text: exactAmountBinding(for: participant.id))
                                .keyboardType(.decimalPad)
                                .font(.system(.callout, design: .rounded))
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }

            // Remaining indicator
            if amount != nil {
                HStack {
                    Text("Remaining")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(exactAmountsRemaining.formatted(.currency(code: currencyCode)))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(
                            abs(exactAmountsRemaining) < Decimal(string: "0.01")!
                                ? .green : .red
                        )
                        .contentTransition(.numericText())
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            abs(exactAmountsRemaining) < Decimal(string: "0.01")!
                                ? Color.green.opacity(0.08)
                                : Color.red.opacity(0.08)
                        )
                )
            }
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        Section {
            TextField("Add a note…", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        } header: {
            Label("Notes", systemImage: "note.text")
        }
    }

    // MARK: - Bindings

    private func participantBinding(for id: UUID) -> Binding<Bool> {
        Binding {
            includedParticipantIDs.contains(id)
        } set: { included in
            withAnimation(.snappy(duration: 0.2)) {
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
        // Include all participants by default
        includedParticipantIDs = Set(participants.map(\.id))
        // Default payer to first participant
        selectedPayerID = participants.first?.id
        // Initialize share weights to 1
        for p in participants {
            shareWeights[p.id] = 1
        }
    }

    // MARK: - Save

    private func saveExpense() {
        guard let amount, let payerID = selectedPayerID else { return }
        guard let payer = participants.first(where: { $0.id == payerID }) else { return }

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

    // MARK: - Helpers

    private var currencySymbol: String {
        let locale = Locale(identifier: Locale.identifier(fromComponents: [
            NSLocale.Key.currencyCode.rawValue: currencyCode
        ]))
        return locale.currencySymbol ?? currencyCode
    }
}

// MARK: - ExpenseSplitMethod Display

extension ExpenseSplitMethod {
    var displayName: String {
        switch self {
        case .equally: "Equal"
        case .byShares: "Shares"
        case .byExactAmounts: "Exact"
        }
    }
}

// MARK: - Preview

#Preview {
    AddExpenseView(trip: Trip(name: "Lisbon 2026"))
        .modelContainer(for: Trip.self, inMemory: true)
}
