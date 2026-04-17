import SwiftUI

struct ContentView: View {
    @ObservedObject var router: URLRouter
    @State private var showSettings = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            // Layer 1: Full-screen web preview or background
            if let url = router.previewURL {
                WebPreview(url: url, onTitleLoaded: { title in
                    router.pageTitle = title
                }, onURLChanged: { newURL in
                    // Record the page visit in history
                    if router.previewURL != newURL {
                        HistoryStore.add(HistoryEntry(
                            id: UUID(),
                            url: newURL.absoluteString,
                            title: router.pageTitle,
                            text: nil,
                            action: "visit",
                            timestamp: Date()
                        ))
                    }
                    router.inputText = newURL.absoluteString
                    router.previewURL = newURL
                    router.inputMode = .url(newURL)
                    router.pageTitle = nil
                }, onWebViewReady: { webView in
                    router.webView = webView
                })
                .ignoresSafeArea(.keyboard)
                .ignoresSafeArea(.container)
            } else {
                Color(.systemBackground)
                    .ignoresSafeArea()
            }

            // Layer 2: Floating bar or minimized bubble
            if router.isMinimized {
                HStack {
                    Spacer()
                    MinimizedBubble {
                        router.toggleMinimize()
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
                .transition(.scale.combined(with: .opacity))
            } else {
                FloatingInputBar(
                    router: router,
                    showSettings: $showSettings,
                    isInputFocused: $isInputFocused
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: router.isMinimized)
        .sheet(isPresented: $showSettings) {
            SettingsView(onDismiss: { router.reloadSettings() })
        }
        .sheet(isPresented: $router.showHistory) {
            HistoryView { url in
                router.handleURL(url)
            }
        }
        .onOpenURL { url in
            router.handleURL(url)
        }
        .onAppear {
            if router.previewURL == nil {
                isInputFocused = true
            }
        }
    }
}
