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
    static let obsidian = ActionConfig(id: "obsidian", name: "Obsidian", icon: "square.and.arrow.down", isEnabled: true, config: ["vault": "", "folder": "Inbox", "dailyNote": "true", "useDirectAccess": "false"])
    static let obsidianTask = ActionConfig(id: "obsidianTask", name: "Task", icon: "checkmark.square", isEnabled: true, config: [:])
    static let obsidianHistory = ActionConfig(id: "obsidianHistory", name: "History", icon: "clock.arrow.trianglehead.counterclockwise.rotate.90", isEnabled: false, config: [:])
    static let kurato = ActionConfig(id: "kurato", name: "Kurato", icon: "tray.and.arrow.down", isEnabled: false, config: ["ingestURL": "", "apiKey": ""])
    static let search = ActionConfig(id: "search", name: "Search", icon: "magnifyingglass", isEnabled: true, config: [:])
    static let share = ActionConfig(id: "share", name: "Share", icon: "square.and.arrow.up", isEnabled: true, config: [:])
    static let copy = ActionConfig(id: "copy", name: "Copy", icon: "doc.on.doc", isEnabled: true, config: [:])
}

struct Settings: Codable {
    var actions: [ActionConfig]

    static let defaultSettings = Settings(actions: [
        .safari, .shelfRead, .obsidian, .obsidianTask, .obsidianHistory, .kurato, .search, .share, .copy
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
    var kuratoIngestURL: String {
        get { action("kurato")?.config["ingestURL"] ?? "" }
    }
    var kuratoApiKey: String {
        get { action("kurato")?.config["apiKey"] ?? "" }
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
           var settings = try? JSONDecoder().decode(Settings.self, from: data) {
            // Migration: add new actions if missing
            let newActions: [ActionConfig] = [.obsidianTask, .obsidianHistory, .kurato]
            for newAction in newActions {
                if settings.action(newAction.id) == nil {
                    // Insert after obsidian for obsidian-related, or before search for kurato
                    if let obsIdx = settings.actions.firstIndex(where: { $0.id == "obsidian" }),
                       newAction.id.hasPrefix("obsidian") {
                        settings.actions.insert(newAction, at: obsIdx + 1 + (newAction.id == "obsidianHistory" ? 1 : 0))
                    } else if let searchIdx = settings.actions.firstIndex(where: { $0.id == "search" }) {
                        settings.actions.insert(newAction, at: searchIdx)
                    } else {
                        settings.actions.append(newAction)
                    }
                }
            }
            // Deduplicate actions (guard against buggy earlier migrations)
            var seen = Set<String>()
            settings.actions = settings.actions.filter { seen.insert($0.id).inserted }

            // Migration: obsidian config cleanup
            if let obsIdx = settings.actions.firstIndex(where: { $0.id == "obsidian" }) {
                settings.actions[obsIdx].config.removeValue(forKey: "saveAsTask")
                // Name/icon don't matter — SettingsView hardcodes the disclosure label
                settings.actions[obsIdx].name = "Obsidian"
                settings.actions[obsIdx].icon = "square.and.arrow.down"
                if settings.actions[obsIdx].config["dailyNote"] == nil {
                    settings.actions[obsIdx].config["dailyNote"] = "true"
                }
            }
            // Persist migration so it doesn't re-run every launch
            settings.save()
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
