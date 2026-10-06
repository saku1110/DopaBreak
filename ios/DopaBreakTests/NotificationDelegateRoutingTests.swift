import DopaBreakCore
import UserNotifications
import XCTest
@testable import DopaBreak

@MainActor
final class NotificationDelegateRoutingTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var settingsStore: SettingsStore!
    private var delegate: NotificationDelegate!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "NotificationDelegateRoutingTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        settingsStore = SettingsStore(userDefaults: defaults)
        delegate = NotificationDelegate(settingsStore: settingsStore)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        delegate = nil
        settingsStore = nil
        defaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    /// 実機クラッシュ（2026-09-02 / 09-03）の再発防止。async版のデリゲートは、ObjCブリッジの
    /// 完了ハンドラを協調プールのスレッドで呼び返していた。UIKitがその延長でメインスレッド外の
    /// スナップショット更新に入り、通知をタップしても画面が出る前にSIGABRTで落ちていた。
    func testCompletionRunsOnMainThreadWhenCalledFromBackgroundQueue() throws {
        let settingsStore = try XCTUnwrap(self.settingsStore)
        let completed = expectation(description: "completion")
        var wasMainThread: Bool?

        // NotificationDelegate自体はSendableではないので、バックグラウンド側で作って渡さない。
        DispatchQueue.global(qos: .userInitiated).async {
            NotificationDelegate(settingsStore: settingsStore).handleResponse(
                identifier: NotificationIdentifier.reflectionPrompt,
                actionIdentifier: UNNotificationDefaultActionIdentifier,
                completion: {
                    wasMainThread = Thread.isMainThread
                    completed.fulfill()
                }
            )
        }

        wait(for: [completed], timeout: 2)
        XCTAssertEqual(wasMainThread, true)
    }

    func testDefaultActionStoresReflectionDestinationAndPostsChange() throws {
        let posted = expectation(
            forNotification: .notificationDestinationDidChange,
            object: nil,
            handler: nil
        )
        let completed = expectation(description: "completion")

        delegate.handleResponse(
            identifier: NotificationIdentifier.reflectionPrompt,
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            completion: { completed.fulfill() }
        )

        wait(for: [posted, completed], timeout: 2)
        let pending = try XCTUnwrap(settingsStore.pendingNotificationDestination)
        XCTAssertEqual(pending.destination, .reflection)
    }

    func testNonDefaultActionStoresNothingAndStillCompletes() {
        let completed = expectation(description: "completion")

        delegate.handleResponse(
            identifier: NotificationIdentifier.reflectionPrompt,
            actionIdentifier: UNNotificationDismissActionIdentifier,
            completion: { completed.fulfill() }
        )

        wait(for: [completed], timeout: 2)
        XCTAssertNil(settingsStore.pendingNotificationDestination)
    }

    func testUnroutedIdentifierStoresNothingAndStillCompletes() {
        let completed = expectation(description: "completion")

        delegate.handleResponse(
            identifier: "dopabreak.lock.morning",
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            completion: { completed.fulfill() }
        )

        wait(for: [completed], timeout: 2)
        XCTAssertNil(settingsStore.pendingNotificationDestination)
    }
}
