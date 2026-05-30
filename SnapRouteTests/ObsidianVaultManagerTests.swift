import XCTest
@testable import SnapRoute

/// Tests for the subfolder/nested-path support added to ObsidianVaultManager.
///
/// These run against a real on-disk vault rooted in a temp dir so we exercise the
/// FileManager + URL.appendPathComponent paths end-to-end, not a mock.
final class ObsidianVaultManagerTests: XCTestCase {

    private var tempVault: URL!
    private let appGroupID = "group.com.rawplusdry.snaproute"
    private let bookmarkKey = "obsidianVaultBookmark"
    private let vaultNameKey = "obsidianVaultName"

    private var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempVault = FileManager.default.temporaryDirectory
            .appendingPathComponent("EmberleapTestVault-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempVault, withIntermediateDirectories: true)

        // Install a bookmark pointing at the temp vault so the manager resolves to it.
        // Regular file URLs accept .startAccessingSecurityScopedResource() as a no-op,
        // so the manager's plumbing works end-to-end against tmp dirs.
        let bookmark = try tempVault.bookmarkData(options: .minimalBookmark)
        defaults.set(bookmark, forKey: bookmarkKey)
        defaults.set(tempVault.lastPathComponent, forKey: vaultNameKey)
    }

    override func tearDownWithError() throws {
        defaults.removeObject(forKey: bookmarkKey)
        defaults.removeObject(forKey: vaultNameKey)
        if let tempVault, FileManager.default.fileExists(atPath: tempVault.path) {
            try? FileManager.default.removeItem(at: tempVault)
        }
        try super.tearDownWithError()
    }

    // MARK: - listAllFolders

    func test_listAllFolders_returnsFlatTopLevel() throws {
        try makeDirs(["Inbox", "Daily Notes", "Personal"])
        let folders = ObsidianVaultManager.shared.listAllFolders()
        XCTAssertEqual(Set(folders), ["Daily Notes", "Inbox", "Personal"])
    }

    func test_listAllFolders_returnsNestedAsRelativePaths() throws {
        try makeDirs([
            "Personal",
            "Personal/Journal",
            "Personal/Journal/Daily",
            "Work/Projects/Q2",
        ])
        let folders = ObsidianVaultManager.shared.listAllFolders()
        XCTAssertTrue(folders.contains("Personal"))
        XCTAssertTrue(folders.contains("Personal/Journal"))
        XCTAssertTrue(folders.contains("Personal/Journal/Daily"))
        XCTAssertTrue(folders.contains("Work"))
        XCTAssertTrue(folders.contains("Work/Projects"))
        XCTAssertTrue(folders.contains("Work/Projects/Q2"))
    }

    func test_listAllFolders_skipsHiddenAndDotObsidian() throws {
        try makeDirs([".obsidian", ".obsidian/plugins", "Real"])
        let folders = ObsidianVaultManager.shared.listAllFolders()
        XCTAssertEqual(folders, ["Real"])
    }

    func test_listAllFolders_respectsMaxDepth() throws {
        try makeDirs(["a", "a/b", "a/b/c", "a/b/c/d", "a/b/c/d/e", "a/b/c/d/e/f", "a/b/c/d/e/f/g"])
        let folders = ObsidianVaultManager.shared.listAllFolders(maxDepth: 3)
        // Depth 1 = a, depth 2 = a/b, depth 3 = a/b/c. Deeper should be cut.
        XCTAssertTrue(folders.contains("a"))
        XCTAssertTrue(folders.contains("a/b"))
        XCTAssertTrue(folders.contains("a/b/c"))
        XCTAssertFalse(folders.contains("a/b/c/d"))
    }

    func test_listAllFolders_sortedAlphabetically() throws {
        try makeDirs(["Zeta", "Alpha", "Mu"])
        let folders = ObsidianVaultManager.shared.listAllFolders()
        XCTAssertEqual(folders, ["Alpha", "Mu", "Zeta"])
    }

