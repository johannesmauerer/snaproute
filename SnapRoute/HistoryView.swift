import SwiftUI

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelectURL: (URL) -> Void
    @State private var entries: [HistoryEntry] = []

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary.opacity(0.5))
                        Text("No history yet")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(entries) { entry in
                            HistoryRow(entry: entry)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if let urlStr = entry.url, let url = URL(string: urlStr) {
                                        onSelectURL(url)
                                        dismiss()
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
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
