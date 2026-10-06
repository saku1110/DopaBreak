import Foundation
import XCTest
@testable import DopaBreakCore

/// 通知タップの着地先を、どれだけのあいだ受け付けるか。
///
/// 振り返りだけが長い。宣言時間の終わりに届く通知は手が空いてからタップされるため、
/// 既定の30分で切ると `InterventionEngine` が3時間まで出せるのに着地先が先に捨てられ、
/// 本人は一度も振り返りを見ないまま畳まれる（2026-09-04の修正3）。
final class PendingNotificationDestinationTests: XCTestCase {
    private let writtenAt = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - 振り返りは3時間

    func testReflectionSurvivesTwoHoursAfterTheTap() {
        let pending = PendingNotificationDestination(destination: .reflection, writtenAt: writtenAt)

        XCTAssertTrue(pending.isValid(at: writtenAt.addingTimeInterval(2 * 60 * 60)))
    }

    func testReflectionIsStillValidExactlyAtThreeHours() {
        let pending = PendingNotificationDestination(destination: .reflection, writtenAt: writtenAt)

        XCTAssertTrue(
            pending.isValid(
                at: writtenAt.addingTimeInterval(
                    PendingNotificationDestination.reflectionValidityInterval
                )
            )
        )
    }

    func testReflectionExpiresPastThreeHours() {
        let pending = PendingNotificationDestination(destination: .reflection, writtenAt: writtenAt)

        XCTAssertFalse(
            pending.isValid(
                at: writtenAt.addingTimeInterval(
                    PendingNotificationDestination.reflectionValidityInterval + 1
                )
            )
        )
    }

    /// 着地先の窓とエンジンの窓は必ず同じ長さにする。
    /// 片方だけ伸ばすと、着地先が生きているのにエンジンが出せない（または逆）穴に戻る。
    func testReflectionWindowMatchesTheEngineTapWindow() {
        XCTAssertEqual(
            PendingNotificationDestination.reflectionValidityInterval,
            InterventionEngine.reflectionNotificationTapWindow
        )
    }

    // MARK: - ほかの着地先は既定のまま

    func testOtherDestinationsKeepTheThirtyMinuteDefault() {
        for destination in NotificationDestination.allCases where destination != .reflection {
            let pending = PendingNotificationDestination(
                destination: destination,
                writtenAt: writtenAt
            )

            XCTAssertTrue(
                pending.isValid(at: writtenAt.addingTimeInterval(29 * 60)),
                "\(destination) は30分以内なら受ける"
            )
            XCTAssertFalse(
                pending.isValid(at: writtenAt.addingTimeInterval(31 * 60)),
                "\(destination) は30分を過ぎたら捨てる"
            )
            XCTAssertEqual(
                PendingNotificationDestination.validity(for: destination),
                PendingNotificationDestination.validityInterval
            )
        }
    }

    /// 端末の時刻が巻き戻った着地先は受けない（従来どおり）。
    func testAWriteTimeInTheFutureIsNeverValid() {
        for destination in NotificationDestination.allCases {
            let pending = PendingNotificationDestination(
                destination: destination,
                writtenAt: writtenAt
            )

            XCTAssertFalse(pending.isValid(at: writtenAt.addingTimeInterval(-1)))
        }
    }
}
