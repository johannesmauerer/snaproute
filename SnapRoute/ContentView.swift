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
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("SnapRoute")
                .font(.title.bold())
            Text("Set as your default browser in\nSettings > Apps > Default Browser App")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            #if DEBUG
            Button("Test with example.com") {
                router.handleURL(URL(string: "https://example.com")!)
            }
            .padding(.bottom, 8)
            #endif
            Button("Settings") {
                showSettings = true
            }
            .padding(.bottom, 32)
        }
    }
}
