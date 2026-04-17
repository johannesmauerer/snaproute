import SwiftUI
import WebKit

// MARK: - Floating Input Bar

struct FloatingInputBar: View {
    @ObservedObject var router: URLRouter
    @Binding var showSettings: Bool
    @FocusState.Binding var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            // Result toast
            if let result = router.actionResult {
                HStack(spacing: 6) {
                    Image(systemName: result.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 13))
                    Text(result.message)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(result.isError ? Color.red : Color.green)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    (result.isError ? Color.red : Color.green).opacity(0.1)
                )
                .clipShape(Capsule())
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // Action buttons — 2-column grid
            let actions = router.availableActions
            if !actions.isEmpty {
                ActionGrid(actions: actions)
                    .padding(.horizontal, 12)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // Input row
            HStack(spacing: 10) {
                Image(systemName: inputIcon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                TextField("Search or enter URL...", text: $router.inputText, axis: .vertical)
                    .font(.system(size: 16))
                    .lineLimit(1...4)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .keyboardType(.webSearch)
                    .submitLabel(.search)
                    .focused($isInputFocused)
                    .onSubmit {
                        router.handleSubmit()
                    }

                // Clear button
                if !router.inputText.isEmpty {
                    Button {
                        router.clearInput()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary.opacity(0.6))
                    }
                }

                // Minimize button
                Button {
                    isInputFocused = false
                    router.toggleMinimize()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }

                // Settings
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .padding(.top, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.12), radius: 16, y: -2)
        .animation(.easeInOut(duration: 0.2), value: router.inputMode)
        .animation(.easeInOut(duration: 0.2), value: router.actionResult?.id)
    }

    private var inputIcon: String {
        switch router.inputMode {
        case .empty: return "magnifyingglass"
        case .url: return "globe"
        case .text: return "pencil"
        }
    }
}

// MARK: - Minimized Bubble

struct MinimizedBubble: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 52, height: 52)
                .background(.regularMaterial)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 12, y: 2)
        }
    }
}

// MARK: - Action Grid

struct ActionGrid: View {
    let actions: [RouteAction]

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(actions) { action in
                ActionGridButton(action: action)
            }
        }
    }
}

struct ActionGridButton: View {
    let action: RouteAction
    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: action.icon)
                .font(.system(size: 13, weight: .semibold))
            Text(action.label)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.systemBackground).opacity(isPressed ? 0.5 : 0.8))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .foregroundStyle(.primary)
        .onTapGesture { action.perform() }
        .onLongPressGesture(minimumDuration: 0.4, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) { isPressed = pressing }
        }) {
            if let longPress = action.onLongPress {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                longPress()
            } else {
                action.perform()
            }
        }
    }
}

// MARK: - Web Preview

struct WebPreview: UIViewRepresentable {
    let url: URL
    let onTitleLoaded: (String) -> Void
    var onURLChanged: ((URL) -> Void)?
    var onWebViewReady: ((WKWebView) -> Void)?

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.processPool = URLRouter.sharedProcessPool
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.requestedURL = url
        webView.load(URLRequest(url: url))
        onWebViewReady?(webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.requestedURL != url {
            context.coordinator.requestedURL = url
            webView.load(URLRequest(url: url))
        }
        context.coordinator.onURLChanged = onURLChanged
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTitleLoaded: onTitleLoaded, onURLChanged: onURLChanged)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let onTitleLoaded: (String) -> Void
        var onURLChanged: ((URL) -> Void)?
        var requestedURL: URL?

        init(onTitleLoaded: @escaping (String) -> Void, onURLChanged: ((URL) -> Void)?) {
            self.onTitleLoaded = onTitleLoaded
            self.onURLChanged = onURLChanged
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let title = webView.title, !title.isEmpty {
                DispatchQueue.main.async {
                    self.onTitleLoaded(title)
                }
            }
            // Update URL bar when user navigates within the browser
            if let currentURL = webView.url, currentURL != requestedURL {
                requestedURL = currentURL
                DispatchQueue.main.async {
                    self.onURLChanged?(currentURL)
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {}
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {}
    }
}

