import SwiftUI

struct ContentView: View {
    @ObservedObject var router: URLRouter
    @State private var showSettings = false

    var body: some View {
        if let url = router.currentURL {
            ActionView(url: url, router: router, showSettings: $showSettings)
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
        } else {
            EmptyStateView(router: router, showSettings: $showSettings)
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
        }
    }
}

struct EmptyStateView: View {
    @ObservedObject var router: URLRouter
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                // Logo mark — sharp, geometric
                ZStack {
                    Rectangle()
                        .fill(.primary.opacity(0.04))
                        .frame(width: 72, height: 72)
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.primary.opacity(0.6))
                }

                VStack(spacing: 6) {
                    Text("SnapRoute")
                        .font(.system(size: 22, weight: .semibold, design: .default))
                        .tracking(0.5)
                    Text("Set as default browser in\nSettings \u{2192} Apps \u{2192} Default Browser")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
            }

            Spacer()

            VStack(spacing: 8) {
                #if DEBUG
                Button {
                    router.handleURL(URL(string: "https://example.com")!)
                } label: {
                    Text("Test")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.4))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(.primary.opacity(0.1), lineWidth: 1)
                        )
                }
                #endif

                Button {
                    showSettings = true
                } label: {
                    Text("Settings")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.4))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(.primary.opacity(0.1), lineWidth: 1)
                        )
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
    }
}
