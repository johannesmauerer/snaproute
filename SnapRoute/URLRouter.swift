import Foundation
import SwiftUI
import Combine

enum InputMode: Equatable {
    case empty
    case text(String)
    case url(URL)

    static func == (lhs: InputMode, rhs: InputMode) -> Bool {
        switch (lhs, rhs) {
        case (.empty, .empty): return true
        case (.text(let a), .text(let b)): return a == b
        case (.url(let a), .url(let b)): return a == b
        default: return false
        }
    }
}

struct RouteAction: Identifiable {
    let id: String
    let label: String
    let icon: String
    let perform: () -> Void
}

@MainActor
class URLRouter: ObservableObject {
    @Published var inputText: String = ""
    @Published var inputMode: InputMode = .empty
    @Published var previewURL: URL?
    @Published var pageTitle: String?
    @Published var actionResult: ActionResult?
    @Published var isMinimized: Bool = false
    @Published var showHistory: Bool = false

    private var cancellables = Set<AnyCancellable>()

    struct ActionResult: Identifiable {
        let id = UUID()
        let message: String
        let isError: Bool
    }

    private func showToast(_ message: String, isError: Bool) {
        actionResult = ActionResult(message: message, isError: isError)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.actionResult?.message == message {
                self?.actionResult = nil
            }
        }
    }

    var availableActions: [RouteAction] {
        let settings = Settings.load()

        switch inputMode {
        case .empty:
            return [RouteAction(id: "history", label: "History", icon: "clock.arrow.circlepath", perform: { self.showHistory = true })]
        case .text:
            var actions: [RouteAction] = []
            if settings.isEnabled("search") {
                actions.append(RouteAction(id: "search", label: "Search", icon: "magnifyingglass", perform: searchGoogle))
            }
            if settings.isEnabled("obsidian") {
                actions.append(RouteAction(id: "note", label: "Note", icon: "note.text", perform: saveTextToObsidian))
            }
            if settings.isEnabled("copy") {
                actions.append(RouteAction(id: "copy", label: "Copy", icon: "doc.on.doc", perform: copyContent))
            }
            actions.append(RouteAction(id: "history", label: "History", icon: "clock.arrow.circlepath", perform: { self.showHistory = true }))
            return actions
        case .url:
            var actions: [RouteAction] = []
            if settings.isEnabled("safari") {
                actions.append(RouteAction(id: "safari", label: "Safari", icon: "safari", perform: openInSafari))
            }
            if settings.isEnabled("shelfRead") {
                actions.append(RouteAction(id: "shelfRead", label: "ShelfRead", icon: "book.closed", perform: sendToShelfRead))
            }
            if settings.isEnabled("obsidian") {
                actions.append(RouteAction(id: "obsidian", label: "Obsidian", icon: "square.and.arrow.down", perform: saveToObsidian))
            }
            if settings.isEnabled("copy") {
                actions.append(RouteAction(id: "copy", label: "Copy", icon: "doc.on.doc", perform: copyContent))
            }
            actions.append(RouteAction(id: "history", label: "History", icon: "clock.arrow.circlepath", perform: { self.showHistory = true }))
            return actions
        }
    }

    init() {
        $inputText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.detectInputMode()
            }
            .store(in: &cancellables)
    }

    // MARK: - Input Detection

    private func detectInputMode() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            inputMode = .empty
            previewURL = nil
            pageTitle = nil
            actionResult = nil
            return
        }

        // Explicit http/https URL
        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           (scheme == "http" || scheme == "https"),
           url.host != nil {
            inputMode = .url(url)
            previewURL = url
            pageTitle = nil
            actionResult = nil
            return
        }

        // Domain-like: has dot, no spaces → prepend https://
        if !trimmed.contains(" "), trimmed.contains("."),
           let url = URL(string: "https://\(trimmed)"),
           url.host != nil {
            inputMode = .url(url)
            previewURL = url
            pageTitle = nil
            actionResult = nil
            return
        }

        // Plain text
        inputMode = .text(trimmed)
    }

    // MARK: - Deep Link Handling

    func handleURL(_ url: URL) {
        if url.scheme?.lowercased() == "snaproute",
           url.host == "open",
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let urlParam = components.queryItems?.first(where: { $0.name == "url" })?.value,
           let realURL = URL(string: urlParam) {
            inputText = realURL.absoluteString
            previewURL = realURL
            inputMode = .url(realURL)
            pageTitle = nil
            actionResult = nil
            isMinimized = false
            return
        }

        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return
        }
        inputText = url.absoluteString
        previewURL = url
        inputMode = .url(url)
        pageTitle = nil
        actionResult = nil
        isMinimized = false
    }

    // MARK: - Submit (Return key)

    func handleSubmit() {
        switch inputMode {
        case .empty: break
        case .text: searchGoogle()
        case .url: break
        }
    }

    // MARK: - Minimize / Expand

    func toggleMinimize() {
        isMinimized.toggle()
    }

    // MARK: - Actions

    func clearInput() {
        inputText = ""
        inputMode = .empty
        previewURL = nil
        pageTitle = nil
        actionResult = nil
    }

    func openInSafari() {
        guard let url = previewURL else { return }
        recordHistory(action: "safari")
        UIApplication.shared.open(url)
    }

    func searchGoogle() {
        guard case .text(let query) = inputMode else { return }
        recordHistory(action: "search")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://www.google.com/search?q=\(encoded)") else { return }
        previewURL = url
        inputMode = .url(url)
        inputText = url.absoluteString
        pageTitle = nil
        actionResult = nil
    }

    func sendToShelfRead() {
        guard let url = previewURL else { return }

        let settings = Settings.load()
        let ingestURL = settings.shelfReadIngestURL
        guard !ingestURL.isEmpty else {
            showToast("ShelfRead URL not configured", isError: true)
            return
        }

        guard let baseComponents = URLComponents(string: ingestURL) else {
            showToast("Invalid ShelfRead URL", isError: true)
            return
        }

        // Fetch page HTML first, then send to /ingest-article
        var fetchRequest = URLRequest(url: url)
        fetchRequest.timeoutInterval = 10
        fetchRequest.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: fetchRequest) { [weak self] data, fetchResponse, fetchError in
            var components = baseComponents
            var payload: [String: String] = ["url": url.absoluteString]

            if fetchError == nil,
               let data,
               let html = String(data: data, encoding: .utf8),
               html.count >= 100 {
                components.path = "/ingest-article"
                payload["html"] = html
            } else {
                components.path = "/ingest-url"
            }

            guard let endpoint = components.url else {
                DispatchQueue.main.async { self?.showToast("Invalid ShelfRead URL", isError: true) }
                return
            }

            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 15
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

            URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
                DispatchQueue.main.async {
                    if error != nil {
                        self?.showToast("Failed to send", isError: true)
                    } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                        self?.recordHistory(action: "shelfRead")
                        self?.showToast("Sent to ShelfRead", isError: false)
                    } else {
                        self?.showToast("ShelfRead error", isError: true)
                    }
                }
            }.resume()
        }.resume()
    }

    func saveToObsidian() {
        guard let url = previewURL else { return }
        recordHistory(action: "obsidian")
        let settings = Settings.load()
        let title = pageTitle ?? url.host ?? "Untitled"
        let time = Self.timeFormatter.string(from: Date())
        let content = "- \(time) [\(title)](\(url.absoluteString))"

        if settings.obsidianDailyNote {
            appendToDailyNote(content: content, settings: settings)
        } else {
            let fullContent = "# \(title)\n\nSource: [\(url.absoluteString)](\(url.absoluteString))\n\nSaved from SnapRoute on \(Self.dateFormatter.string(from: Date()))"
            openObsidianNote(title: title, content: fullContent, settings: settings)
        }
    }

    func saveTextToObsidian() {
        guard case .text(let text) = inputMode else { return }
        recordHistory(action: "note")
        let settings = Settings.load()

        if settings.obsidianDailyNote {
            let time = Self.timeFormatter.string(from: Date())
            appendToDailyNote(content: "- \(time) \(text)", settings: settings)
        } else {
            let title = String(text.prefix(50)).replacingOccurrences(of: "\n", with: " ")
            openObsidianNote(title: title, content: text, settings: settings)
        }
    }

    func copyContent() {
        recordHistory(action: "copy")
        switch inputMode {
        case .url(let url):
            UIPasteboard.general.url = url
            showToast("Link copied", isError: false)
        case .text(let text):
            UIPasteboard.general.string = text
            showToast("Copied", isError: false)
        case .empty:
            break
        }
    }

    // MARK: - Obsidian Helpers

    private func appendToDailyNote(content: String, settings: Settings) {
        // Use Advanced URI plugin: obsidian://adv-uri?vault=X&daily=true&data=Y&mode=append
        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "adv-uri"
        components.queryItems = [
            URLQueryItem(name: "daily", value: "true"),
            URLQueryItem(name: "data", value: content),
            URLQueryItem(name: "mode", value: "append"),
        ]
        if !settings.obsidianVault.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "vault", value: settings.obsidianVault))
        }

        if let url = components.url {
            UIApplication.shared.open(url) { [weak self] success in
                DispatchQueue.main.async {
                    if success {
                        self?.showToast("Added to daily note", isError: false)
                    } else {
                        self?.showToast("Obsidian or Advanced URI not installed", isError: true)
                    }
                }
            }
        }
    }

    private func openObsidianNote(title: String, content: String, settings: Settings) {
        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "new"
        components.queryItems = [
            URLQueryItem(name: "name", value: title),
            URLQueryItem(name: "content", value: content),
        ]
        if !settings.obsidianVault.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "vault", value: settings.obsidianVault))
        }
        if !settings.obsidianFolder.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "path", value: "\(settings.obsidianFolder)/\(title)"))
        }

        if let obsidianURL = components.url {
            UIApplication.shared.open(obsidianURL) { [weak self] success in
                if !success {
                    DispatchQueue.main.async {
                        self?.showToast("Obsidian not installed", isError: true)
                    }
                }
            }
        }
    }

    private func recordHistory(action: String) {
        let entry = HistoryEntry(
            id: UUID(),
            url: previewURL?.absoluteString,
            title: pageTitle,
            text: inputMode == .text(inputText.trimmingCharacters(in: .whitespacesAndNewlines)) ? inputText.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            action: action,
            timestamp: Date()
        )
        HistoryStore.add(entry)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}
