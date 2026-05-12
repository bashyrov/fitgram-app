import UIKit
import XCTest

@testable import Mealgram

final class QRCodeRendererTests: XCTestCase {
    func testDeepLinkFormatsCorrectly() {
        let link = QRCodeRenderer.deepLink(forUserID: "abc-123")
        XCTAssertEqual(link, "mealgram://friend/abc-123")
    }

    func testImageProducesNonNilUIImage() {
        let image = QRCodeRenderer.image(for: "mealgram://friend/test-user")
        XCTAssertNotNil(image)
    }

    func testImageScalesToRequestedSide() throws {
        let image = try XCTUnwrap(
            QRCodeRenderer.image(for: "mealgram://friend/x", side: 240)
        )
        // CGImage carries native pixel dimensions; size in points should
        // hit our requested side (give or take a pixel of rounding).
        XCTAssertEqual(image.size.width, 240, accuracy: 1)
    }

    func testEmptyPayloadStillProducesImage() {
        // CIFilter accepts empty data and returns a minimal QR. Verify we
        // don't crash on the boundary case.
        XCTAssertNotNil(QRCodeRenderer.image(for: ""))
    }
}
