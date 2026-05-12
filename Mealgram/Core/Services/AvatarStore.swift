import Foundation
import OSLog
import UIKit

/// Persists user avatar images on disk. Files live under
/// `Documents/avatars/<filename>.jpg` so the SwiftData model only carries
/// a short filename and the binary payload stays out of the store.
struct AvatarStore: Sendable {
    enum AvatarError: Error, Equatable {
        case encodingFailed
        case writeFailed
    }

    let directory: URL

    init() {
        let documents =
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.directory = documents.appending(path: "avatars", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Compresses + writes the supplied image. Old avatar file (if any) is
    /// deleted in the same call so the directory doesn't accumulate
    /// orphans. Returns the new filename suitable for User.avatarFilename.
    @discardableResult
    func save(_ image: UIImage, previous: String?) throws -> String {
        let resized = Self.resize(image, maxDimension: 512)
        guard let data = resized.jpegData(compressionQuality: 0.85) else {
            throw AvatarError.encodingFailed
        }
        if let previous {
            try? FileManager.default.removeItem(at: directory.appending(path: previous))
        }
        let filename = "avatar-\(UUID().uuidString).jpg"
        do {
            try data.write(to: directory.appending(path: filename), options: [.atomic])
        } catch {
            Logger.persistence.error("Avatar write failed: \(String(describing: error))")
            throw AvatarError.writeFailed
        }
        return filename
    }

    func load(_ filename: String) -> UIImage? {
        let url = directory.appending(path: filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func remove(_ filename: String?) {
        guard let filename else { return }
        try? FileManager.default.removeItem(at: directory.appending(path: filename))
    }

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        // Force a 1x render so the resulting UIImage's .size matches the
        // on-disk JPEG pixel dimensions (JPEG can't carry a scale factor).
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
