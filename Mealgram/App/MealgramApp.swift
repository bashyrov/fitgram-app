import SwiftUI

@main
struct MealgramApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Tokens.Palette.primary)
                .preferredColorScheme(nil)  // follow system; design works in both
        }
    }
}
