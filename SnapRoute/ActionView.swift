import SwiftUI
import WebKit

struct ActionView: View {
    let url: URL
    @ObservedObject var router: URLRouter
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            // URL bar
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text(url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))

            // Web preview — top half, loaded async (doesn't block actions)
            WebPreview(url: url, onTitleLoaded: { title in
                router.pageTitle = title
            })

            Divider()

            // Result toast
            if let result = router.actionResult {
                HStack {
                    Image(systemName: result.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                    Text(result.message)
                        .font(.subheadline)
                }
                .foregroundStyle(result.isError ? .red : .green)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            // Action buttons — bottom half, easy thumb reach
            VStack(spacing: 12) {
                ActionButton(
                    title: "Open in Safari",
                    icon: "safari",
                    color: .blue
                ) {
                    router.openInSafari()
                }

                ActionButton(
                    title: "Send to ShelfRead",
                    icon: "book.closed",
                    color: .orange
                ) {
                    router.sendToShelfRead()
                }

                ActionButton(
                    title: "Save to Obsidian",
                    icon: "square.and.arrow.down",
                    color: .purple
                ) {
                    router.saveToObsidian()
                }
            }
            .padding(16)
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24)
                Text(title)
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct WebPreview: UIViewRepresentable {
    let url: URL
    let onTitleLoaded: (String) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onTitleLoaded: onTitleLoaded)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let onTitleLoaded: (String) -> Void

        init(onTitleLoaded: @escaping (String) -> Void) {
            self.onTitleLoaded = onTitleLoaded
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let title = webView.title, !title.isEmpty {
                DispatchQueue.main.async {
                    self.onTitleLoaded(title)
                }
            }
        }
    }
}
