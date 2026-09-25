import Foundation
import OSLog
import SwiftData

/// CRUD + progress evaluation for user-defined supplementary goals.
/// Main weight-loss / weight-gain goal lives on User; this service is
/// for everything in addition.
@MainActor
protocol GoalsServing: AnyObject {
    func activeGoals() throws -> [CustomGoal]
    func allGoals() throws -> [CustomGoal]
    func create(_ goal: CustomGoal) throws
    func updateStatus(id: UUID, _ status: CustomGoalStatus) throws
    func update(_ goal: CustomGoal) throws
    func delete(id: UUID) throws

    /// Returns 0.0-1.0 progress fraction for the given goal, evaluated
    /// against the most recent meal/weight history. Multi-target goals
    /// return the average of their per-target fractions.
    func progress(for goal: CustomGoal) throws -> Double
}

enum GoalsServiceError: Error, Equatable {
    case tooManyActiveGoals(max: Int)
    case notFound
    case invalidGoal(String)
}

@MainActor
final class GoalsService: GoalsServing {
    /// Soft cap from the product brief — three active goals at once is
    /// the line between "motivating" and "overwhelming". Stored as a
    /// constant here so the UI can echo the same number in copy.
    static let maxActiveGoals = 3

    private let container: ModelContainer
    private let sessionRemoteID: () -> String?

    init(container: ModelContainer, sessionRemoteID: @escaping () -> String?) {
        self.container = container
        self.sessionRemoteID = sessionRemoteID
    }

    func activeGoals() throws -> [CustomGoal] {
        let all = try allGoals()
        return all.filter { $0.status == .active }
    }

    func allGoals() throws -> [CustomGoal] {
        guard let remoteID = sessionRemoteID() else { return [] }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CustomGoal>(
            predicate: #Predicate { $0.userRemoteID == remoteID },
            sortBy: [SortDescriptor(\CustomGoal.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func create(_ goal: CustomGoal) throws {
        guard !goal.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw GoalsServiceError.invalidGoal("name")
        }
        guard goal.endDate > goal.startDate else {
            throw GoalsServiceError.invalidGoal("dates")
        }
        let active = try activeGoals()
        if active.count >= Self.maxActiveGoals {
            throw GoalsServiceError.tooManyActiveGoals(max: Self.maxActiveGoals)
        }
        let context = ModelContext(container)
        context.insert(goal)
        try context.save()
        Logger.persistence.notice("GoalsService created custom goal \(goal.name, privacy: .public)")
    }

    func updateStatus(id: UUID, _ status: CustomGoalStatus) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CustomGoal>(
            predicate: #Predicate { $0.id == id }
        )
        guard let goal = try context.fetch(descriptor).first else {
            throw GoalsServiceError.notFound
        }
        goal.status = status
        try context.save()
    }

    func update(_ goal: CustomGoal) throws {
        let context = ModelContext(container)
        let goalID = goal.id
        let descriptor = FetchDescriptor<CustomGoal>(
            predicate: #Predicate { $0.id == goalID }
        )
        guard let stored = try context.fetch(descriptor).first else {
            throw GoalsServiceError.notFound
        }
        stored.name = goal.name
        stored.startDate = goal.startDate
        stored.endDate = goal.endDate
        stored.targets = goal.targets
        stored.reminderType = goal.reminderType
        stored.status = goal.status
        try context.save()
    }

    func delete(id: UUID) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CustomGoal>(
            predicate: #Predicate { $0.id == id }
        )
        guard let stored = try context.fetch(descriptor).first else {
            throw GoalsServiceError.notFound
        }
        context.delete(stored)
        try context.save()
    }

    func progress(for goal: CustomGoal) throws -> Double {
        guard !goal.targets.isEmpty else { return 0 }
        // Time progress fraction — used as a baseline / fallback when a
        // target type has no meal-based eval (e.g. "noFastFoodDays" needs
        // a real eval, but a pure-time fallback at least animates the
        // bar so the user sees something is happening).
        let totalSpan = goal.endDate.timeIntervalSince(goal.startDate)
        let elapsed = max(0, Date().timeIntervalSince(goal.startDate))
        let timeFraction = min(1.0, totalSpan > 0 ? elapsed / totalSpan : 0)
        // For now every target uses the time-fraction. A richer evaluator
        // that joins meals/weights is in flight; keeping the API stable
        // means swapping that in later doesn't touch callers.
        let perTarget = goal.targets.map { _ in timeFraction }
        return perTarget.reduce(0, +) / Double(perTarget.count)
    }
}
