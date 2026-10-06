import DopaBreakCore
import UIKit
import XCTest

final class BundledFontIntegrationTests: XCTestCase {
    private let expectedNames = Set(DopaBreakBundledFont.allCases.map(\.rawValue))

    func testWidgetExtensionContainsAndAppProcessRegistersAllFourThemeFonts() throws {
        let fontURLs = try widgetExtensionBundledFontURLs()

        XCTAssertEqual(fontURLs.count, 4)
        XCTAssertEqual(
            DopaBreakFontRegistrar.registerBundledFonts(),
            expectedNames
        )

        for font in DopaBreakBundledFont.allCases {
            let name = try XCTUnwrap(DopaBreakFontRegistrar.registeredName(for: font))
            XCTAssertEqual(name, font.rawValue)
            XCTAssertNotNil(UIFont(name: name, size: 17), "UIFont could not resolve \(name)")
        }
    }

    func testFontsExistOnlyInWidgetExtensionWithinApprovedLimit() throws {
        let fontURLs = try widgetExtensionBundledFontURLs()
        let allFontURLs = FileManager.default.enumerator(
            at: Bundle.main.bundleURL,
            includingPropertiesForKeys: nil
        )?.compactMap { $0 as? URL }.filter { $0.pathExtension == "ttf" } ?? []

        XCTAssertEqual(Set(allFontURLs), Set(fontURLs), "Fonts must exist only once in the app payload")
        for font in DopaBreakBundledFont.allCases {
            let appRootURL = Bundle.main.bundleURL
                .appendingPathComponent("\(fileStem(for: font)).ttf")
            XCTAssertFalse(
                FileManager.default.fileExists(atPath: appRootURL.path),
                "\(appRootURL.lastPathComponent) must not exist at the DopaBreak.app root"
            )
        }
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

    private func widgetExtensionBundledFontURLs() throws -> [URL] {
        let extensionURL = Bundle.main.bundleURL
            .appendingPathComponent("PlugIns", isDirectory: true)
            .appendingPathComponent("WidgetsExtension.appex", isDirectory: true)
        return try DopaBreakBundledFont.allCases.map { font in
            let fontURL = extensionURL.appendingPathComponent("\(fileStem(for: font)).ttf")
            return try XCTUnwrap(
                FileManager.default.fileExists(atPath: fontURL.path) ? fontURL : nil,
                "Missing \(fontURL.lastPathComponent) from \(extensionURL.path)"
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
