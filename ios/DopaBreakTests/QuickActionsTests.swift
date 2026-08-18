import UIKit
import XCTest

@testable import DopaBreak

final class QuickActionsTests: XCTestCase {
    // MARK: - 引き止めオファー枠の出し分け

    func testOfferSlotStaysHiddenWhileFeatureFlagIsOff() {
        XCTAssertFalse(
            QuickActionPolicy.showsOfferSlot(
                isPro: false,
                hasConfirmedEntitlement: true,
                offerSlotEnabled: false
            )
        )
    }

    func testShippedConfigurationKeepsOfferSlotOff() {
        // App Store Connect に実オファーを作るまでは既定OFF。
        XCTAssertFalse(QuickActionsConfiguration.offerSlotEnabled)
        XCTAssertFalse(
            QuickActionPolicy.showsOfferSlot(isPro: false, hasConfirmedEntitlement: true)
        )
    }

    func testOfferSlotNeverShownToSubscriber() {
        XCTAssertFalse(
            QuickActionPolicy.showsOfferSlot(
                isPro: true,
                hasConfirmedEntitlement: true,
                offerSlotEnabled: true
            )
        )
    }

    func testOfferSlotHiddenWhileEntitlementIsUnconfirmed() {
        // 権利の取得に失敗しただけの課金者へ割引を見せない（未確定は課金者扱い）。
        XCTAssertFalse(
            QuickActionPolicy.showsOfferSlot(
                isPro: false,
                hasConfirmedEntitlement: false,
                offerSlotEnabled: true
            )
        )
        XCTAssertFalse(
            QuickActionPolicy.showsOfferSlot(
                isPro: true,
                hasConfirmedEntitlement: false,
                offerSlotEnabled: true
            )
        )
    }

    func testOfferSlotShownOnlyToConfirmedFreeUserWhenEnabled() {
        XCTAssertTrue(
            QuickActionPolicy.showsOfferSlot(
                isPro: false,
                hasConfirmedEntitlement: true,
                offerSlotEnabled: true
            )
        )
    }

    // MARK: - 登録する枠と並び

    func testShippedTypesAreCoreAndSupportOnly() {
        XCTAssertEqual(
            QuickActionPolicy.types(
                isOnboardingCompleted: true,
                hasInterventionTargets: true,
                isPro: false,
                hasConfirmedEntitlement: true
            ),
            [.intervene, .support]
        )
    }

    func testSubscriberNeverGetsOfferSlotEvenWhenEnabled() {
        XCTAssertEqual(
            QuickActionPolicy.types(
                isOnboardingCompleted: true,
                hasInterventionTargets: true,
                isPro: true,
                hasConfirmedEntitlement: true,
                offerSlotEnabled: true
            ),
            [.intervene, .support]
        )
    }

    func testEnabledOfferSlotSitsBetweenCoreAndSupport() {
        XCTAssertEqual(
            QuickActionPolicy.types(
                isOnboardingCompleted: true,
                hasInterventionTargets: true,
                isPro: false,
                hasConfirmedEntitlement: true,
                offerSlotEnabled: true
            ),
            [.intervene, .offer, .support]
        )
    }

    func testOnboardingIncompleteKeepsSupportOnly() {
        // 介入は対象アプリが決まる前に着地先を持たない。
        XCTAssertEqual(
            QuickActionPolicy.types(
                isOnboardingCompleted: false,
                hasInterventionTargets: false,
                isPro: false,
                hasConfirmedEntitlement: true,
                offerSlotEnabled: true
            ),
            [.support]
        )
    }

    func testOnboardingIncompleteKeepsSupportOnlyEvenWithTargets() {
        // 対象が残っていてもオンボーディング未完了なら介入は出さない（既存の挙動を保つ）。
        XCTAssertEqual(
            QuickActionPolicy.types(
                isOnboardingCompleted: false,
                hasInterventionTargets: true,
                isPro: false,
                hasConfirmedEntitlement: true,
                offerSlotEnabled: true
            ),
            [.support]
        )
    }

    // MARK: - 対象アプリ0件

    func testInterveneSlotDroppedWhenNoTargetRemains() {
        // 設定で対象を全部外すと介入は着地先を持たない。押しても無反応な枠を残さない。
        XCTAssertEqual(
            QuickActionPolicy.types(
                isOnboardingCompleted: true,
                hasInterventionTargets: false,
                isPro: false,
                hasConfirmedEntitlement: true
            ),
            [.support]
        )
    }

    func testNoTargetKeepsOfferSlotWhenEnabled() {
        // 対象0件で落とすのは介入枠だけ。引き止めオファーは対象の有無と関係がない。
        XCTAssertEqual(
            QuickActionPolicy.types(
                isOnboardingCompleted: true,
                hasInterventionTargets: false,
                isPro: false,
                hasConfirmedEntitlement: true,
                offerSlotEnabled: true
            ),
            [.offer, .support]
        )
    }

