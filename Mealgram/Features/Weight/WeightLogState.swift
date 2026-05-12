import Foundation
import OSLog
import Observation

@MainActor
@Observable
final class WeightLogState {
    private(set) var entries: [WeightEntry] = []
    private(set) var summary: WeightService.Summary?
    private(set) var isLoading = false

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
        try? service.log(weightKg, for: userRemoteID, note: note)
        await refresh(for: userRemoteID)
    }

    func delete(_ entry: WeightEntry, for userRemoteID: String) async {
        try? service.delete(entry)
        await refresh(for: userRemoteID)
    }
}
