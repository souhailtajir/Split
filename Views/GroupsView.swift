//
//  GroupsView.swift
//  Split
//
//  Created by Souhail on 8/4/26.
//

import SwiftData
import SwiftUI

struct GroupsView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(UserProfile.self) private var userProfile
  @Query(
    filter: #Predicate<Trip> { !$0.isTombstoned },
    sort: \Trip.createdAt,
    order: .reverse
  )
  private var groups: [Trip]

  @State private var isAddingGroup = false
  @State private var newGroupName = ""
  @FocusState private var isGroupNameFocused: Bool

  var body: some View {
    NavigationStack {
      ZStack {
        TopGradientWash(tint: .indigo, secondaryTint: .purple)

        List {
          // Hero Summary
          heroSummaryCard
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 0, trailing: 16))

          // Groups Section
          Section {
            // Inline Add Group Card
            if isAddingGroup {
              inlineAddGroupCard
                .transition(
                  .asymmetric(
                    insertion: .scale(scale: 0.92).combined(with: .opacity).combined(with: .offset(y: -8)),
                    removal: .scale(scale: 0.92).combined(with: .opacity)
                  )
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }

            // Group Deck
            if groups.isEmpty && !isAddingGroup {
              emptyStateCard
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
            } else {
              ForEach(groups) { group in
                ZStack {
                  NavigationLink {
                    GroupDetailView(trip: group)
                  } label: {
                    EmptyView()
                  }
                  .opacity(0)

                  GroupCardRow(group: group)
                }
                .contextMenu {
                  Button(role: .destructive) {
                    softDelete(group: group)
                  } label: {
                    Label("Delete Group", systemImage: "trash")
                  }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
              }
            }
          } header: {
            HStack {
              Text("Your Groups")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)

              Spacer()

              GlassActionButton(title: "New", systemImage: "plus", accentColor: .indigo) {
                withAnimation(.spring(.bouncy)) {
                  isAddingGroup = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                  isGroupNameFocused = true
                }
              }
            }
            .padding(.horizontal, 4)
          }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
      }
      .navigationTitle("Groups")
    }
  }

  // MARK: - Hero Summary Card

  private var heroSummaryCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text("OVERVIEW")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
            .tracking(1.0)

          Text(allGroupsTotalSpend.formatted(.currency(code: primaryCurrencyCode)))
            .font(.system(size: 34, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
            .contentTransition(.numericText())
        }

        Spacer()

        Image(systemName: "creditcard.fill")
          .font(.title2)
          .foregroundStyle(.indigo)
          .frame(width: 48, height: 48)
          .glassEffect(.clear, in: .circle)
      }

      HStack(spacing: 10) {
        StatPill(icon: "rectangle.3.group", value: "\(groups.count) Groups")
        StatPill(icon: "person.2.fill", value: "\(totalUniqueParticipants) Members")
      }
    }
    .padding(20)
    .appleCardStyle(cornerRadius: 24)
  }

  // MARK: - Inline Add Group Card

  private var inlineAddGroupCard: some View {
    VStack(spacing: 14) {
      Text("NEW GROUP")
        .font(.system(size: 11, weight: .bold, design: .rounded))
        .foregroundStyle(.secondary)
        .tracking(0.5)
        .frame(maxWidth: .infinity, alignment: .leading)

      HStack(spacing: 12) {
        TextField("Group name", text: $newGroupName)
          .font(.system(.title3, design: .rounded, weight: .semibold))
          .focused($isGroupNameFocused)
          .onSubmit { createGroup() }
          .submitLabel(.done)

        Button {
          createGroup()
        } label: {
          Image(systemName: "checkmark.circle.fill")
            .font(.title2)
            .foregroundStyle(
              newGroupName.trimmingCharacters(in: .whitespaces).isEmpty
                ? Color.gray.opacity(0.5) : Color.indigo)
        }
        .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)

        Button {
          withAnimation(.spring(.bouncy)) {
            isAddingGroup = false
            newGroupName = ""
          }
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.title2)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(18)
    .appleCardStyle(cornerRadius: 20)
  }

  // MARK: - Empty State Card

  private var emptyStateCard: some View {
    VStack(spacing: 16) {
      Image(systemName: "rectangle.3.group")
        .font(.system(size: 44))
        .foregroundStyle(.indigo.gradient)
        .padding(.top, 12)

      VStack(spacing: 6) {
        Text("No Groups Yet")
          .font(.headline)
          .foregroundStyle(.primary)
        Text(
          "Create a group to start splitting expenses — whether it's a trip, dinner, shared apartment, or any activity."
        )
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      }

      GlassActionButton(
        title: "Create New Group", systemImage: "plus.circle.fill", accentColor: .indigo
      ) {
        withAnimation(.spring(.bouncy)) {
          isAddingGroup = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          isGroupNameFocused = true
        }
      }
      .padding(.bottom, 8)
    }
    .padding(24)
    .appleCardStyle()
  }

  // MARK: - Computed Properties

  private var allGroupsTotalSpend: Decimal {
    groups.reduce(.zero) { sum, group in
      sum + group.expenses.filter { !$0.isTombstoned }.reduce(.zero) { $0 + $1.amount }
    }
  }

  private var totalUniqueParticipants: Int {
    Set(groups.flatMap { $0.participants.filter { !$0.isTombstoned }.map(\.id) }).count
  }

  private var primaryCurrencyCode: String {
    groups.flatMap(\.expenses).first(where: { !$0.isTombstoned })?.currencyCode
      ?? Locale.current.currency?.identifier ?? "USD"
  }

  // MARK: - Actions

  private func createGroup() {
    let name = newGroupName.trimmingCharacters(in: .whitespaces)
    guard !name.isEmpty else { return }

    withAnimation(.spring(.bouncy)) {
      let group = Trip(name: name, startDate: .now)
      modelContext.insert(group)

      // Auto-add the creator as the first member
      let owner = Participant(
        handle: userProfile.handle,
        fullName: userProfile.displayName,
        isOwner: true,
        trip: group
      )
      modelContext.insert(owner)

      isAddingGroup = false
    }
    newGroupName = ""
  }

  private func softDelete(group: Trip) {
    withAnimation(.spring(.bouncy)) {
      group.isTombstoned = true
      group.updatedAt = .now
    }
  }
}

