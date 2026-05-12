import XCTest

@testable import Mealgram

@MainActor
final class MealPhotoStoreTests: XCTestCase {
    private var directoryName: String!

    override func setUp() async throws {
        directoryName = "TestMealPhotos-\(UUID().uuidString)"
    }

    override func tearDown() async throws {
        // Wipe the test directory.
        let documents = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false
        )
        let folder = documents.appendingPathComponent(directoryName, isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
    }

    private func pngData(width: Int = 8, height: Int = 8) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let image = renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.pngData() ?? Data()
    }

    func testSaveProducesUniqueJPEGFilename() throws {
        let store = try MealPhotoStore(directoryName: directoryName)
        let one = try store.save(imageData: pngData())
        let two = try store.save(imageData: pngData())
        XCTAssertNotEqual(one, two)
        XCTAssertTrue(one.hasSuffix(".jpg"))
        XCTAssertEqual(store.fileCount(), 2)
    }

    func testImageRoundTrip() throws {
        let store = try MealPhotoStore(directoryName: directoryName)
        let filename = try store.save(imageData: pngData())
        let loaded = store.image(forFilename: filename)
        XCTAssertNotNil(loaded)
    }

    func testImageForUnknownFilenameReturnsNil() throws {
        let store = try MealPhotoStore(directoryName: directoryName)
        XCTAssertNil(store.image(forFilename: "nope.jpg"))
    }

    func testSaveRejectsNonImageData() throws {
        let store = try MealPhotoStore(directoryName: directoryName)
        XCTAssertThrowsError(try store.save(imageData: Data("not an image".utf8))) { error in
            XCTAssertEqual(error as? MealPhotoStore.StoreError, .encodingFailed)
        }
    }

    func testDeleteRemovesFile() throws {
        let store = try MealPhotoStore(directoryName: directoryName)
        let filename = try store.save(imageData: pngData())
        XCTAssertEqual(store.fileCount(), 1)
        store.delete(filename: filename)
        XCTAssertEqual(store.fileCount(), 0)
    }

    func testDeleteMissingIsNoOp() throws {
        let store = try MealPhotoStore(directoryName: directoryName)
        XCTAssertNoThrow(store.delete(filename: "ghost.jpg"))
    }
}