    // MARK: - appendToDailyNote with nested folder

    func test_appendToDailyNote_createsNestedFolders_andWritesFile() throws {
        let nested = "Personal/Journal/Daily"
        let line = "- 12:34 picked up the dry cleaning"

        let ok = ObsidianVaultManager.shared.appendToDailyNote(
            content: line, dailyNoteFolder: nested
        )
        XCTAssertTrue(ok, "appendToDailyNote should succeed and create nested dirs")

        let dateStr = todayString()
        let expected = tempVault
            .appendingPathComponent("Personal")
            .appendingPathComponent("Journal")
            .appendingPathComponent("Daily")
            .appendingPathComponent("\(dateStr).md")

        XCTAssertTrue(FileManager.default.fileExists(atPath: expected.path),
                      "Daily note file should exist at the nested path: \(expected.path)")
        let contents = try String(contentsOf: expected, encoding: .utf8)
        XCTAssertEqual(contents, line)
    }

    func test_appendToDailyNote_appendsToExistingFile_acrossNestedPath() throws {
        let nested = "Work/Logs"
        let first = "- 09:00 first"
        let second = "- 10:00 second"

        XCTAssertTrue(ObsidianVaultManager.shared.appendToDailyNote(content: first, dailyNoteFolder: nested))
        XCTAssertTrue(ObsidianVaultManager.shared.appendToDailyNote(content: second, dailyNoteFolder: nested))

        let dateStr = todayString()
        let expected = tempVault
            .appendingPathComponent("Work")
            .appendingPathComponent("Logs")
            .appendingPathComponent("\(dateStr).md")
        let contents = try String(contentsOf: expected, encoding: .utf8)
        XCTAssertEqual(contents, "\(first)\n\(second)")
    }

    func test_appendToDailyNote_emptyFolder_writesAtVaultRoot() throws {
        let line = "- root line"
        XCTAssertTrue(ObsidianVaultManager.shared.appendToDailyNote(content: line, dailyNoteFolder: ""))
        let expected = tempVault.appendingPathComponent("\(todayString()).md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expected.path))
    }

    func test_appendToDailyNote_singleSegmentFolder_stillWorks() throws {
        let line = "- single segment"
        XCTAssertTrue(ObsidianVaultManager.shared.appendToDailyNote(content: line, dailyNoteFolder: "Inbox"))
        let expected = tempVault.appendingPathComponent("Inbox").appendingPathComponent("\(todayString()).md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expected.path))
    }

    // MARK: - saveNote with nested folder

    func test_saveNote_createsNestedFolders_andWritesMarkdown() throws {
        let nested = "Areas/Reading/Articles"
        let title = "An interesting post"
        let body = "# An interesting post\n\nbody body body"

        XCTAssertTrue(ObsidianVaultManager.shared.saveNote(title: title, content: body, folder: nested))

        let expected = tempVault
            .appendingPathComponent("Areas")
            .appendingPathComponent("Reading")
            .appendingPathComponent("Articles")
            .appendingPathComponent("\(title).md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expected.path))
        let contents = try String(contentsOf: expected, encoding: .utf8)
        XCTAssertEqual(contents, body)
    }

    func test_saveNote_doesNotOverwrite_collisionGetsSuffix() throws {
        let folder = "Inbox/Articles"
        let title = "same"
        XCTAssertTrue(ObsidianVaultManager.shared.saveNote(title: title, content: "a", folder: folder))
        XCTAssertTrue(ObsidianVaultManager.shared.saveNote(title: title, content: "b", folder: folder))

        let dir = tempVault.appendingPathComponent("Inbox").appendingPathComponent("Articles")
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()
        XCTAssertEqual(files, ["same 1.md", "same.md"])
    }

    // MARK: - Helpers

    private func makeDirs(_ relativePaths: [String]) throws {
        for relative in relativePaths {
            let url = tempVault.appendingPathComponent(relative, isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
