import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings: Settings
    @State private var showVaultPicker = false
    @State private var vaultFolders: [String] = []
    var onDismiss: (() -> Void)?

    init(onDismiss: (() -> Void)? = nil) {
        _settings = State(initialValue: Settings.load())
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            List {
                // Actions section
                Section {
                    let visibleIndices = settings.actions.indices.filter { idx in
                        let id = settings.actions[idx].id
                        return id != "obsidianTask" && id != "obsidianHistory"
                    }
                    ForEach(visibleIndices, id: \.self) { index in
                        let action = settings.actions[index]
                        switch action.id {
                        case "safari":
                            ActionToggleRow(action: $settings.actions[index])
                        case "shelfRead":
                            DisclosureGroup {
                                SettingsField(
                                    label: "Ingest URL",
                                    placeholder: "https://your-deployment.convex.site/ingest",
                                    text: configBinding(index: index, key: "ingestURL"),
                                    keyboardType: .URL
                                )
                                Link(destination: URL(string: "https://github.com/johannesmauerer/shelfread")!) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "link")
                                            .font(.system(size: 12))
                                        Text("ShelfRead on GitHub")
                                            .font(.system(size: 13))
                                    }
                                    .foregroundStyle(.blue)
                                }
                            } label: {
                                ActionToggleRow(action: $settings.actions[index])
                            }
                        case "obsidian":
                            DisclosureGroup {
                                // Note toggle
                                Toggle(isOn: $settings.actions[index].isEnabled) {
                                    Label("Note button", systemImage: "note.text")
                                }
                                .font(.system(size: 14))

                                // Task toggle
                                if let taskIdx = settings.actions.firstIndex(where: { $0.id == "obsidianTask" }) {
                                    Toggle(isOn: $settings.actions[taskIdx].isEnabled) {
                                        Label("Task button", systemImage: "checkmark.square")
                                    }
                                    .font(.system(size: 14))
                                }

                                // History toggle
                                if let histIdx = settings.actions.firstIndex(where: { $0.id == "obsidianHistory" }) {
                                    Toggle(isOn: $settings.actions[histIdx].isEnabled) {
                                        Label("Log history", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                                    }
                                    .font(.system(size: 14))
                                    if settings.actions[histIdx].isEnabled {
                                        Text("Appends every action to your daily note in the background")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Divider()

                                obsidianSettings(index: index)
                            } label: {
                                Label("Obsidian", systemImage: "square.and.arrow.down")
                            }
                        case "kurato":
                            DisclosureGroup {
                                SettingsField(
                                    label: "Cloud Function URL",
                                    placeholder: "https://us-central1-kurato-1.cloudfunctions.net/ingestExternalLink",
                                    text: configBinding(index: index, key: "ingestURL"),
                                    keyboardType: .URL
                                )
                                SettingsField(
                                    label: "API Key",
                                    placeholder: "Paste from Kurato settings",
                                    text: configBinding(index: index, key: "apiKey")
                                )
                            } label: {
                                ActionToggleRow(action: $settings.actions[index])
                            }
                        case "search", "share", "copy":
                            ActionToggleRow(action: $settings.actions[index])
                        default:
                            ActionToggleRow(action: $settings.actions[index])
                        }
                    }
                } header: {
                    Text("Actions")
                } footer: {
                    Text("Disabled actions won't appear in the action bar.")
                }

            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        settings.save()
                        onDismiss?()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .medium))
                }
            }
            .sheet(isPresented: $showVaultPicker) {
                VaultFolderPicker { url in
                    ObsidianVaultManager.shared.saveBookmark(for: url)
                    settings.updateConfig("obsidian", key: "useDirectAccess", value: "true")
                    settings.updateConfig("obsidian", key: "vault", value: url.lastPathComponent)
                    vaultFolders = ObsidianVaultManager.shared.listFolders()
                }
            }
            .onAppear {
                if ObsidianVaultManager.shared.hasVaultAccess {
                    vaultFolders = ObsidianVaultManager.shared.listFolders()
                }
            }
        }
    }

    @ViewBuilder
    private func obsidianSettings(index: Int) -> some View {
        // Vault selection
        let hasAccess = ObsidianVaultManager.shared.hasVaultAccess
        let vaultDisplayName = ObsidianVaultManager.shared.vaultName ?? settings.actions[index].config["vault"] ?? ""

        if hasAccess {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vault")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(vaultDisplayName)
                        .font(.system(size: 15))
                }
                Spacer()
                Button("Change") {
                    showVaultPicker = true
                }
                .font(.system(size: 14))
            }

            // Destination folder picker
            if !vaultFolders.isEmpty {
                Picker("Save to", selection: configBinding(index: index, key: "folder")) {
                    Text("Vault root").tag("")
                    ForEach(vaultFolders, id: \.self) { folder in
                        Text(folder).tag(folder)
                    }
                }
                .font(.system(size: 14))
            } else {
                SettingsField(
                    label: "Folder",
                    placeholder: "Inbox",
                    text: configBinding(index: index, key: "folder")
                )
            }
        } else {
            Button {
                showVaultPicker = true
            } label: {
                HStack {
                    Image(systemName: "folder.badge.plus")
                    Text("Select Obsidian Vault")
                }
                .font(.system(size: 15, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            // Fallback manual config
            SettingsField(
                label: "Vault name (for URI fallback)",
                placeholder: "My Vault",
                text: configBinding(index: index, key: "vault")
            )
            SettingsField(
                label: "Folder",
                placeholder: "Inbox",
                text: configBinding(index: index, key: "folder")
            )
        }

        // Daily note toggle
        Toggle("Append to daily note", isOn: dailyNoteBinding(index: index))
            .font(.system(size: 14))
        if settings.actions[index].config["dailyNote"] == "true" {
            if hasAccess {
                Text("Select the folder containing your daily notes above")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                Text("Requires the Advanced URI plugin in Obsidian")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }

        // Remove vault access
        if hasAccess {
            Button(role: .destructive) {
                ObsidianVaultManager.shared.clearVault()
                settings.updateConfig("obsidian", key: "useDirectAccess", value: "false")
                vaultFolders = []
            } label: {
                Text("Disconnect Vault")
                    .font(.system(size: 14))
            }
        }
    }

    private func configBinding(index: Int, key: String) -> Binding<String> {
        Binding(
            get: { settings.actions[index].config[key] ?? "" },
            set: { settings.actions[index].config[key] = $0 }
        )
    }

    private func dailyNoteBinding(index: Int) -> Binding<Bool> {
        Binding(
            get: { settings.actions[index].config["dailyNote"] == "true" },
            set: { settings.actions[index].config["dailyNote"] = $0 ? "true" : "false" }
        )
    }

    private func boolBinding(index: Int, key: String) -> Binding<Bool> {
        Binding(
            get: { settings.actions[index].config[key] == "true" },
            set: { settings.actions[index].config[key] = $0 ? "true" : "false" }
        )
    }
}

// MARK: - Vault Folder Picker (wraps UIDocumentPickerViewController)

struct VaultFolderPicker: UIViewControllerRepresentable {
    let onSelect: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onSelect: (URL) -> Void

        init(onSelect: @escaping (URL) -> Void) {
            self.onSelect = onSelect
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onSelect(url)
        }
    }
}

struct ActionToggleRow: View {
    @Binding var action: ActionConfig

    var body: some View {
        Toggle(isOn: $action.isEnabled) {
            Label(action.name, systemImage: action.icon)
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
        }
    }
}
