import UIKit
import SwiftUI
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        extractURL { [weak self] url in
            guard let self, let url else {
                self?.close()
                return
            }

            var appComponents = URLComponents()
            appComponents.scheme = "snaproute"
            appComponents.host = "open"
            appComponents.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
            let appURL = appComponents.url

            let shareView = ShareSheetView(
                url: url,
                onOpenInApp: { [weak self] in self?.openExternalURL(appURL) },
                onSafari: { [weak self] in self?.openExternalURL(url) },
                onShelfRead: { [weak self] in self?.sendToShelfRead(url: url) },
                onObsidian: { [weak self] in self?.openExternalURL(self?.buildObsidianURL(url: url)) },
                onCopyLink: { [weak self] in self?.copyLink(url: url) },
                onCancel: { [weak self] in self?.close() }
            )

            let hostingController = UIHostingController(rootView: shareView)
            hostingController.view.backgroundColor = .clear
            self.addChild(hostingController)
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(hostingController.view)
            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: self.view.topAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            ])
            hostingController.didMove(toParent: self)
        }
    }

    // MARK: - URL Extraction

    private func extractURL(completion: @escaping (URL?) -> Void) {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            completion(nil)
            return
        }
        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { data, _ in
                        DispatchQueue.main.async {
                            if let url = data as? URL { completion(url) }
                            else if let d = data as? Data, let url = URL(dataRepresentation: d, relativeTo: nil) { completion(url) }
                            else { completion(nil) }
                        }
                    }
                    return
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
                        DispatchQueue.main.async {
                            if let text = data as? String,
                               let range = text.range(of: "https?://[^\\s]+", options: .regularExpression),
                               let url = URL(string: String(text[range])) { completion(url) }
                            else { completion(nil) }
                        }
                    }
                    return
                }
            }
        }
        completion(nil)
    }

    // MARK: - Actions

    @objc private func openURL(_ url: URL) -> Bool {
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:]) { _ in }
                return true
            }
            responder = responder?.next
        }
        return false
    }

    private func openExternalURL(_ url: URL?) {
        guard let url else { return }
        _ = openURL(url)
        close()
    }

    private func sendToShelfRead(url: URL) {
        let defaults = UserDefaults(suiteName: "group.com.rawplusdry.snaproute") ?? .standard
        let ingestStr = defaults.string(forKey: "shelfReadIngestURL") ?? ""

        guard !ingestStr.isEmpty,
              let baseComponents = URLComponents(string: ingestStr) else {
            showFeedbackAndDismiss("ShelfRead not configured", delay: 1.5)
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
                // Got HTML — use /ingest-article
                components.path = "/ingest-article"
                payload["html"] = html
            } else {
                // Fetch failed — fall back to /ingest-url
                components.path = "/ingest-url"
            }

            guard let endpoint = components.url else {
                DispatchQueue.main.async { self?.showFeedbackAndDismiss("ShelfRead not configured", delay: 1.5) }
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
                        self?.showFeedbackAndDismiss("Failed to send", delay: 1.5)
                    } else if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                        self?.showFeedbackAndDismiss("Sent to ShelfRead ✓", delay: 1.0)
                    } else {
                        self?.showFeedbackAndDismiss("ShelfRead error", delay: 1.5)
                    }
                }
            }.resume()
        }.resume()
    }

    private func buildObsidianURL(url: URL) -> URL? {
        let defaults = UserDefaults(suiteName: "group.com.rawplusdry.snaproute") ?? .standard
        let vault = defaults.string(forKey: "obsidianVault") ?? ""
        let folder = defaults.string(forKey: "obsidianFolder") ?? "Inbox"
        let title = url.host ?? "Untitled"
        let content = "# \(title)\n\nSource: [\(url.absoluteString)](\(url.absoluteString))\n\nSaved from SnapRoute"

        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "new"
        components.queryItems = [
            URLQueryItem(name: "name", value: title),
            URLQueryItem(name: "content", value: content),
        ]
        if !vault.isEmpty { components.queryItems?.append(URLQueryItem(name: "vault", value: vault)) }
        if !folder.isEmpty { components.queryItems?.append(URLQueryItem(name: "path", value: "\(folder)/\(title)")) }
        return components.url
    }

    private func copyLink(url: URL) {
        UIPasteboard.general.url = url
        showFeedbackAndDismiss("Link copied ✓", delay: 0.8)
    }

    // MARK: - Helpers

    private func showFeedbackAndDismiss(_ message: String, delay: TimeInterval) {
        let toast = UILabel()
        toast.text = message
        toast.font = .systemFont(ofSize: 15, weight: .semibold)
        toast.textColor = .label
        toast.textAlignment = .center
        toast.backgroundColor = UIColor.secondarySystemBackground
        toast.layer.cornerRadius = 16
        toast.clipsToBounds = true
        toast.alpha = 0
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            toast.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
            toast.heightAnchor.constraint(equalToConstant: 50),
        ])
        UIView.animate(withDuration: 0.15) { toast.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.close()
        }
    }

    private func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
