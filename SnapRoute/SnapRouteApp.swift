import SwiftUI

@main
struct SnapRouteApp: App {
    @StateObject private var router = URLRouter()

    var body: some Scene {
        WindowGroup {
            ContentView(router: router)
                .onOpenURL { url in
                    router.handleURL(url)
                }
        }
    }
}
