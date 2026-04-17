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

    var actionLabel: String {
        switch action {
        case "safari": return "Opened in Safari"
        case "shelfRead": return "Sent to ShelfRead"
        case "obsidian": return "Saved to Obsidian"
        case "search": return "Searched"
        case "copy": return "Copied"
        case "visit": return "Visited"
        default: return action
        }
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
    private static let maxEntries = 200
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
