import Foundation

struct ActionConfig: Codable, Identifiable {
    var id: String
    var name: String
    var icon: String
    var isEnabled: Bool
    var config: [String: String]

    // Built-in action definitions
    static let safari = ActionConfig(id: "safari", name: "Safari", icon: "safari", isEnabled: true, config: [:])
    static let shelfRead = ActionConfig(id: "shelfRead", name: "ShelfRead", icon: "book.closed", isEnabled: false, config: ["ingestURL": ""])
    static let obsidian = ActionConfig(id: "obsidian", name: "Obsidian", icon: "square.and.arrow.down", isEnabled: true, config: ["vault": "", "folder": "Inbox", "dailyNote": "false", "useDirectAccess": "false", "saveAsTask": "false"])
    static let search = ActionConfig(id: "search", name: "Search", icon: "magnifyingglass", isEnabled: true, config: [:])
    static let share = ActionConfig(id: "share", name: "Share", icon: "square.and.arrow.up", isEnabled: true, config: [:])
    static let copy = ActionConfig(id: "copy", name: "Copy", icon: "doc.on.doc", isEnabled: true, config: [:])
}

struct Settings: Codable {
    var actions: [ActionConfig]

    static let defaultSettings = Settings(actions: [
        .safari, .shelfRead, .obsidian, .search, .share, .copy
    ])

    // Convenience accessors
    var shelfReadIngestURL: String {
        get { action("shelfRead")?.config["ingestURL"] ?? "" }
    }
    var obsidianVault: String {
        get { action("obsidian")?.config["vault"] ?? "" }
    }
    var obsidianFolder: String {
        get { action("obsidian")?.config["folder"] ?? "Inbox" }
    }
    var obsidianDailyNote: Bool {
        get { action("obsidian")?.config["dailyNote"] == "true" }
    }
    var obsidianUseDirectAccess: Bool {
        get { action("obsidian")?.config["useDirectAccess"] == "true" }
    }
    var obsidianSaveAsTask: Bool {
        get { action("obsidian")?.config["saveAsTask"] == "true" }
    }

    func action(_ id: String) -> ActionConfig? {
        actions.first { $0.id == id }
    }

    func isEnabled(_ id: String) -> Bool {
        action(id)?.isEnabled ?? false
    }

    // MARK: - Persistence

    private static let appGroupID = "group.com.rawplusdry.snaproute"

    private static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func load() -> Settings {
        let defaults = sharedDefaults
        if let data = defaults.data(forKey: "snaproute_actions"),
           let settings = try? JSONDecoder().decode(Settings.self, from: data) {
            return settings
        }
        // Also check standard defaults for migration
        let standardDefaults = UserDefaults.standard
        if let data = standardDefaults.data(forKey: "snaproute_actions"),
           let settings = try? JSONDecoder().decode(Settings.self, from: data) {
            // Migrate to shared defaults
            settings.save()
            return settings
        }
        // Migration: check for old flat keys
        let oldURL = standardDefaults.string(forKey: "shelfReadIngestURL") ?? ""
        let oldVault = standardDefaults.string(forKey: "obsidianVault") ?? ""
        let oldFolder = standardDefaults.string(forKey: "obsidianFolder") ?? "Inbox"

        var settings = defaultSettings
        if !oldURL.isEmpty {
            settings.updateConfig("shelfRead", key: "ingestURL", value: oldURL)
            settings.setEnabled("shelfRead", enabled: true)
        }
        if !oldVault.isEmpty {
            settings.updateConfig("obsidian", key: "vault", value: oldVault)
        }
        if !oldFolder.isEmpty {
            settings.updateConfig("obsidian", key: "folder", value: oldFolder)
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            Self.sharedDefaults.set(data, forKey: "snaproute_actions")
        }
    }

    // MARK: - Mutators

    mutating func updateConfig(_ actionId: String, key: String, value: String) {
        guard let idx = actions.firstIndex(where: { $0.id == actionId }) else { return }
        actions[idx].config[key] = value
    }

    mutating func setEnabled(_ actionId: String, enabled: Bool) {
        guard let idx = actions.firstIndex(where: { $0.id == actionId }) else { return }
        actions[idx].isEnabled = enabled
    }
}
