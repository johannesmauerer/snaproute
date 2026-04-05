import Foundation

struct Settings: Codable {
    var shelfReadIngestURL: String
    var obsidianVault: String
    var obsidianFolder: String

    static let defaultSettings = Settings(
        shelfReadIngestURL: "",
        obsidianVault: "",
        obsidianFolder: "Inbox"
    )

    private static let key = "snaproute_settings"

    static func load() -> Settings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(Settings.self, from: data) else {
            return defaultSettings
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Settings.key)
        }
    }
}
