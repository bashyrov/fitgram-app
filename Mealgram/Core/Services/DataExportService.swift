import Foundation
import OSLog
import SwiftData

/// Builds a single JSON archive of everything Mealgram stores about a user —
/// required by RODO/GDPR and Apple Store guideline 5.1.1(iv). The bundle is
/// written to a temporary file so callers can hand it to `UIActivityViewController`
/// (share sheet) or attach it to an email.
@MainActor
final class DataExportService {
    private let container: ModelContainer
    private let encoder: JSONEncoder

    init(container: ModelContainer) {
        self.container = container
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        self.encoder = encoder
    }

    /// Returns the file URL of the freshly generated archive. Files are
    /// written to `tmp/exports/`, named with an ISO timestamp.
    func export(for userRemoteID: String) throws -> URL {
        let bundle = try snapshot(for: userRemoteID)
        let data = try encoder.encode(bundle)

        let directory = FileManager.default.temporaryDirectory.appending(path: "exports", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stamp = Self.fileTimestamp.string(from: bundle.generatedAt)
        let fileURL = directory.appending(path: "mealgram-export-\(stamp).json")
        try data.write(to: fileURL, options: [.atomic])
        Logger.persistence.notice("Exported user data to \(fileURL.lastPathComponent, privacy: .public)")
        return fileURL
    }

    /// Serializable snapshot of every user-owned row. Exposed for tests.
    func snapshot(for userRemoteID: String) throws -> ExportBundle {
        let context = ModelContext(container)
        let userFetch = FetchDescriptor<User>(
            predicate: #Predicate { $0.remoteID == userRemoteID }
        )
        let user = try context.fetch(userFetch).first.map(UserExport.init)

        // MealEntry doesn't currently store a userRemoteID — Phase 1 ships
        // single-user installs — so we export every entry on the device.
        let meals = try context.fetch(
            FetchDescriptor<MealEntry>(
                sortBy: [SortDescriptor(\MealEntry.consumedAt)]
            )
        ).map(MealExport.init)

        let recipes = try context.fetch(
            FetchDescriptor<Recipe>(
                sortBy: [SortDescriptor(\Recipe.createdAt)]
            )
        ).map(RecipeExport.init)

        let streak = try context.fetch(
            FetchDescriptor<Streak>(
                predicate: #Predicate { $0.userRemoteID == userRemoteID }
            )
        ).first.map(StreakExport.init)

        let achievements = try context.fetch(
            FetchDescriptor<Achievement>(
                predicate: #Predicate { $0.userRemoteID == userRemoteID },
                sortBy: [SortDescriptor(\Achievement.earnedAt)]
            )
        ).map(AchievementExport.init)

        return ExportBundle(
            generatedAt: Date(),
            schemaVersion: "1.0.0",
            appBuild: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0",
            user: user,
            meals: meals,
            recipes: recipes,
            streak: streak,
            achievements: achievements
        )
    }

    private static var fileTimestamp: DateFormatter {

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    
}
}

// MARK: - Wire format

/// Stable, version-bumped JSON shape exposed to the user export. Changes to
/// these structures must bump `schemaVersion` so external tools have a hint.
struct ExportBundle: Codable, Equatable {
    let generatedAt: Date
    let schemaVersion: String
    let appBuild: String
    let user: UserExport?
    let meals: [MealExport]
    let recipes: [RecipeExport]
    let streak: StreakExport?
    let achievements: [AchievementExport]
}

struct UserExport: Codable, Equatable {
    let remoteID: String
    let email: String?
    let displayName: String?
    let provider: String
    let locale: String
    let timeZone: String
    let createdAt: Date
    let onboardingCompletedAt: Date?
    let birthDate: Date?
    let heightCm: Int?
    let weightKg: Double?
    let biologicalSex: String
    let activityLevel: String
    let goalKind: String
    let dailyCalorieGoalKcal: Int
    let proteinGoalGrams: Int
    let carbsGoalGrams: Int
    let fatGoalGrams: Int

    init(_ user: User) {
        self.remoteID = user.remoteID
        self.email = user.email
        self.displayName = user.displayName
        self.provider = user.providerKind.rawValue
        self.locale = user.locale
        self.timeZone = user.timeZoneIdentifier
        self.createdAt = user.createdAt
        self.onboardingCompletedAt = user.onboardingCompletedAt
        self.birthDate = user.birthDate
        self.heightCm = user.heightCm
        self.weightKg = user.weightKg
        self.biologicalSex = user.biologicalSex.rawValue
        self.activityLevel = user.activityLevel.rawValue
        self.goalKind = user.goalKind.rawValue
        self.dailyCalorieGoalKcal = user.dailyCalorieGoalKcal
        self.proteinGoalGrams = user.proteinGoalGrams
        self.carbsGoalGrams = user.carbsGoalGrams
        self.fatGoalGrams = user.fatGoalGrams
    }
}

struct MealExport: Codable, Equatable {
    let consumedAt: Date
    let mealType: String
    let source: String
    let portionMultiplier: Double
    let notes: String?
    let items: [MealItemExport]

    init(_ entry: MealEntry) {
        self.consumedAt = entry.consumedAt
        self.mealType = entry.mealType.rawValue
        self.source = entry.source.rawValue
        self.portionMultiplier = entry.portionMultiplier
        self.notes = entry.notes
        self.items = entry.items.map(MealItemExport.init)
    }
}

struct MealItemExport: Codable, Equatable {
    let name: String
    let quantityGrams: Double
    let caloriesKcal: Double
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
    let confidence: Double?

    init(_ item: FoodItem) {
        self.name = item.name
        self.quantityGrams = item.quantityGrams
        self.caloriesKcal = item.caloriesKcal
        self.proteinGrams = item.proteinGrams
        self.carbsGrams = item.carbsGrams
        self.fatGrams = item.fatGrams
        self.confidence = item.confidence
    }
}

struct RecipeExport: Codable, Equatable {
    let title: String
    let sourceURL: String?
    let servings: Int
    let instructions: [String]
    let modifications: [String]
    let cookCount: Int
    let createdAt: Date

    init(_ recipe: Recipe) {
        self.title = recipe.title
        self.sourceURL = recipe.sourceURL?.absoluteString
        self.servings = recipe.servings
        self.instructions = recipe.instructions
        self.modifications = recipe.modifications
        self.cookCount = recipe.cookCount
        self.createdAt = recipe.createdAt
    }
}

struct StreakExport: Codable, Equatable {
    let currentLength: Int
    let longestLength: Int
    let lastLoggedDate: Date?
    let freezesAvailable: Int

    init(_ streak: Streak) {
        self.currentLength = streak.currentLength
        self.longestLength = streak.longestLength
        self.lastLoggedDate = streak.lastLoggedDate
        self.freezesAvailable = streak.freezesAvailable
    }
}

struct AchievementExport: Codable, Equatable {
    let kind: String
    let earnedAt: Date
    let title: String
    let details: String

    init(_ achievement: Achievement) {
        self.kind = achievement.kind
        self.earnedAt = achievement.earnedAt
        self.title = achievement.title
        self.details = achievement.details
    }
}