    func testInterveneSlotReturnsOnceTargetIsSelectedAgain() {
        XCTAssertEqual(
            QuickActionPolicy.types(
                isOnboardingCompleted: true,
                hasInterventionTargets: true,
                isPro: false,
                hasConfirmedEntitlement: true
            ),
            [.intervene, .support]
        )
    }

    @MainActor
    func testRegistrationDropsInterveneWhenLastTargetIsRemoved() {
        let center = QuickActionCenter()
        let application = UIApplication.shared
        let originalItems = application.shortcutItems
        defer { application.shortcutItems = originalItems }

        center.updateShortcutItems(
            isOnboardingCompleted: true,
            hasInterventionTargets: true,
            isPro: false,
            hasConfirmedEntitlement: true,
            application: application
        )
        XCTAssertEqual(
            application.shortcutItems?.map(\.type),
            [QuickActionType.intervene, .support].map(\.shortcutItemType)
        )

        center.enqueue(.intervene)
        center.updateShortcutItems(
            isOnboardingCompleted: true,
            hasInterventionTargets: false,
            isPro: false,
            hasConfirmedEntitlement: true,
            application: application
        )
        XCTAssertEqual(
            application.shortcutItems?.map(\.type),
            [QuickActionType.support.shortcutItemType]
        )
        // 外れた枠の押下が残っていると、着地先の無いまま消費されてしまう。
        XCTAssertNil(center.pendingAction)

        center.updateShortcutItems(
            isOnboardingCompleted: true,
            hasInterventionTargets: true,
            isPro: false,
            hasConfirmedEntitlement: true,
            application: application
        )
        XCTAssertEqual(
            application.shortcutItems?.map(\.type),
            [QuickActionType.intervene, .support].map(\.shortcutItemType)
        )
    }

    // MARK: - 識別子

    func testShortcutItemTypeRoundTripsForEveryCase() {
        for type in QuickActionType.allCases {
            XCTAssertEqual(QuickActionType(shortcutItemType: type.shortcutItemType), type)
        }
    }

    func testUnknownShortcutItemTypeIsRejected() {
        XCTAssertNil(QuickActionType(shortcutItemType: "com.example.other"))
    }

    // MARK: - 押下の受け渡し

    @MainActor
    func testEnqueueAcceptsKnownShortcutItemAndConsumesOnce() {
        let center = QuickActionCenter()
        let item = UIApplicationShortcutItem(
            type: QuickActionType.intervene.shortcutItemType,
            localizedTitle: "test"
        )

        XCTAssertTrue(center.enqueue(item))
        XCTAssertEqual(center.pendingAction, .intervene)
        XCTAssertEqual(center.consumePendingAction(), .intervene)
        XCTAssertNil(center.pendingAction)
        XCTAssertNil(center.consumePendingAction())
    }

    @MainActor
    func testEnqueueRejectsUnknownShortcutItem() {
        let center = QuickActionCenter()
        let item = UIApplicationShortcutItem(type: "com.example.other", localizedTitle: "test")

        XCTAssertFalse(center.enqueue(item))
        XCTAssertNil(center.pendingAction)
    }

    @MainActor
    func testRegistrationDropsPendingActionThatLeftTheMenu() {
        let center = QuickActionCenter()
        let application = UIApplication.shared
        let originalItems = application.shortcutItems
        defer { application.shortcutItems = originalItems }

        center.updateShortcutItems(
            isOnboardingCompleted: true,
            hasInterventionTargets: true,
            isPro: false,
            hasConfirmedEntitlement: true,
            application: application
        )
        XCTAssertEqual(
            application.shortcutItems?.map(\.type),
            [QuickActionType.intervene, .support].map(\.shortcutItemType)
        )

        center.enqueue(.intervene)
        center.updateShortcutItems(
            isOnboardingCompleted: false,
            hasInterventionTargets: true,
            isPro: false,
            hasConfirmedEntitlement: true,
            application: application
        )
        XCTAssertEqual(
            application.shortcutItems?.map(\.type),
            [QuickActionType.support.shortcutItemType]
        )
        XCTAssertNil(center.pendingAction)
    }

    @MainActor
    func testRegistrationCarriesLocalizedTitleAndIcon() {
        let center = QuickActionCenter()
        let application = UIApplication.shared
        let originalItems = application.shortcutItems
        defer { application.shortcutItems = originalItems }

        center.updateShortcutItems(
            isOnboardingCompleted: true,
            hasInterventionTargets: true,
            isPro: false,
            hasConfirmedEntitlement: true,
            application: application
        )

        let items = try? XCTUnwrap(application.shortcutItems)
        XCTAssertEqual(items?.count, 2)
        XCTAssertEqual(items?.first?.localizedTitle, QuickActionType.intervene.localizedTitle)
        XCTAssertNotNil(items?.first?.icon)
        XCTAssertNil(items?.first?.localizedSubtitle)
    }
}
