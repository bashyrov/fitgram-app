import UIKit
import XCTest

@testable import Fitgram

@MainActor
final class StreakShareCardTests: XCTestCase {
    func testRenderProducesNonNilImage() {
        let image = StreakShareCard.render(streakLength: 7, longestLength: 12)
        XCTAssertNotNil(image)
    }

    func testRenderProducesPortraitSizedImage() throws {
        let image = try XCTUnwrap(
            StreakShareCard.render(streakLength: 14, longestLength: 14)
        )
        XCTAssertEqual(image.size.width, 1080, accuracy: 1)
        XCTAssertEqual(image.size.height, 1920, accuracy: 1)
    }

    func testRenderToleratesZeroLongestStreak() {
        // longest = 0 + current = 1 used to crash older renderers that
        // expected longest to be set. Smoke-test that the SwiftUI path
        // still produces a usable image.
        let image = StreakShareCard.render(streakLength: 1, longestLength: 0)
        XCTAssertNotNil(image)
    }

    func testTransparentCardKeepsAlphaInPNG() throws {
        let image = try XCTUnwrap(StreakShareCard.render(streakLength: 3, longestLength: 5, background: .transparent))
        let data = try XCTUnwrap(ShareCardImage(image: image).pngData)
        let cgImage = try XCTUnwrap(UIImage(data: data)?.cgImage)
        XCTAssertTrue([.first, .last, .premultipliedFirst, .premultipliedLast].contains(cgImage.alphaInfo))
        // Top-left corner is outside every element, so it must be fully clear.
        let context = try XCTUnwrap(
            CGContext(
                data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.draw(
            cgImage,
            in: CGRect(
                x: 0, y: -CGFloat(cgImage.height) + 1, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
        let alpha = try XCTUnwrap(context.data?.load(fromByteOffset: 3, as: UInt8.self))
        XCTAssertEqual(alpha, 0)
    }
}
