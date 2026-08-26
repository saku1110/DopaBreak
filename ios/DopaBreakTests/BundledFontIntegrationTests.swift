import DopaBreakCore
import UIKit
import XCTest

final class BundledFontIntegrationTests: XCTestCase {
    private let expectedNames = Set(DopaBreakBundledFont.allCases.map(\.rawValue))

    func testAppBundleContainsAndRegistersAllFourThemeFonts() throws {
        let fontURLs = try appBundledFontURLs()

        XCTAssertEqual(fontURLs.count, 4)
        XCTAssertEqual(
            DopaBreakFontRegistrar.registerBundledFonts(resourceBundleURL: Bundle.main.bundleURL),
            expectedNames
        )

        for name in expectedNames {
            XCTAssertNotNil(UIFont(name: name, size: 17), "UIFont could not resolve \(name)")
        }
    }

    func testAppBundleContainsOnlyOneFontPayloadWithinApprovedLimit() throws {
        let fontURLs = try appBundledFontURLs()
        let allFontURLs = FileManager.default.enumerator(
            at: Bundle.main.bundleURL,
            includingPropertiesForKeys: nil
        )?.compactMap { $0 as? URL }.filter { $0.pathExtension == "ttf" } ?? []

        XCTAssertEqual(Set(allFontURLs), Set(fontURLs), "Fonts must exist only once in the app payload")
        let byteCount = try fontURLs.reduce(Int64.zero) { total, url in
            total + Int64(try XCTUnwrap(url.resourceValues(forKeys: [.fileSizeKey]).fileSize))
        }
        XCTAssertLessThanOrEqual(byteCount, 14_994_637) // 14.3 MiB
    }

    func testExplicitMissingFontPayloadCannotBeHiddenByFallbackOrEarlierRegistration() throws {
        let emptyDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: emptyDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: emptyDirectory) }

        XCTAssertEqual(
            DopaBreakFontRegistrar.registerBundledFonts(resourceBundleURL: emptyDirectory),
            [],
            "An explicit resource scope with no fonts must never report registration success"
        )
    }

    private func appBundledFontURLs() throws -> [URL] {
        try DopaBreakBundledFont.allCases.map { font in
            try XCTUnwrap(
                Bundle.main.url(forResource: fileStem(for: font), withExtension: "ttf"),
                "Missing \(fileStem(for: font)).ttf from \(Bundle.main.bundleURL.path)"
            )
        }
    }

    private func fileStem(for font: DopaBreakBundledFont) -> String {
        switch font {
        case .dotGothic16: "DotGothic16"
        case .zenKurenaido: "ZenKurenaido"
        case .galmuri11: "Galmuri11"
        case .nanumPenScript: "NanumPenScript"
        }
    }
}
