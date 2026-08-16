import XCTest

@testable import DopaBreak

final class LaunchSplashTests: XCTestCase {
    func testEveryColdLaunchPolicyPresentsOnEveryColdLaunch() {
        XCTAssertEqual(
            LaunchSplashDisplayPolicy.everyColdLaunch.presentationDecision(
                for: .coldLaunch,
                reduceMotion: false,
                voiceOverRunning: false,
                hasShownBefore: true
            ),
            .present
        )
    }

    func testEveryColdLaunchPolicySkipsBackgroundResume() {
        XCTAssertEqual(
            LaunchSplashDisplayPolicy.everyColdLaunch.presentationDecision(
                for: .backgroundResume,
                reduceMotion: false,
                voiceOverRunning: false,
                hasShownBefore: false
            ),
            .skip(.backgroundResume)
        )
    }

    func testFirstColdLaunchPolicyCanBeSelectedInOnePlace() {
        XCTAssertEqual(
            LaunchSplashDisplayPolicy.firstColdLaunchOnly.presentationDecision(
                for: .coldLaunch,
                reduceMotion: false,
                voiceOverRunning: false,
                hasShownBefore: false
            ),
            .present
        )
        XCTAssertEqual(
            LaunchSplashDisplayPolicy.firstColdLaunchOnly.presentationDecision(
                for: .coldLaunch,
                reduceMotion: false,
                voiceOverRunning: false,
                hasShownBefore: true
            ),
            .skip(.displayPolicy)
        )
    }

    func testReduceMotionSkipsImmediately() {
        let decision = LaunchSplashDisplayPolicy.everyColdLaunch.presentationDecision(
            for: .coldLaunch,
            reduceMotion: true,
            voiceOverRunning: false,
            hasShownBefore: false
        )
        let state = LaunchSplashStateMachine(presentationDecision: decision)

        XCTAssertEqual(decision, .skip(.reduceMotion))
        XCTAssertTrue(state.isCompleted)
        XCTAssertEqual(state.phase, .completed(.reduceMotion))
    }

    func testVoiceOverSkipsImmediately() {
        let decision = LaunchSplashDisplayPolicy.everyColdLaunch.presentationDecision(
            for: .coldLaunch,
            reduceMotion: false,
            voiceOverRunning: true,
            hasShownBefore: false
        )
        let state = LaunchSplashStateMachine(presentationDecision: decision)

        XCTAssertEqual(decision, .skip(.voiceOver))
        XCTAssertTrue(state.isCompleted)
        XCTAssertEqual(state.phase, .completed(.voiceOver))
    }

    func testCoordinatorNeverPresentsAfterCompletion() throws {
        let coordinator = LaunchSplashCoordinator(userDefaults: try makeUserDefaults())
        coordinator.complete(.userSkipped)

        for reduceMotion in [false, true] {
            for voiceOverRunning in [false, true] {
                XCTAssertEqual(
                    coordinator.presentationDecision(
                        reduceMotion: reduceMotion,
                        voiceOverRunning: voiceOverRunning
                    ),
                    .skip(.userSkipped)
                )
            }
        }
    }

    func testCoordinatorCompletionIsIdempotent() throws {
        let coordinator = LaunchSplashCoordinator(userDefaults: try makeUserDefaults())

        coordinator.complete(.userSkipped)
        coordinator.complete(.playbackFailed)

        XCTAssertEqual(coordinator.completionReason, .userSkipped)
    }

    func testOnlyFirstColdLaunchPolicyRecordsPresentation() throws {
        let everyColdLaunchDefaults = try makeUserDefaults()
        let everyColdLaunchCoordinator = LaunchSplashCoordinator(
            displayPolicy: .everyColdLaunch,
            userDefaults: everyColdLaunchDefaults
        )

        everyColdLaunchCoordinator.recordPresentationIfNeeded()

        XCTAssertFalse(
            everyColdLaunchDefaults.bool(
                forKey: LaunchSplashConfiguration.firstLaunchShownKey
            )
        )

        let firstColdLaunchDefaults = try makeUserDefaults()
        let firstColdLaunchCoordinator = LaunchSplashCoordinator(
            displayPolicy: .firstColdLaunchOnly,
            userDefaults: firstColdLaunchDefaults
        )

        firstColdLaunchCoordinator.recordPresentationIfNeeded()

        XCTAssertTrue(
            firstColdLaunchDefaults.bool(
                forKey: LaunchSplashConfiguration.firstLaunchShownKey
            )
        )
    }

