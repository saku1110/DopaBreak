import Foundation
import XCTest
@testable import DopaBreakCore

final class InterventionTargetStoreTests: XCTestCase {
    func testDefaultSelectionIsEmpty() throws {
        let store = try makeStore()

        XCTAssertEqual(try store.selectedCatalogIDs(), [])
        XCTAssertEqual(try store.selectedTargets(), [])
    }

    func testSaveLoadAndOrdering() throws {
        let store = try makeStore()

        try store.setTargets(["youtube", "instagram", "safari"])

        XCTAssertEqual(try store.selectedCatalogIDs(), ["youtube", "instagram", "safari"])
        XCTAssertEqual(try store.selectedTargets().map(\.displayName), ["YouTube", "Instagram", "Safari"])
    }

    func testPersistsAcrossInstances() throws {
        let containerURL = try makeTemporaryDirectory()
        let provider = FixedContainer(url: containerURL)
        let first = InterventionTargetStore(snapshotStore: JSONSnapshotStore(containerProvider: provider))
        try first.setTargets(["x", "line"])

        let second = InterventionTargetStore(snapshotStore: JSONSnapshotStore(containerProvider: provider))

        XCTAssertEqual(try second.selectedCatalogIDs(), ["x", "line"])
    }

    func testUnknownIDThrowsValidation() throws {
        let store = try makeStore()

        XCTAssertValidationError(try store.setTargets(["instagram", "unknown"]))
    }

    func testDuplicateIDThrowsValidation() throws {
        let store = try makeStore()

        XCTAssertValidationError(try store.setTargets(["instagram", "instagram"]))
    }

    private func makeStore() throws -> InterventionTargetStore {
        InterventionTargetStore(
            snapshotStore: JSONSnapshotStore(containerProvider: FixedContainer(url: try makeTemporaryDirectory()))
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("InterventionTargetStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func XCTAssertValidationError(
        _ expression: @autoclosure () throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            guard case CoreError.validation = error else {
                return XCTFail("Expected validation error, got \(error)", file: file, line: line)
            }
        }
    }
}