// MARK: - Hero Stat Pill

private struct StatPill: View {
  let icon: String
  let value: String

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.caption.weight(.bold))
        .foregroundStyle(.primary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .clearGlassCapsule()
  }
}

// MARK: - Premium Group Card Row

struct GroupCardRow: View {
  let group: Trip

  @Environment(\.colorScheme) private var colorScheme

  private var activeExpenses: [Expense] {
    group.expenses.filter { !$0.isTombstoned }
  }

  private var activeParticipants: [Participant] {
    group.participants.filter { !$0.isTombstoned }
  }

  private var totalSpend: Decimal {
    activeExpenses.reduce(.zero) { $0 + $1.amount }
  }

  private var currencyCode: String {
    activeExpenses.first?.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
  }

  var body: some View {
    VStack(spacing: 0) {
      // Top: Icon + Name + Amount
      HStack(spacing: 14) {
        // Gradient Icon Badge
        ZStack {
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
              LinearGradient(
                colors: [cardAccentColor, cardAccentColor.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .frame(width: 48, height: 48)

          Image(systemName: groupIcon)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.white)
        }

        VStack(alignment: .leading, spacing: 3) {
          Text(group.name)
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(.primary)
            .lineLimit(1)

          if let start = group.startDate {
            Text(start.formatted(.dateTime.month(.wide).day().year()))
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 3) {
          Text(totalSpend.formatted(.currency(code: currencyCode)))
            .font(.system(.callout, design: .rounded, weight: .bold))
            .foregroundStyle(.primary)

          Image(systemName: "chevron.right")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.tertiary)
        }
      }

      // Divider
      Rectangle()
        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
        .frame(height: 1)
        .padding(.vertical, 12)

      // Bottom: Metadata chips
      HStack(spacing: 8) {
        MetadataChip(icon: "person.2.fill", value: "\(activeParticipants.count)", label: "members")
        MetadataChip(icon: "receipt", value: "\(activeExpenses.count)", label: "expenses")

        Spacer()

        // Per-person breakdown
        if !activeParticipants.isEmpty && totalSpend > .zero {
          let perPerson = totalSpend / Decimal(activeParticipants.count)
          Text("~\(perPerson.formatted(.currency(code: currencyCode)))/person")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(16)
    .interactiveGlassCard(cornerRadius: 20)
  }

  /// Context-aware icon based on group name keywords.
  private var groupIcon: String {
    let name = group.name.lowercased()
    if name.contains("trip") || name.contains("travel") || name.contains("vacation")
      || name.contains("flight")
    {
      return "airplane"
    } else if name.contains("dinner") || name.contains("lunch") || name.contains("brunch")
      || name.contains("meal") || name.contains("food")
    {
      return "fork.knife"
    } else if name.contains("apartment") || name.contains("house") || name.contains("room")
      || name.contains("rent")
    {
      return "house.fill"
    } else if name.contains("event") || name.contains("party") || name.contains("concert")
      || name.contains("festival")
    {
      return "party.popper.fill"
    } else if name.contains("office") || name.contains("work") || name.contains("team") {
      return "briefcase.fill"
    }
    return "rectangle.3.group"
  }

  private var cardAccentColor: Color {
    let colors: [Color] = [.indigo, .blue, .purple, .teal, .orange]
    return colors[abs(group.id.hashValue) % colors.count]
  }
}

// MARK: - Metadata Chip

private struct MetadataChip: View {
  let icon: String
  let value: String
  let label: String

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: icon)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.secondary)
      Text(value)
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .foregroundStyle(.primary)
      Text(label)
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(.tertiary)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 5)
    .clearGlassCapsule()
  }
}

// MARK: - Preview

#Preview("Groups — With Data") {
  GroupsView()
    .modelContainer(PreviewSampleData.container)
    .environment(UserProfile.shared)
}

#Preview("Groups — Empty") {
  GroupsView()
    .modelContainer(PreviewSampleData.emptyContainer)
    .environment(UserProfile.shared)
}