    func testOpenURLHandlerRejectsDifferentScheme() throws {
        let result = try handleOpenURL("other://intervene?app=instagram")

        XCTAssertFalse(result.wasHandled)
        XCTAssertTrue(result.consumedCatalogIDs.isEmpty)
    }

    func testOpenURLHandlerRejectsDifferentHost() throws {
        let result = try handleOpenURL("dopabreak://other?app=instagram")

        XCTAssertFalse(result.wasHandled)
        XCTAssertTrue(result.consumedCatalogIDs.isEmpty)
    }

    func testOpenURLHandlerRejectsMissingAppParameter() throws {
        let result = try handleOpenURL("dopabreak://intervene")

        XCTAssertFalse(result.wasHandled)
        XCTAssertTrue(result.consumedCatalogIDs.isEmpty)
    }

    func testOpenURLHandlerRejectsUnknownCatalogID() throws {
        let result = try handleOpenURL("dopabreak://intervene?app=unknown")

        XCTAssertFalse(result.wasHandled)
        XCTAssertTrue(result.consumedCatalogIDs.isEmpty)
    }

    func testOpenURLHandlerAcceptsKnownIntervention() throws {
        let result = try handleOpenURL("dopabreak://intervene?app=instagram")

        XCTAssertTrue(result.wasHandled)
        XCTAssertEqual(result.consumedCatalogIDs, ["instagram"])
    }

    func testFailSafeDurationsMaintainRequiredInvariants() {
        XCTAssertLessThan(
            LaunchSplashConfiguration.startupTimeout,
            LaunchSplashConfiguration.maximumPlaybackDuration
        )
        XCTAssertGreaterThanOrEqual(
            LaunchSplashConfiguration.maximumPlaybackDuration,
            LaunchSplashConfiguration.videoDuration
                + LaunchSplashConfiguration.playbackCompletionMargin
        )
    }

    func testStartupTimeoutCompletesSplash() {
        var state = LaunchSplashStateMachine(presentationDecision: .present)

        let completion = state.handle(.startupTimedOut)

        XCTAssertEqual(completion, .startupTimedOut)
        XCTAssertEqual(state.phase, .completed(.startupTimedOut))
    }

    func testPlaybackFailureCompletesSplash() {
        var state = LaunchSplashStateMachine(presentationDecision: .present)

        let completion = state.handle(.playbackFailed)

        XCTAssertEqual(completion, .playbackFailed)
        XCTAssertEqual(state.phase, .completed(.playbackFailed))
    }

    func testMaximumDurationGuardCompletesSplashAfterPlaybackStarts() {
        var state = LaunchSplashStateMachine(presentationDecision: .present)

        XCTAssertNil(state.handle(.playbackStarted))
        let completion = state.handle(.maximumDurationReached)

        XCTAssertEqual(completion, .maximumDurationReached)
        XCTAssertEqual(state.phase, .completed(.maximumDurationReached))
    }

    func testCompletionIsIdempotent() {
        var state = LaunchSplashStateMachine(presentationDecision: .present)

        XCTAssertEqual(state.handle(.userSkipped), .userSkipped)
        XCTAssertNil(state.handle(.playbackFailed))
        XCTAssertEqual(state.phase, .completed(.userSkipped))
    }

    private func makeUserDefaults() throws -> UserDefaults {
        let suiteName = "LaunchSplashTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }

    private func handleOpenURL(
        _ rawURL: String
    ) throws -> (wasHandled: Bool, consumedCatalogIDs: [String]) {
        let url = try XCTUnwrap(URL(string: rawURL))
        var consumedCatalogIDs: [String] = []
        let wasHandled = DopaBreakOpenURLHandler.handle(url) { catalogID in
            consumedCatalogIDs.append(catalogID)
        }
        return (wasHandled, consumedCatalogIDs)
    }
}
