import DopaBreakCore
import SwiftUI
import UIKit
import XCTest
@testable import DopaBreak

@MainActor
final class SettingsDeviceFixesSnapshotCapture: XCTestCase {
    func testHoldTimelineForPausedDragVerification() throws {
        guard ProcessInfo.processInfo.environment["DOPABREAK_HOLD_TIMELINE_DRAG"] == "1" else {
            throw XCTSkip("Set DOPABREAK_HOLD_TIMELINE_DRAG=1 for interactive drag verification")
        }

        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        fixture.settingsStore.wakeTimeMinutes = 420
        fixture.settingsStore.bedTimeMinutes = 60

        let size = CGSize(width: 393, height: 852)
        let view = SettingsView(
            snapshotModel: fixture.model,
            settingsStore: fixture.settingsStore,
            screenTimeAuthorized: true,
            onResetOnboarding: {}
        )
        .frame(width: size.width, height: size.height)

        let controller = UIHostingController(rootView: view)
        let windowScene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: windowScene)
        window.frame = CGRect(origin: .zero, size: size)
        window.windowLevel = .alert + 1
        window.rootViewController = controller
        window.makeKeyAndVisible()
        window.layoutIfNeeded()

        let appeared = expectation(description: "Settings timeline appeared")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { appeared.fulfill() }
        wait(for: [appeared], timeout: 1)

        let scrollView = try XCTUnwrap(firstScrollView(in: controller.view))
        let maximumOffset = max(
            0,
            scrollView.contentSize.height - scrollView.adjustedContentInset.top
                - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
        )
        scrollView.setContentOffset(
            CGPoint(x: 0, y: maximumOffset * 0.72),
            animated: false
        )
        window.layoutIfNeeded()
        print("TIMELINE_PAUSED_DRAG_READY")

        let hold = expectation(description: "External Simulator drag verification completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { hold.fulfill() }
        wait(for: [hold], timeout: 65)

        window.isHidden = true
        window.rootViewController = nil
    }

