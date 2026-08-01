import Foundation
import OSLog
import Observation

@MainActor
@Observable
final class WeightLogState {
    private(set) var entries: [WeightEntry] = []
    private(set) var summary: WeightService.Summary?
    private(set) var isLoading = false
    var errorMessage: String?

    private let service: WeightService

    init(service: WeightService) {
        self.service = service
    }

    func refresh(for userRemoteID: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            summary = try service.summary(for: userRemoteID)
            entries = summary?.entries ?? []
        } catch {
            Logger.persistence.error("Weight refresh failed: \(String(describing: error))")
            entries = []
            summary = nil
        }
    }

    func log(_ weightKg: Double, for userRemoteID: String, note: String?) async {
        do {
            try service.log(weightKg, for: userRemoteID, note: note)
        } catch {
            Logger.persistence.error("Weight log failed: \(String(describing: error))")
            errorMessage = L("Couldn't save. Try again.")
        }
        await refresh(for: userRemoteID)
    }

    func delete(_ entry: WeightEntry, for userRemoteID: String) async {
        do {
            try service.delete(entry)
        } catch {
            Logger.persistence.error("Weight delete failed: \(String(describing: error))")
            errorMessage = L("Couldn't save. Try again.")
        }
        await refresh(for: userRemoteID)
    }

    func update(_ entry: WeightEntry, weightKg: Double, note: String?, for userRemoteID: String) async {
        do {
            try service.update(entry, weightKg: weightKg, note: note)
        } catch {
            Logger.persistence.error("Weight update failed: \(String(describing: error))")
            errorMessage = L("Couldn't save. Try again.")
        }
        await refresh(for: userRemoteID)
    }
}
