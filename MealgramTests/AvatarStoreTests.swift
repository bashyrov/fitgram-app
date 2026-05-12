import UIKit
import XCTest

@testable import Mealgram

final class AvatarStoreTests: XCTestCase {
    func testSaveProducesFilenameThatLoads() throws {
        let store = AvatarStore()
        let image = Self.makeImage(color: .red, size: CGSize(width: 100, height: 100))
        let filename = try store.save(image, previous: nil)
        defer { store.remove(filename) }
        let loaded = store.load(filename)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.size.width.isFinite, true)
    }

    func testSaveDeletesPreviousAvatar() throws {
        let store = AvatarStore()
        let first = try store.save(Self.makeImage(color: .red), previous: nil)
        let second = try store.save(Self.makeImage(color: .blue), previous: first)
        XCTAssertNil(store.load(first), "previous avatar should have been removed")
        XCTAssertNotNil(store.load(second))
        store.remove(second)
    }

    func testResizingClampsLargeImagesToMaxDimension() throws {
        let store = AvatarStore()
        let huge = Self.makeImage(color: .green, size: CGSize(width: 2048, height: 1024))
        let filename = try store.save(huge, previous: nil)
        defer { store.remove(filename) }
        let loaded = try XCTUnwrap(store.load(filename))
        XCTAssertLessThanOrEqual(max(loaded.size.width, loaded.size.height), 512)
    }

    func testRemoveTolerantOfMissingFile() {
        let store = AvatarStore()
        store.remove("never-existed.jpg")
        store.remove(nil)
        // No assertion needed — should not throw.
    }

    private static func makeImage(color: UIColor, size: CGSize = CGSize(width: 32, height: 32)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
