import CoreTransferable
import OSLog
import Photos
import SwiftUI
import UniformTypeIdentifiers

/// A rendered share card handed out as PNG. Passing a SwiftUI `Image` to
/// ShareLink or `UIImageWriteToSavedPhotosAlbum` re-encoded it as JPEG,
/// which has no alpha — the "transparent" card arrived with a dark box.
struct ShareCardImage: Transferable {
    let image: UIImage
    var fileName = "fitgram-streak"

    var pngData: Data? { image.pngData() }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { card in
            guard let data = card.pngData else { throw CocoaError(.fileWriteUnknown) }
            return data
        }
        .suggestedFileName { "\($0.fileName).png" }
    }

    /// Saves the PNG bytes as-is so Photos keeps the transparency.
    func saveToPhotos() async -> Bool {
        guard let data = pngData else { return false }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.uniformTypeIdentifier = UTType.png.identifier
                options.originalFilename = "\(fileName).png"
                request.addResource(with: .photo, data: data, options: options)
            }
            return true
        } catch {
            Logger.ui.error("Share card save failed: \(String(describing: error))")
            return false
        }
    }
}
