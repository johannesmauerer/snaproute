import Foundation
import UIKit

/// Manages direct file access to an Obsidian vault via security-scoped bookmarks.
/// Shared between main app and extensions through app group UserDefaults.
class ObsidianVaultManager {

    static let shared = ObsidianVaultManager()

    private let appGroupID = "group.com.rawplusdry.snaproute"
    private let bookmarkKey = "obsidianVaultBookmark"
    private let vaultNameKey = "obsidianVaultName"

    private var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    // MARK: - Vault Access

    /// Whether a vault has been selected and bookmarked.
    var hasVaultAccess: Bool {
        defaults.data(forKey: bookmarkKey) != nil
    }

    /// The display name of the selected vault folder.
    var vaultName: String? {
        defaults.string(forKey: vaultNameKey)
    }

    /// Resolve the security-scoped bookmark into a usable URL.
    /// Caller must call `stopAccessingSecurityScopedResource()` when done.
    func resolveVaultURL() -> URL? {
        guard let bookmarkData = defaults.data(forKey: bookmarkKey) else { return nil }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        if isStale {
            // Re-save the bookmark
            saveBookmark(for: url)
        }

        guard url.startAccessingSecurityScopedResource() else { return nil }
        return url
    }

    /// Save a security-scoped bookmark for the selected vault folder.
    func saveBookmark(for url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let bookmarkData = try? url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }

        defaults.set(bookmarkData, forKey: bookmarkKey)
        defaults.set(url.lastPathComponent, forKey: vaultNameKey)
    }

    /// Clear the saved vault bookmark.
    func clearVault() {
        defaults.removeObject(forKey: bookmarkKey)
        defaults.removeObject(forKey: vaultNameKey)
    }

    // MARK: - Read Folders

    /// List top-level folders in the vault (for destination picker).
    func listFolders() -> [String] {
        guard let vaultURL = resolveVaultURL() else { return [] }
        defer { vaultURL.stopAccessingSecurityScopedResource() }

        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: vaultURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map { $0.lastPathComponent }
            .sorted()
    }

    // MARK: - Write Files

    /// Save content as a new markdown file in the vault.
    /// - Parameters:
    ///   - title: Note title (used as filename)
    ///   - content: Markdown content
    ///   - folder: Subfolder path (e.g. "Inbox"). Created if it doesn't exist.
    /// - Returns: true if the file was written successfully.
    @discardableResult
    func saveNote(title: String, content: String, folder: String?) -> Bool {
        guard let vaultURL = resolveVaultURL() else { return false }
        defer { vaultURL.stopAccessingSecurityScopedResource() }

        let sanitizedTitle = sanitizeFilename(title)
        var targetDir = vaultURL
        if let folder, !folder.isEmpty {
            targetDir = vaultURL.appendingPathComponent(folder, isDirectory: true)
            try? FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        }

        let fileURL = targetDir.appendingPathComponent("\(sanitizedTitle).md")

        // Avoid overwriting — append number if needed
        let finalURL = uniqueFileURL(for: fileURL)
        return (try? content.write(to: finalURL, atomically: true, encoding: .utf8)) != nil
    }

    /// Append content to a daily note file (YYYY-MM-DD.md in vault root or configured folder).
    /// Creates the file if it doesn't exist.
    /// - Parameters:
    ///   - content: Line to append
    ///   - dailyNoteFolder: Optional folder for daily notes (e.g. "Daily Notes")
    /// - Returns: true if successful
    @discardableResult
    func appendToDailyNote(content: String, dailyNoteFolder: String? = nil) -> Bool {
        guard let vaultURL = resolveVaultURL() else { return false }
        defer { vaultURL.stopAccessingSecurityScopedResource() }

        let dateStr = Self.dailyNoteDateFormatter.string(from: Date())
        var targetDir = vaultURL
        if let folder = dailyNoteFolder, !folder.isEmpty {
            targetDir = vaultURL.appendingPathComponent(folder, isDirectory: true)
            try? FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        }

        let fileURL = targetDir.appendingPathComponent("\(dateStr).md")

        if FileManager.default.fileExists(atPath: fileURL.path) {
            // Append
            guard let handle = try? FileHandle(forWritingTo: fileURL) else { return false }
            handle.seekToEndOfFile()
            let line = "\n\(content)"
            guard let data = line.data(using: .utf8) else { return false }
            handle.write(data)
            handle.closeFile()
            return true
        } else {
            // Create with header
            let header = "# \(dateStr)\n\n\(content)"
            return (try? header.write(to: fileURL, atomically: true, encoding: .utf8)) != nil
        }
    }

    // MARK: - Helpers

    private func sanitizeFilename(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: illegal).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(100)
            .description
    }

    private func uniqueFileURL(for url: URL) -> URL {
        if !FileManager.default.fileExists(atPath: url.path) { return url }

        let dir = url.deletingLastPathComponent()
        let stem = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        for i in 1...99 {
            let candidate = dir.appendingPathComponent("\(stem) \(i).\(ext)")
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        return url // fallback
    }

    private static let dailyNoteDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
