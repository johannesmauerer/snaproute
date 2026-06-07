import Foundation

struct HistoryEntry: Codable, Identifiable {
    let id: UUID
    let url: String?
    let title: String?
    let text: String?
    let action: String // "safari", "shelfRead", "obsidian", "search", "note", "copy"
    let timestamp: Date

    var displayTitle: String {
        title ?? url ?? text?.prefix(60).description ?? "Untitled"
    }

    var displaySubtitle: String {
        if let url = url {
            return URL(string: url)?.host ?? url
        }
        return text?.prefix(100).description ?? ""
    }

    /// What to drop back into the input field when this row is tapped.
    /// URL wins (re-renders preview); otherwise the original text; otherwise the title.
    var recallText: String? {
        if let url, !url.isEmpty { return url }
        if let text, !text.isEmpty { return text }
        if let title, !title.isEmpty { return title }
        return nil
    }

    var actionLabel: String {
        switch action {
        case "safari": return "Opened in Safari"
        case "shelfRead": return "Sent to ShelfRead"
        case "obsidian": return "Saved note"
        case "obsidianTask": return "Saved task"
        case "kurato": return "Sent to Kurato"
        case "search": return "Searched"
        case "copy": return "Copied"
        case "visit": return "Visited"
        default: return action
        }
    }

    /// Short label for filter chips and badges.
    var actionShortLabel: String {
        switch action {
        case "safari": return "Safari"
        case "shelfRead": return "ShelfRead"
        case "obsidian": return "Note"
        case "obsidianTask": return "Task"
        case "kurato": return "Kurato"
        case "search": return "Search"
        case "copy": return "Copy"
        case "visit": return "Visit"
        default: return action.capitalized
        }
    }

    /// Canonical action IDs in display order — used by the filter UI.
    static let allActionTypes: [String] = [
        "safari", "shelfRead", "obsidian", "obsidianTask", "kurato",
        "search", "copy", "visit",
    ]

    /// Short label for an arbitrary action id (used by filter chips before
    /// any entries with that action exist).
    static func shortLabel(for action: String) -> String {
        let stub = HistoryEntry(id: UUID(), url: nil, title: nil, text: nil,
                                action: action, timestamp: Date())
        return stub.actionShortLabel
    }

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        return f
    }()

    var timeAgo: String {
        let interval = Date().timeIntervalSince(timestamp)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 604800 { return "\(Int(interval / 86400))d ago" }
        return Self.shortDateFormatter.string(from: timestamp)
    }
}

class HistoryStore {
    private static let key = "snaproute_history"
    private static let maxEntries = 2000
    private static var cache: [HistoryEntry]?

    static func load() -> [HistoryEntry] {
        if let cache { return cache }
        guard let data = UserDefaults.standard.data(forKey: key),
              let entries = try? JSONDecoder().decode([HistoryEntry].self, from: data) else {
            return []
        }
        cache = entries
        return entries
    }

    static func add(_ entry: HistoryEntry) {
        var entries = load()
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        cache = entries
        // Write to disk off the main thread
        DispatchQueue.global(qos: .utility).async {
            if let data = try? JSONEncoder().encode(entries) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }

    static func clear() {
        cache = nil
        UserDefaults.standard.removeObject(forKey: key)
    }
}
