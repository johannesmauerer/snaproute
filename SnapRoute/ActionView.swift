import SwiftUI
import WebKit

struct ActionView: View {
    let url: URL
    @ObservedObject var router: URLRouter
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            // URL bar — minimal, sharp
            HStack(spacing: 8) {
                Text(url.host ?? url.absoluteString)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.5))
                    .lineLimit(1)
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.35))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            // Thin separator
            Rectangle()
                .fill(.primary.opacity(0.06))
                .frame(height: 1)

            // Web preview — top half
            WebPreview(url: url, onTitleLoaded: { title in
                router.pageTitle = title
            })

            // Thin separator
            Rectangle()
                .fill(.primary.opacity(0.06))
                .frame(height: 1)

            // Result toast
            if let result = router.actionResult {
                HStack(spacing: 6) {
                    Circle()
                        .fill(result.isError ? .red : Color(hex: "2D6A4F"))
                        .frame(width: 6, height: 6)
                    Text(result.message)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(result.isError ? .red : Color(hex: "2D6A4F"))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }

            // Action buttons — bottom, easy reach
            VStack(spacing: 8) {
                ActionButton(
                    title: "Safari",
                    icon: "arrow.up.right",
                    accent: Color(hex: "1A1A1A")
                ) {
                    router.openInSafari()
                }

                ActionButton(
                    title: "ShelfRead",
                    icon: "text.page",
                    accent: Color(hex: "1A1A1A")
                ) {
                    router.sendToShelfRead()
                }

                ActionButton(
                    title: "Obsidian",
                    icon: "square.and.arrow.down",
                    accent: Color(hex: "1A1A1A")
                ) {
                    router.saveToObsidian()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.bottom, 4)
        }
        .background(Color(.systemBackground))
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.2))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.primary.opacity(0.03))
            .foregroundStyle(accent)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.primary.opacity(0.06), lineWidth: 1)
            )
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

// Hex color extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}
