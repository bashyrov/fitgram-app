import Foundation
import OSLog

/// One-tap export of everything Mealgram has on the user: the JSON
/// bundle, the CSV meal log, and the meal photos directory — all
/// packed into a single ZIP via NSFileCoordinator's `.forUploading`
/// option (the Apple-blessed way to create a multi-entry archive in
/// pure Foundation without dragging in a third-party zip lib).
@MainActor
final class DataBundleExportService {
    private let jsonService: DataExportService
    private let csvService: MealCSVExportService
    private let photoDirectory: URL?

    init(
        jsonService: DataExportService,
        csvService: MealCSVExportService,
        photoDirectory: URL? = nil
    ) {
        self.jsonService = jsonService
        self.csvService = csvService
        self.photoDirectory = photoDirectory
    }

    /// Materialises the export under `tmp/bundles/mealgram-bundle-<ts>/`,
    /// then asks NSFileCoordinator to hand back a ZIP'd version that
    /// callers can drop into a ShareLink. The temp directory hangs
    /// around — tmp cleans up itself.
    func export(forUser userRemoteID: String) throws -> URL {
        let tempRoot = FileManager.default.temporaryDirectory
            .appending(path: "bundles", directoryHint: .isDirectory)
        let stamp = Self.fileTimestamp.string(from: Date())
        let bundleDir = tempRoot.appending(path: "mealgram-bundle-\(stamp)", directoryHint: .isDirectory)

        try FileManager.default.createDirectory(at: bundleDir, withIntermediateDirectories: true)

        let jsonURL = try jsonService.export(for: userRemoteID)
        try FileManager.default.copyItem(at: jsonURL, to: bundleDir.appending(path: "data.json"))

        let csvURL = try csvService.export()
        try FileManager.default.copyItem(at: csvURL, to: bundleDir.appending(path: "meals.csv"))

        if let photoDirectory, FileManager.default.fileExists(atPath: photoDirectory.path) {
            let target = bundleDir.appending(path: "photos", directoryHint: .isDirectory)
            try? FileManager.default.copyItem(at: photoDirectory, to: target)
        }

        return try zipDirectory(bundleDir)
    }

    /// Uses NSFileCoordinator's forUploading flag — the documented way
    /// to produce a temp `.zip` of a directory in pure Foundation. The
    /// coordinator's callback fires synchronously for local URLs, so
    /// we copy the temp ZIP into our exports dir before returning.
    private func zipDirectory(_ directory: URL) throws -> URL {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var resultURL: URL?
        var copyError: Error?

        coordinator.coordinate(
            readingItemAt: directory,
            options: [.forUploading],
            error: &coordinationError
        ) { zipURL in
            do {
                let exportsDir = FileManager.default.temporaryDirectory
                    .appending(path: "exports", directoryHint: .isDirectory)
                try FileManager.default.createDirectory(
                    at: exportsDir,
                    withIntermediateDirectories: true
                )
                let finalURL = exportsDir.appending(
                    path: "\(directory.lastPathComponent).zip"
                )
                try? FileManager.default.removeItem(at: finalURL)
                try FileManager.default.copyItem(at: zipURL, to: finalURL)
                resultURL = finalURL
            } catch {
                copyError = error
            }
        }

        if let coordinationError {
            throw coordinationError
        }
        if let copyError {
            throw copyError
        }
        guard let resultURL else {
            throw BundleError.zipFailed
        }
        Logger.persistence.notice(
            "Wrote bundle zip \(resultURL.lastPathComponent, privacy: .public)"
        )
        return resultURL
    }

    enum BundleError: Error, Equatable {
        case zipFailed
    }

    private static var fileTimestamp: DateFormatter {

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    
}
}
