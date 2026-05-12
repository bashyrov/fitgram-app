import Foundation
import OSLog
import UIKit

/// Writes scan photos to the app's Documents directory under
/// `MealPhotos/`. We store JPEG (quality 0.85) rather than HEIC so the
/// CoreData blob → file migration in Phase 4 has fewer codec quirks to
/// worry about. Files are keyed by the UUID we hand back, which the
/// caller stores on `MealEntry.photoFilename`.
///
/// Photos never leave the device today; once Supabase ships, the upload
/// path reads from this directory.
@MainActor
final class MealPhotoStore {
    enum StoreError: Error, Equatable {
        case encodingFailed
        case writeFailed(String)
        case directoryUnavailable
    }

    private let directory: URL
    private let fileManager: FileManager
    private let compressionQuality: CGFloat = 0.85

    init(fileManager: FileManager = .default, directoryName: String = "MealPhotos") throws {
        self.fileManager = fileManager
        let documents = try fileManager.url(
            for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        let folder = documents.appendingPathComponent(directoryName, isDirectory: true)
        if !fileManager.fileExists(atPath: folder.path) {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        self.directory = folder
    }

    /// Persists a JPEG and returns the filename to store on the meal.
    /// Filename is a fresh UUID so two saves never collide.
    @discardableResult
    func save(imageData: Data) throws -> String {
        guard let uiImage = UIImage(data: imageData) else { throw StoreError.encodingFailed }
        guard let jpeg = uiImage.jpegData(compressionQuality: compressionQuality) else {
            throw StoreError.encodingFailed
        }
        let filename = "\(UUID().uuidString).jpg"
        let url = directory.appendingPathComponent(filename)
        do {
            try jpeg.write(to: url, options: .atomic)
        } catch {
            throw StoreError.writeFailed(String(describing: error))
        }
        Logger.persistence.notice("Saved meal photo \(filename, privacy: .public)")
        return filename
    }

    /// Loads a previously saved photo. Returns nil if the file is missing
    /// (e.g. user wiped storage manually) — callers should fall back to a
    /// placeholder rather than crashing.
    func image(forFilename filename: String) -> UIImage? {
        let url = directory.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    /// Best-effort delete. Missing-file is not an error — the caller may
    /// be racing the undo banner.
    func delete(filename: String) {
        let url = directory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: url)
    }

    /// Test hook — number of files currently in the directory.
    func fileCount() -> Int {
        let contents = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return contents.count
    }
}
