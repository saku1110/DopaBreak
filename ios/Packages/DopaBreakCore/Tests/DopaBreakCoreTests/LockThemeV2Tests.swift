import XCTest
@testable import DopaBreakCore

final class LockThemeV2Tests: XCTestCase {
    func testAllCasesAreExactlyTheTenV2Themes() {
        XCTAssertEqual(
            LockTheme.allCases,
            [.e1, .gaming, .asagiri, .monochrome, .liquidGlass, .kpop, .kawaiiPink, .note, .blueprint, .retroPop]
        )
        XCTAssertEqual(LockTheme.allCases.count, 10)
        XCTAssertNil(LockTheme(rawValue: "sumi"))
        XCTAssertNil(LockTheme(rawValue: "shinrin"))
        XCTAssertNil(LockTheme(rawValue: "yozora"))
    }

    func testLegacyAndUnknownRawValuesMigrateExplicitly() {
        XCTAssertEqual(LockTheme(migratingRawValue: "sumi"), .gaming)
        XCTAssertEqual(LockTheme(migratingRawValue: "shinrin"), .monochrome)
        XCTAssertEqual(LockTheme(migratingRawValue: "yozora"), .liquidGlass)
        XCTAssertEqual(LockTheme(migratingRawValue: "future-theme"), .e1)
    }

    func testSettingsReadMigratesAndPersistsNewRawValues() {
        let mappings: [(String, LockTheme)] = [
            ("sumi", .gaming), ("shinrin", .monochrome), ("yozora", .liquidGlass)
        ]
        for (legacy, expected) in mappings {
            let suite = "LockThemeV2Tests.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            defaults.set(legacy, forKey: "lockThemeRawValue")
            let store = SettingsStore(userDefaults: defaults)

            XCTAssertEqual(store.lockTheme, expected)
            XCTAssertEqual(store.lockThemeRawValue, legacy, "A getter must not mutate UserDefaults")
            store.migrateStoredValues()
            XCTAssertEqual(store.lockThemeRawValue, expected.rawValue)
            XCTAssertEqual(SettingsStore(userDefaults: defaults).lockTheme, expected)
        }
    }

    func testUnknownSettingsValueNormalizesToDefault() {
        let suite = "LockThemeV2Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("future-theme", forKey: "lockThemeRawValue")

        let store = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(store.lockTheme, .e1)
        XCTAssertEqual(store.lockThemeRawValue, "future-theme", "A getter must not mutate UserDefaults")
        store.migrateStoredValues()
        XCTAssertNil(store.lockThemeRawValue)
    }

    func testStoredDefaultLiteralNormalizesLikeTheSetter() {
        let suite = "LockThemeV2Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(LockTheme.e1.rawValue, forKey: "lockThemeRawValue")

        let store = SettingsStore(userDefaults: defaults)
        store.migrateStoredValues()

        XCTAssertNil(store.lockThemeRawValue)
    }

    func testEveryThemeProvidesTheApprovedPalette() {
        let expected: [LockTheme: LockThemePalette] = [
            .e1: .init(background: .init(11, 13, 15), card: .init(20, 23, 27), primaryText: .init(244, 242, 236), secondaryText: .init(139, 146, 158), accent: .init(184, 255, 61)),
            .gaming: .init(background: .init(10, 10, 20), card: .init(20, 20, 40), primaryText: .init(234, 234, 242), secondaryText: .init(138, 143, 168), accent: .init(0, 229, 255)),
            .asagiri: .init(background: .init(232, 237, 242), card: .init(250, 251, 252), primaryText: .init(31, 37, 47), secondaryText: .init(91, 105, 119), accent: .init(91, 126, 153)),
            .monochrome: .init(background: .init(250, 250, 250), card: .init(255, 255, 255), primaryText: .init(18, 18, 18), secondaryText: .init(118, 118, 118), accent: .init(18, 18, 18)),
            .liquidGlass: .init(background: .init(62, 91, 200), card: .init(90, 111, 216), primaryText: .init(255, 255, 255), secondaryText: .init(216, 222, 245), accent: .init(255, 255, 255)),
            .kpop: .init(background: .init(225, 205, 247), card: .init(249, 246, 251), primaryText: .init(35, 31, 38), secondaryText: .init(104, 94, 108), accent: .init(238, 52, 137)),
            .kawaiiPink: .init(background: .init(255, 220, 229), card: .init(255, 253, 253), primaryText: .init(68, 43, 49), secondaryText: .init(139, 91, 102), accent: .init(242, 94, 137)),
            .note: .init(background: .init(251, 247, 239), card: .init(255, 255, 255), primaryText: .init(59, 52, 40), secondaryText: .init(138, 128, 112), accent: .init(199, 80, 80)),
            .blueprint: .init(background: .init(22, 65, 138), card: .init(27, 76, 158), primaryText: .init(255, 255, 255), secondaryText: .init(185, 203, 232), accent: .init(255, 255, 255)),
            .retroPop: .init(background: .init(245, 233, 214), card: .init(255, 255, 255), primaryText: .init(74, 51, 32), secondaryText: .init(107, 74, 50), accent: .init(232, 99, 43))
        ]

        XCTAssertEqual(expected.count, LockTheme.allCases.count)
        for theme in LockTheme.allCases {
            XCTAssertEqual(theme.palette, expected[theme], "Unexpected palette for \(theme)")
        }
    }

    func testCurrentWidgetStateRawValuesRoundTrip() {
        for theme in LockTheme.allCases {
            XCTAssertEqual(LockTheme(migratingRawValue: theme.rawValue), theme)
        }
    }

    func testBundledFontDefinitionsContainAllThemePostScriptNames() {
        XCTAssertEqual(
            Set(DopaBreakBundledFont.allCases.map(\.rawValue)),
            ["DotGothic16-Regular", "ZenKurenaido-Regular", "Galmuri11-Regular", "NanumPen-Regular"]
        )
    }
}
