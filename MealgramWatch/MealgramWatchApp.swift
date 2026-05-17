import SwiftUI

@main
struct MealgramWatchApp: App {
    @State private var store = WatchStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
