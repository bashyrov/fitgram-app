#if DEBUG
import Foundation
import OSLog
import SwiftData

/// Launch-time arguments for screenshot / preview flows. Compiled out of
/// release builds entirely via `#if DEBUG` so production never branches
/// on this.
enum DebugBypass {
    /// Pass `-fitgramDebugBypassAuth 1` (or set the env var) at launch
    /// to skip Sign in with Apple + onboarding and land in the main
    /// scene with seeded sample meals.
    static var bypassAuth: Bool {
        flag("fitgramDebugBypassAuth", env: "FITGRAM_DEBUG_BYPASS_AUTH")
    }

    /// Pass `-fitgramDebugOnboarding 1` (with `-fitgramDebugResetData 1`)
    /// to sign in as a fresh, unseeded user so the onboarding flow shows.
    static var forceOnboarding: Bool {
        flag("fitgramDebugOnboarding", env: "FITGRAM_DEBUG_ONBOARDING")
    }

    /// Pass `-fitgramDebugPremium 1` to start with a mock Premium
    /// subscription (screenshots of Premium-only surfaces such as posts).
    static var premium: Bool {
        flag("fitgramDebugPremium", env: "FITGRAM_DEBUG_PREMIUM")
    }

    /// Pass `-fitgramDebugResetData 1` once from Xcode/devicectl to wipe
    /// local stores and keychain before the app boots normally.
    static var resetData: Bool {
        flag("fitgramDebugResetData", env: "FITGRAM_DEBUG_RESET_DATA")
    }

    /// Override the initial tab. Values: "today" | "progress" | "profile".
    /// Useful for screenshot scripts.
    static var initialTab: String? {
        ProcessInfo.processInfo.environment["FITGRAM_DEBUG_TAB"]
    }

    /// Auto-open a sheet after launch for screenshot capture.
    /// Values: "streak-share" | "weight-log" | "ola-tips".
    static var initialSheet: String? {
        ProcessInfo.processInfo.environment["FITGRAM_DEBUG_SHEET"]
    }

    /// Auto-scroll a scrollable view to an anchor for screenshots.
    /// Values: "journey".
    static var initialScroll: String? {
        ProcessInfo.processInfo.environment["FITGRAM_DEBUG_SCROLL"]
    }

    static let fakeAuthUser = AuthUser(
        id: "debug-user-001",
        email: "demo@fitgram.space",
        displayName: "Anna",
        provider: .apple
    )

    private static func flag(_ argumentName: String, env: String) -> Bool {
        if ProcessInfo.processInfo.environment[env] == "1" {
            return true
        }
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-\(argumentName)") else {
            return false
        }
        let nextIndex = arguments.index(after: index)
        guard nextIndex < arguments.endIndex else {
            return true
        }
        return arguments[nextIndex] != "0"
    }
}
#endif
