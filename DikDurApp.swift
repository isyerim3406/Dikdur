import SwiftUI

@main
struct DikDurApp: App {
    @StateObject private var monitor = PostureMonitor()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(monitor)
        }
    }
}
