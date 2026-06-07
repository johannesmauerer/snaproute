import SwiftUI

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (String) -> Void
    @State private var entries: [HistoryEntry] = []
    @State private var searchText: String = ""
    @State private var selectedActions: Set<String> = []

    private var filteredEntries: [HistoryEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return entries.filter { entry in
            if !selectedActions.isEmpty, !selectedActions.contains(entry.action) {
                return false
            }
            if query.isEmpty { return true }
            if entry.displayTitle.lowercased().contains(query) { return true }
            if entry.displaySubtitle.lowercased().contains(query) { return true }
            if let url = entry.url, url.lowercased().contains(query) { return true }
            if let text = entry.text, text.lowercased().contains(query) { return true }
            return false
        }
    }

    /// Action types actually present in the loaded history, in canonical order.
    private var availableActions: [String] {
        let present = Set(entries.map(\.action))
        let canonical = HistoryEntry.allActionTypes.filter { present.contains($0) }
        let extras = present.subtracting(canonical).sorted()
        return canonical + extras
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !entries.isEmpty {
                    filterChips
                }

                Group {
                    if entries.isEmpty {
                        emptyState(
                            icon: "clock.arrow.circlepath",
                            text: "No history yet"
                        )
                    } else if filteredEntries.isEmpty {
                        emptyState(
                            icon: "magnifyingglass",
                            text: "No matches"
                        )
                    } else {
                        List {
                            ForEach(filteredEntries) { entry in
                                HistoryRow(entry: entry)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if let recall = entry.recallText {
                                            onSelect(recall)
                                            dismiss()
                                        }
                                    }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search history")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                }
                if !entries.isEmpty {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Clear") {
                            HistoryStore.clear()
                            entries = []
                            selectedActions = []
                            searchText = ""
                        }
                        .font(.system(size: 15))
                        .foregroundStyle(.red)
                    }
                }
            }
            .onAppear {
                entries = HistoryStore.load()
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    label: "All",
                    isSelected: selectedActions.isEmpty,
                    action: { selectedActions = [] }
                )
                ForEach(availableActions, id: \.self) { action in
                    FilterChip(
                        label: HistoryEntry.shortLabel(for: action),
                        isSelected: selectedActions.contains(action),
                        action: {
                            if selectedActions.contains(action) {
                                selectedActions.remove(action)
                            } else {
                                selectedActions.insert(action)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(.secondary.opacity(0.5))
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isSelected ? Color.blue : Color.secondary.opacity(0.12))
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.displayTitle)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                Spacer()
                Text(entry.timeAgo)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            if !entry.displaySubtitle.isEmpty && entry.displaySubtitle != entry.displayTitle {
                Text(entry.displaySubtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(entry.actionLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.blue)
        }
        .padding(.vertical, 2)
    }
}
