import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Renders a Mealgram friend-add deep link (`mealgram://friend/<id>`) into
/// a UIImage QR code. Pure helper; the renderer doesn't reach for any
/// state.
enum QRCodeRenderer {
    /// Encodes the deep-link form of a user id. Decoder (lands with
    /// Supabase) will accept the bare id or the deep link.
    static func deepLink(forUserID userID: String) -> String {
        "mealgram://friend/\(userID)"
    }

    /// Returns a crisp UIImage rendered at `target` square px. The
    /// underlying CIImage is integer-multiplied so the bars stay aligned
    /// — passing a non-multiple of the CIImage's natural size produces
    /// scaling artifacts.
    static func image(for payload: String, side: CGFloat = 480) -> UIImage? {
        let data = Data(payload.utf8)
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scale = side / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
