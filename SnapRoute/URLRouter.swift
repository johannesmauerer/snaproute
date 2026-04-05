import Foundation
import SwiftUI

@MainActor
class URLRouter: ObservableObject {
    @Published var currentURL: URL?
    @Published var pageTitle: String?
    @Published var actionResult: ActionResult?

    struct ActionResult: Identifiable {
        let id = UUID()
        let message: String
        let isError: Bool
    }

    func handleURL(_ url: URL) {
        // Only handle http/https URLs
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return
        }
        currentURL = url
        pageTitle = nil
        actionResult = nil
    }

    func openInSafari() {
        guard let url = currentURL else { return }
        UIApplication.shared.open(url)
    }

    func sendToShelfRead() {
        guard let url = currentURL else { return }

        let settings = Settings.load()
        guard !settings.shelfReadIngestURL.isEmpty else {
            actionResult = ActionResult(message: "ShelfRead ingest URL not configured", isError: true)
            return
        }

        guard let ingestURL = URL(string: settings.shelfReadIngestURL) else {
            actionResult = ActionResult(message: "Invalid ShelfRead URL", isError: true)
            return
        }

        var request = URLRequest(url: ingestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "from": "snaproute@local",
            "subject": pageTitle ?? url.host ?? "Shared Link",
            "htmlBody": "<html><body><p>Shared from SnapRoute:</p><p><a href=\"\(url.absoluteString)\">\(url.absoluteString)</a></p></body></html>",
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.actionResult = ActionResult(message: "Failed: \(error.localizedDescription)", isError: true)
                } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    self?.actionResult = ActionResult(message: "Sent to ShelfRead", isError: false)
                } else {
                    self?.actionResult = ActionResult(message: "ShelfRead returned an error", isError: true)
                }
            }
        }.resume()
    }

    func saveToObsidian() {
        guard let url = currentURL else { return }

        let settings = Settings.load()
        let vault = settings.obsidianVault
        let folder = settings.obsidianFolder

        let title = pageTitle ?? url.host ?? "Untitled"
        let content = """
        # \(title)

        Source: [\(url.absoluteString)](\(url.absoluteString))

        Saved from SnapRoute on \(Self.dateFormatter.string(from: Date()))
        """

        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "new"
        components.queryItems = [
            URLQueryItem(name: "name", value: title),
            URLQueryItem(name: "content", value: content),
        ]

        if !vault.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "vault", value: vault))
        }
        if !folder.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "path", value: "\(folder)/\(title)"))
        }

        if let obsidianURL = components.url {
            UIApplication.shared.open(obsidianURL) { success in
                if !success {
                    self.actionResult = ActionResult(message: "Obsidian not installed", isError: true)
                }
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
