import XCTest
import StoreKit
import StoreKitTest
import DopaBreakCore

@testable import DopaBreak

final class PaywallCTAZeroPriceTests: XCTestCase {
    func testZeroPriceCTAIsBuiltOnlyForThePaywall() {
        // オンボーディング用の「◯日間 ¥0 で始める」は2026-09-27に廃止。ゼロ価格の文言はペイウォールのボタンだけ。
        XCTAssertEqual(IntroOfferDisplayPolicy.ctaText(durationText: "2週間", zeroPriceText: "¥0"), "2週間 ¥0で始める")
        XCTAssertNil(IntroOfferDisplayPolicy.ctaText(durationText: nil, zeroPriceText: "¥0"))
    }

    func testAnnualIntroFallbacksContainNoDurationInEveryLanguage() throws {
        for language in ["ja", "en", "ko"] {
            let bundle = try XCTUnwrap(Bundle(path: XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))))
            for key in ["paywall.plan.annual.intro_duration_fallback", "paywall.plan.annual.intro_fallback"] {
                let text = bundle.localizedString(forKey: key, value: nil, table: nil)
                XCTAssertNotEqual(text, key)
                XCTAssertNil(text.rangeOfCharacter(from: .decimalDigits))
                XCTAssertFalse(text.isEmpty)
            }
        }
    }

    @MainActor
    func testFailedAndEmptyProductsDisablePurchaseAndReloadRecovers() async throws {
        let config = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("DopaBreak/DopaBreak.storekit")
        let session = try SKTestSession(contentsOf: config)
        session.disableDialogs = true
        defer { session.resetToDefaultState() }
        let products = try await Product.products(for: ProProductID.saleSubscriptionIDs)
        XCTAssertEqual(products.count, 2)
        var attempt = 0
        let suite = "PaywallLoad.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = StoreService(settingsStore: SettingsStore(userDefaults: defaults), startsBackgroundTasks: false,
                                 productLoader: {
            attempt += 1
            if attempt == 1 { throw URLError(.notConnectedToInternet) }
            return attempt == 2 ? [] : products
        })
        XCTAssertEqual(store.productLoadingState, .loading)
        XCTAssertFalse(store.canPurchase(products.first))
        await store.loadProducts()
        XCTAssertEqual(store.productLoadingState, .failed)
        XCTAssertFalse(store.canPurchase(products.first))
        await store.loadProducts()
        XCTAssertEqual(store.productLoadingState, .failed)
        XCTAssertFalse(store.canPurchase(nil))
        await store.loadProducts()
        XCTAssertEqual(store.productLoadingState, .loaded)
        XCTAssertTrue(store.canPurchase(store.activeAnnualProduct))
        XCTAssertTrue(store.canPurchase(store.monthlyProduct))
    }

    func testCTAUsesDurationAndZeroPriceWhenBothAreAvailable() {
        let text = IntroOfferDisplayPolicy.ctaText(
            durationText: "7日間",
            zeroPriceText: "¥0"
        )

        XCTAssertEqual(text, "7日間 ¥0で始める")
        XCTAssertTrue(text?.contains("7日間") == true, text ?? "nil")
        XCTAssertTrue(text?.contains("¥0") == true, text ?? "nil")
    }

    func testCTAReturnsNilForUnusableZeroPrice() {
        for zeroPrice in [nil, "", "   ", "¥"] as [String?] {
            XCTAssertNil(
                IntroOfferDisplayPolicy.ctaText(
                    durationText: "7日間",
                    zeroPriceText: zeroPrice
                )
            )
        }
    }

    func testCTAReturnsNilWithoutDuration() {
        XCTAssertNil(
            IntroOfferDisplayPolicy.ctaText(
                durationText: nil,
                zeroPriceText: "¥0"
            )
        )
    }

    func testCatalogHasTranslatedPositionalArgumentsInEveryLanguage() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("DopaBreak/Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let catalog = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
        let entry = try XCTUnwrap(
            strings["paywall.action.start_zero_price"] as? [String: Any]
        )
        let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any])

        for language in ["ja", "en", "ko"] {
            let localization = try XCTUnwrap(
                localizations[language] as? [String: Any],
                "\(language): localization is missing"
            )
            let stringUnit = try XCTUnwrap(
                localization["stringUnit"] as? [String: Any],
                "\(language): stringUnit is missing"
            )
            XCTAssertEqual(stringUnit["state"] as? String, "translated", language)
            let value = try XCTUnwrap(stringUnit["value"] as? String, language)
            XCTAssertTrue(value.contains("%1$@"), "\(language): %1$@ is missing")
            XCTAssertTrue(value.contains("%2$@"), "\(language): %2$@ is missing")
        }
    }
}
