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
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // ShelfRead section
                    SettingsSection(title: "SHELFREAD") {
                        SettingsField(
                            label: "Ingest URL",
                            placeholder: "https://your-deployment.convex.site/ingest",
                            text: $shelfReadURL,
                            keyboardType: .URL
                        )
                    }

                    // Obsidian section
                    SettingsSection(title: "OBSIDIAN") {
                        SettingsField(
                            label: "Vault",
                            placeholder: "My Vault",
                            text: $obsidianVault
                        )
                        SettingsField(
                            label: "Folder",
                            placeholder: "Inbox",
                            text: $obsidianFolder
                        )
                    }

                    // Info section
                    SettingsSection(title: "DEFAULT BROWSER") {
                        Text("Settings \u{2192} Apps \u{2192} Default Browser App \u{2192} SnapRoute")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        save()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .medium))
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

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.3))
                .tracking(1.5)
            content
        }
    }
}

struct SettingsField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .font(.system(size: 15))
                .autocapitalization(.none)
                .keyboardType(keyboardType)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.primary.opacity(0.06), lineWidth: 1)
                )
        }
    }
}
