import OSLog

extension Logger {
    /// Shared subsystem identifier — keeps Console.app filters concise.
    static let subsystem = Bundle.main.bundleIdentifier ?? "app.mealgram.ios"

    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let keychain = Logger(subsystem: subsystem, category: "keychain")
    static let networking = Logger(subsystem: subsystem, category: "networking")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let coach = Logger(subsystem: subsystem, category: "coach")
}
