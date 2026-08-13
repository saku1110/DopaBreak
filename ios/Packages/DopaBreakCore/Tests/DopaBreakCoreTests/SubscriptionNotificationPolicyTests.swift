import Foundation
import XCTest
@testable import DopaBreakCore

final class SubscriptionNotificationPolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    // MARK: - 年額移行オファー

    func testAnnualOfferWaitsForTheNinetyDayBoundary() {
        let purchaseDate = date(year: 2026, month: 5, day: 1, hour: 10)
        let boundary = date(year: 2026, month: 7, day: 30, hour: 10)

        XCTAssertNil(
            AnnualUpgradeOfferPolicy.fireDate(
                subscription: monthly(purchaseDate: purchaseDate),
                isEnabled: true,
                scheduledFireDate: nil,
                now: boundary.addingTimeInterval(-1),
                calendar: calendar
            )
        )
        XCTAssertEqual(
            AnnualUpgradeOfferPolicy.fireDate(
                subscription: monthly(purchaseDate: purchaseDate),
                isEnabled: true,
                scheduledFireDate: nil,
                now: boundary,
                calendar: calendar
            ),
            boundary.addingTimeInterval(60)
        )
    }

    func testAnnualOfferCountsFromTheOriginalPurchaseDate() {
        // 更新のたびにpurchaseDateは進むが、判定は初回購入日を基準にする。
        let originalPurchaseDate = date(year: 2026, month: 5, day: 1, hour: 10)
        let renewalPurchaseDate = date(year: 2026, month: 7, day: 1, hour: 10)
        let subscription = SubscriptionEntitlementSnapshot(
            productID: ProProductID.monthly.rawValue,
            purchaseDate: renewalPurchaseDate,
            originalPurchaseDate: originalPurchaseDate,
            offerType: nil,
            willAutoRenew: true
        )

        XCTAssertNotNil(
            AnnualUpgradeOfferPolicy.fireDate(
                subscription: subscription,
                isEnabled: true,
                scheduledFireDate: nil,
                now: date(year: 2026, month: 7, day: 30, hour: 10),
                calendar: calendar
            )
        )
    }

    func testAnnualOfferIsMonthlySubscribersOnly() {
        let purchaseDate = date(year: 2026, month: 1, day: 1, hour: 10)
        let now = date(year: 2026, month: 7, day: 1, hour: 10)

        XCTAssertNil(
            AnnualUpgradeOfferPolicy.fireDate(
                subscription: SubscriptionEntitlementSnapshot(
                    productID: ProProductID.annual.rawValue,
                    purchaseDate: purchaseDate,
                    offerType: nil,
                    willAutoRenew: true
                ),
                isEnabled: true,
                scheduledFireDate: nil,
                now: now,
                calendar: calendar
            )
        )
        XCTAssertNil(
            AnnualUpgradeOfferPolicy.fireDate(
                subscription: SubscriptionEntitlementSnapshot(
                    productID: ProProductID.lifetime.rawValue,
                    purchaseDate: purchaseDate,
                    offerType: nil
                ),
                isEnabled: true,
                scheduledFireDate: nil,
                now: now,
                calendar: calendar
            )
        )
        XCTAssertNil(
            AnnualUpgradeOfferPolicy.fireDate(
                subscription: nil,
                isEnabled: true,
                scheduledFireDate: nil,
                now: now,
                calendar: calendar
            )
        )
    }

    func testAnnualOfferRespectsPlanNotificationToggle() {
        XCTAssertNil(
            AnnualUpgradeOfferPolicy.fireDate(
                subscription: monthly(purchaseDate: date(year: 2026, month: 1, day: 1, hour: 10)),
                isEnabled: false,
                scheduledFireDate: nil,
                now: date(year: 2026, month: 7, day: 1, hour: 10),
                calendar: calendar
            )
        )
    }

    func testAnnualOfferDefersToNextMorningOutsideQuietHours() {
        let purchaseDate = date(year: 2026, month: 5, day: 1, hour: 10)

        XCTAssertEqual(
            AnnualUpgradeOfferPolicy.fireDate(
                subscription: monthly(purchaseDate: purchaseDate),
                isEnabled: true,
                scheduledFireDate: nil,
                now: date(year: 2026, month: 7, day: 30, hour: 23),
                calendar: calendar
            ),
            date(year: 2026, month: 7, day: 31, hour: 9)
        )
        XCTAssertEqual(
            AnnualUpgradeOfferPolicy.fireDate(
                subscription: monthly(purchaseDate: purchaseDate),
                isEnabled: true,
                scheduledFireDate: nil,
                now: date(year: 2026, month: 7, day: 31, hour: 3),
                calendar: calendar
            ),
            date(year: 2026, month: 7, day: 31, hour: 9)
        )
    }

    func testAnnualOfferIsSentOnlyOnceEver() {
        let purchaseDate = date(year: 2026, month: 5, day: 1, hour: 10)
        let scheduledFireDate = date(year: 2026, month: 7, day: 30, hour: 10)

        // まだ発火前: 全消し→積み直しで落とさないよう、同じ時刻を返す。
        XCTAssertEqual(
            AnnualUpgradeOfferPolicy.fireDate(
                subscription: monthly(purchaseDate: purchaseDate),
                isEnabled: true,
                scheduledFireDate: scheduledFireDate,
                now: scheduledFireDate.addingTimeInterval(-60),
                calendar: calendar
            ),
            scheduledFireDate
        )
        // 発火後: 二度と予約しない。
        XCTAssertNil(
            AnnualUpgradeOfferPolicy.fireDate(
                subscription: monthly(purchaseDate: purchaseDate),
                isEnabled: true,
                scheduledFireDate: scheduledFireDate,
                now: scheduledFireDate,
                calendar: calendar
            )
        )
        XCTAssertNil(
            AnnualUpgradeOfferPolicy.fireDate(
                subscription: monthly(purchaseDate: purchaseDate),
                isEnabled: true,
                scheduledFireDate: scheduledFireDate,
                now: date(year: 2027, month: 1, day: 1, hour: 10),
                calendar: calendar
            )
        )
    }

    /// 予約済みマーカーがあっても、いまの購読が対象外なら送らない。
    /// 予約後・発火前に年額へ切り替えた人へ「月額3ヶ月目」の文面が届いていた退行の防止。
    func testAnnualOfferStoredFireDateStillRequiresAMonthlySubscription() {
        let scheduledFireDate = date(year: 2026, month: 7, day: 30, hour: 10)
        let now = scheduledFireDate.addingTimeInterval(-60)

        // 年額へ切り替えた直後。
        XCTAssertNil(
            AnnualUpgradeOfferPolicy.fireDate(
                subscription: SubscriptionEntitlementSnapshot(
                    productID: ProProductID.annual.rawValue,
                    purchaseDate: date(year: 2026, month: 5, day: 1, hour: 10),
                    offerType: nil,
                    willAutoRenew: true
                ),
                isEnabled: true,
                scheduledFireDate: scheduledFireDate,
                now: now,
                calendar: calendar
            )
        )
        // 失効して権利が無くなった人。
        XCTAssertNil(
            AnnualUpgradeOfferPolicy.fireDate(
                subscription: nil,
                isEnabled: true,
                scheduledFireDate: scheduledFireDate,
                now: now,
                calendar: calendar
            )
        )
        // 月額のままなら従来どおり同じ時刻で積み直す。
        XCTAssertEqual(
            AnnualUpgradeOfferPolicy.fireDate(
                subscription: monthly(purchaseDate: date(year: 2026, month: 5, day: 1, hour: 10)),
                isEnabled: true,
                scheduledFireDate: scheduledFireDate,
                now: now,
                calendar: calendar
            ),
            scheduledFireDate
        )
    }

    /// プラン通知をオフにすると予約は消える。発火前ならまだ誰にも届いていないので、
    /// マーカーを戻して次にオンへ戻したときに送れるようにする。
    func testAnnualOfferMarkerIsReturnedWhenTheOfferIsDisarmedBeforeItFires() {
        let scheduledFireDate = date(year: 2026, month: 7, day: 31, hour: 9)

        XCTAssertTrue(
            AnnualUpgradeOfferPolicy.shouldClearScheduledFireDate(
                isEnabled: false,
                scheduledFireDate: scheduledFireDate,
                now: scheduledFireDate.addingTimeInterval(-1)
            )
        )
        // 発火時刻を過ぎたものは届いた可能性があるため残す（二重送信を作らない）。
        XCTAssertFalse(
            AnnualUpgradeOfferPolicy.shouldClearScheduledFireDate(
                isEnabled: false,
                scheduledFireDate: scheduledFireDate,
                now: scheduledFireDate
            )
        )
        // オンのままなら触らない。
        XCTAssertFalse(
            AnnualUpgradeOfferPolicy.shouldClearScheduledFireDate(
                isEnabled: true,
                scheduledFireDate: scheduledFireDate,
                now: scheduledFireDate.addingTimeInterval(-1)
            )
        )
        XCTAssertFalse(
            AnnualUpgradeOfferPolicy.shouldClearScheduledFireDate(
                isEnabled: false,
                scheduledFireDate: nil,
                now: scheduledFireDate
            )
        )
    }

    /// マーカーを戻した後は、同じ条件でもう一度予約できる（機会を失わない）。
    func testAnnualOfferCanBeRearmedAfterItsMarkerIsReturned() {
        let purchaseDate = date(year: 2026, month: 5, day: 1, hour: 10)
        let now = date(year: 2026, month: 8, day: 1, hour: 10)

        XCTAssertEqual(
            AnnualUpgradeOfferPolicy.fireDate(
                subscription: monthly(purchaseDate: purchaseDate),
                isEnabled: true,
                scheduledFireDate: nil,
                now: now,
                calendar: calendar
            ),
            now.addingTimeInterval(60)
        )
    }

    // MARK: - 解約セーブ

    func testCancelSaveFiresThreeDaysBeforeExpiration() {
        let expirationDate = date(year: 2026, month: 8, day: 20, hour: 12)

        XCTAssertEqual(
            CancelSaveNotificationPolicy.fireDate(
                subscription: monthly(
                    purchaseDate: date(year: 2026, month: 7, day: 20, hour: 12),
                    willAutoRenew: false,
                    expirationDate: expirationDate
                ),
                isEnabled: true,
                sentExpirationDate: nil,
                sentFireDate: nil,
                now: date(year: 2026, month: 8, day: 1, hour: 12),
                calendar: calendar
            ),
            date(year: 2026, month: 8, day: 17, hour: 12)
        )
    }

    func testCancelSaveRequiresAutoRenewOffAndKnownExpiration() {
        let expirationDate = date(year: 2026, month: 8, day: 20, hour: 12)
        let now = date(year: 2026, month: 8, day: 1, hour: 12)
        let purchaseDate = date(year: 2026, month: 7, day: 20, hour: 12)

        XCTAssertNil(
            CancelSaveNotificationPolicy.fireDate(
                subscription: monthly(
                    purchaseDate: purchaseDate,
                    willAutoRenew: true,
                    expirationDate: expirationDate
                ),
                isEnabled: true,
                sentExpirationDate: nil,
                sentFireDate: nil,
                now: now,
                calendar: calendar
            )
        )
        XCTAssertNil(
            CancelSaveNotificationPolicy.fireDate(
                subscription: monthly(
                    purchaseDate: purchaseDate,
                    willAutoRenew: nil,
                    expirationDate: expirationDate
                ),
                isEnabled: true,
                sentExpirationDate: nil,
                sentFireDate: nil,
                now: now,
                calendar: calendar
            )
        )
        XCTAssertNil(
            CancelSaveNotificationPolicy.fireDate(
                subscription: monthly(
                    purchaseDate: purchaseDate,
                    willAutoRenew: false,
                    expirationDate: nil
                ),
                isEnabled: true,
                sentExpirationDate: nil,
                sentFireDate: nil,
                now: now,
                calendar: calendar
            )
        )
        XCTAssertNil(
            CancelSaveNotificationPolicy.fireDate(
                subscription: monthly(
                    purchaseDate: purchaseDate,
                    willAutoRenew: false,
                    expirationDate: expirationDate
                ),
                isEnabled: false,
                sentExpirationDate: nil,
                sentFireDate: nil,
                now: now,
                calendar: calendar
            )
        )
    }

    func testCancelSaveNeverFiresLate() {
        let expirationDate = date(year: 2026, month: 8, day: 20, hour: 12)

        XCTAssertNil(
            CancelSaveNotificationPolicy.fireDate(
                subscription: monthly(
                    purchaseDate: date(year: 2026, month: 7, day: 20, hour: 12),
                    willAutoRenew: false,
                    expirationDate: expirationDate
                ),
                isEnabled: true,
                sentExpirationDate: nil,
                sentFireDate: nil,
                now: date(year: 2026, month: 8, day: 18, hour: 12),
                calendar: calendar
            )
        )
    }

    func testCancelSaveAppliesQuietHoursToTheThreeDayMark() {
        let lateExpiration = date(year: 2026, month: 8, day: 20, hour: 23, minute: 30)
        let earlyExpiration = date(year: 2026, month: 8, day: 20, hour: 6)
        let now = date(year: 2026, month: 8, day: 1, hour: 12)

        XCTAssertEqual(
            CancelSaveNotificationPolicy.fireDate(
                subscription: monthly(
                    purchaseDate: date(year: 2026, month: 7, day: 20, hour: 12),
                    willAutoRenew: false,
                    expirationDate: lateExpiration
                ),
                isEnabled: true,
                sentExpirationDate: nil,
                sentFireDate: nil,
                now: now,
                calendar: calendar
            ),
            date(year: 2026, month: 8, day: 18, hour: 9)
        )
        XCTAssertEqual(
            CancelSaveNotificationPolicy.fireDate(
                subscription: monthly(
                    purchaseDate: date(year: 2026, month: 7, day: 20, hour: 12),
                    willAutoRenew: false,
                    expirationDate: earlyExpiration
                ),
                isEnabled: true,
                sentExpirationDate: nil,
                sentFireDate: nil,
                now: now,
                calendar: calendar
            ),
            date(year: 2026, month: 8, day: 17, hour: 9)
        )
    }

    func testCancelSaveDoesNotResendForTheSameExpirationDate() {
        let expirationDate = date(year: 2026, month: 8, day: 20, hour: 12)
        let sentFireDate = date(year: 2026, month: 8, day: 17, hour: 12)
        let subscription = monthly(
            purchaseDate: date(year: 2026, month: 7, day: 20, hour: 12),
            willAutoRenew: false,
            expirationDate: expirationDate
        )

        // 送信済みかつ発火済み: オフ→オン→オフを繰り返しても二度目は出さない。
        XCTAssertNil(
            CancelSaveNotificationPolicy.fireDate(
                subscription: subscription,
                isEnabled: true,
                sentExpirationDate: expirationDate,
                sentFireDate: sentFireDate,
                now: date(year: 2026, month: 8, day: 18, hour: 12),
                calendar: calendar
            )
        )
        // 送信済みでもまだ発火前なら、pendingを保つため同じ時刻で積み直す（送るのは1回のまま）。
        XCTAssertEqual(
            CancelSaveNotificationPolicy.fireDate(
                subscription: subscription,
                isEnabled: true,
                sentExpirationDate: expirationDate,
                sentFireDate: sentFireDate,
                now: date(year: 2026, month: 8, day: 10, hour: 12),
                calendar: calendar
            ),
            sentFireDate
        )
    }

    func testCancelSaveSendsAgainForANewExpirationDate() {
        let sentExpirationDate = date(year: 2026, month: 8, day: 20, hour: 12)
        let newExpirationDate = date(year: 2026, month: 9, day: 20, hour: 12)

        XCTAssertEqual(
            CancelSaveNotificationPolicy.fireDate(
                subscription: monthly(
                    purchaseDate: date(year: 2026, month: 8, day: 20, hour: 12),
                    willAutoRenew: false,
                    expirationDate: newExpirationDate
                ),
                isEnabled: true,
                sentExpirationDate: sentExpirationDate,
                sentFireDate: date(year: 2026, month: 8, day: 17, hour: 12),
                now: date(year: 2026, month: 9, day: 1, hour: 12),
                calendar: calendar
            ),
            date(year: 2026, month: 9, day: 17, hour: 12)
        )
    }

    func testCancelSaveMarkerToleratesSubSecondDateDrift() {
        let expirationDate = date(year: 2026, month: 8, day: 20, hour: 12)

        XCTAssertTrue(
            CancelSaveNotificationPolicy.isSamePeriod(
                expirationDate,
                expirationDate.addingTimeInterval(0.0001)
            )
        )
        XCTAssertFalse(
            CancelSaveNotificationPolicy.isSamePeriod(
                expirationDate,
                expirationDate.addingTimeInterval(60)
            )
        )
    }

    private func monthly(
        purchaseDate: Date,
        willAutoRenew: Bool? = true,
        expirationDate: Date? = nil
    ) -> SubscriptionEntitlementSnapshot {
        SubscriptionEntitlementSnapshot(
            productID: ProProductID.monthly.rawValue,
            purchaseDate: purchaseDate,
            offerType: nil,
            willAutoRenew: willAutoRenew,
            expirationDate: expirationDate
        )
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date!
    }
}
