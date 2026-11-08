import Foundation

/// A `fitgram://friend/<id>` link that opened the app. Kept until the
/// signed-in main screen picks it up, so a link that cold-starts the app
/// (or arrives on the sign-in screen) still lands in the friends window.
@MainActor
enum PendingFriendLink {
    static let notification = Notification.Name("FitgramOpenFriendLink")
    static var code: String?

    static func take() -> String? {
        defer { code = nil }
        return code
    }
}
