import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var shelfReadURL: String
    @State private var obsidianVault: String
    @State private var obsidianFolder: String

    init() {
        let settings = Settings.load()
        _shelfReadURL = State(initialValue: settings.shelfReadIngestURL)
        _obsidianVault = State(initialValue: settings.obsidianVault)
        _obsidianFolder = State(initialValue: settings.obsidianFolder)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("ShelfRead") {
                    TextField("Ingest URL", text: $shelfReadURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    Text("e.g. https://your-deployment.convex.site/ingest")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Obsidian") {
                    TextField("Vault name", text: $obsidianVault)
                        .autocapitalization(.none)
                    TextField("Folder", text: $obsidianFolder)
                        .autocapitalization(.none)
                    Text("Notes will be saved to this folder in your vault")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Default Browser") {
                    Text("To use SnapRoute as your default browser, go to Settings > Apps > Default Browser App and select SnapRoute.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        save()
                        dismiss()
                    }
                }
            }
        }
    }

    private func save() {
        var settings = Settings.load()
        settings.shelfReadIngestURL = shelfReadURL.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.obsidianVault = obsidianVault.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.obsidianFolder = obsidianFolder.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.save()
    }
}
