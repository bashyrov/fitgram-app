import SwiftUI

@main
struct FitgramWatchApp: App {
    @State private var store = WatchStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
