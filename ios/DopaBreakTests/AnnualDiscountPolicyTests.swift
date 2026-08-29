import XCTest

@testable import DopaBreak

final class AnnualDiscountPolicyTests: XCTestCase {
    func testReturnsRoundedDiscountForAvailableProductsWithValidPrices() {
        XCTAssertEqual(
            AnnualDiscountPolicy.percent(annualPrice: 5_000, monthlyPrice: 1_000),
            58
        )
    }

    func testReturnsNilWhenAnnualProductIsUnavailable() {
        XCTAssertNil(
            AnnualDiscountPolicy.percent(annualPrice: nil, monthlyPrice: 1_000)
        )
    }

    func testReturnsNilWhenMonthlyProductIsUnavailable() {
        XCTAssertNil(
            AnnualDiscountPolicy.percent(annualPrice: 5_000, monthlyPrice: nil)
        )
    }

    func testReturnsNilWhenMonthlyPriceIsZero() {
        XCTAssertNil(
            AnnualDiscountPolicy.percent(annualPrice: 5_000, monthlyPrice: 0)
        )
    }

    func testReturnsNilWhenCalculatedDiscountIsZeroOrLess() {
        XCTAssertNil(
            AnnualDiscountPolicy.percent(annualPrice: 12_000, monthlyPrice: 1_000)
        )
        XCTAssertNil(
            AnnualDiscountPolicy.percent(annualPrice: 13_000, monthlyPrice: 1_000)
        )
    }
}