    func testCaptureHomeBlockSettingsLanding() throws {
        guard ProcessInfo.processInfo.environment["DOPABREAK_CAPTURE_SETTINGS_DEVICE_FIXES"] == "1" else {
            throw XCTSkip("Set DOPABREAK_CAPTURE_SETTINGS_DEVICE_FIXES=1 to capture verification images")
        }

        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        let actionReady = expectation(description: "Home block settings action is available")
        var openBlockSettings: (() -> Void)?
        let size = CGSize(width: 393, height: 852)
        let view = HomeBlockSettingsLandingHarness(
            model: fixture.model,
            settingsStore: fixture.settingsStore,
            onBlockSettingsActionReady: { action in
                openBlockSettings = action
                actionReady.fulfill()
            }
        )
        .frame(width: size.width, height: size.height)

        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.isHidden = false
        window.layoutIfNeeded()
        wait(for: [actionReady], timeout: 2)

        try XCTUnwrap(openBlockSettings)()
        let landed = expectation(description: "Settings consumed the Full Block focus request")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if !fixture.model.pendingDeepFocusSettingsFocus {
                landed.fulfill()
            }
        }
        wait(for: [landed], timeout: 2)
        window.layoutIfNeeded()
        XCTAssertNil(fixture.model.deepFocusSession)

        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            controller.view.drawHierarchy(
                in: CGRect(origin: .zero, size: size),
                afterScreenUpdates: true
            )
        }
        let outputURL = projectRootURL
            .appendingPathComponent("output/verify", isDirectory: true)
            .appendingPathComponent("home-block-settings-landing-warm.png")
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try XCTUnwrap(image.pngData()).write(to: outputURL, options: .atomic)
        XCTAssertEqual(image.cgImage?.width, 1_179)
        XCTAssertEqual(image.cgImage?.height, 2_556)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        window.isHidden = true
        window.rootViewController = nil
    }

    func testCaptureSettingsDeviceFixes() throws {
        guard ProcessInfo.processInfo.environment["DOPABREAK_CAPTURE_SETTINGS_DEVICE_FIXES"] == "1" else {
            throw XCTSkip("Set DOPABREAK_CAPTURE_SETTINGS_DEVICE_FIXES=1 to capture verification images")
        }

        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        try capture(
            model: fixture.model,
            settingsStore: fixture.settingsStore,
            timelineDragPreview: false,
            scrollFraction: 0.30,
            filename: "settings-deep-focus-choose-apps.png"
        )
        fixture.settingsStore.wakeTimeMinutes = 420
        fixture.settingsStore.bedTimeMinutes = 60
        try capture(
            model: fixture.model,
            settingsStore: fixture.settingsStore,
            timelineDragPreview: true,
            scrollFraction: 0.72,
            filename: "settings-timeline-drag-live-time.png"
        )
    }

    private func capture(
        model: AppModel,
        settingsStore: SettingsStore,
        timelineDragPreview: Bool,
        scrollFraction: CGFloat,
        filename: String
    ) throws {
        let size = CGSize(width: 393, height: 852)
        let view = SettingsView(
            snapshotModel: model,
            settingsStore: settingsStore,
            screenTimeAuthorized: true,
            timelineDragPreview: timelineDragPreview,
            onResetOnboarding: {}
        )
        .frame(width: size.width, height: size.height)

        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.isHidden = false
        window.layoutIfNeeded()

        let appeared = expectation(description: "Settings appeared")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            appeared.fulfill()
        }
        wait(for: [appeared], timeout: 1)
        window.layoutIfNeeded()

        let scrollView = try XCTUnwrap(firstScrollView(in: controller.view))
        let maximumOffset = max(
            0,
            scrollView.contentSize.height - scrollView.adjustedContentInset.top
                - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
        )
        scrollView.setContentOffset(
            CGPoint(x: 0, y: maximumOffset * scrollFraction),
            animated: false
        )
        window.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            controller.view.drawHierarchy(
                in: CGRect(origin: .zero, size: size),
                afterScreenUpdates: true
            )
        }

        let outputDirectory = projectRootURL.appendingPathComponent("output/verify", isDirectory: true)
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        let outputURL = outputDirectory.appendingPathComponent(filename)
        try XCTUnwrap(image.pngData()).write(to: outputURL, options: .atomic)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        window.isHidden = true
        window.rootViewController = nil
    }

    private func firstScrollView(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView {
            return scrollView
        }
        for subview in view.subviews {
            if let scrollView = firstScrollView(in: subview) {
                return scrollView
            }
        }
        return nil
    }

    private func makeFixture() throws -> (
        model: AppModel,
        settingsStore: SettingsStore,
        cleanup: () -> Void
    ) {
        let containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SettingsDeviceFixesSnapshot-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)

        let suiteName = "SettingsDeviceFixesSnapshot-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let settingsStore = SettingsStore(userDefaults: defaults)
        settingsStore.entitlementCachedIsPro = true
        settingsStore.pendingInterventionMode = InterventionMode.deepFocus.rawValue
        settingsStore.wakeTimeMinutes = 420
        settingsStore.bedTimeMinutes = 1_380

        let model = AppModel(
            containerProvider: SettingsDeviceFixesSnapshotContainer(url: containerURL),
            settingsStore: settingsStore,
            automaticallyRefreshEntitlement: false,
            scheduleNotificationsOnInit: false
        )
        return (
            model,
            settingsStore,
            {
                defaults.removePersistentDomain(forName: suiteName)
                try? FileManager.default.removeItem(at: containerURL)
            }
        )
    }

    private var projectRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private struct HomeBlockSettingsLandingHarness: View {
    let model: AppModel
    let settingsStore: SettingsStore
    let onBlockSettingsActionReady: ((@escaping () -> Void) -> Void)
    @State private var selectedTab: AppTab = .settings
    @State private var hasWarmedSettings = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                model: model,
                settingsStore: settingsStore,
                onOpenBlockSettings: {
                    selectedTab = .settings
                    model.pendingDeepFocusSettingsFocus = true
                },
                onBlockSettingsActionReady: onBlockSettingsActionReady
            )
            .tag(AppTab.home)
            .tabItem { Label("ホーム", systemImage: "house") }

            SettingsView(
                snapshotModel: model,
                settingsStore: settingsStore,
                screenTimeAuthorized: true,
                onResetOnboarding: {}
            )
            .tag(AppTab.settings)
            .tabItem { Label("設定", systemImage: "gearshape") }
            .onAppear {
                guard !hasWarmedSettings else { return }
                hasWarmedSettings = true
                Task { @MainActor in
                    await Task.yield()
                    selectedTab = .home
                }
            }
        }
        .environment(\.locale, Locale(identifier: "ja_JP"))
        .preferredColorScheme(.dark)
    }
}

private struct SettingsDeviceFixesSnapshotContainer: ContainerProviding {
    let url: URL

    func containerURL() throws -> URL {
        url
    }
}
