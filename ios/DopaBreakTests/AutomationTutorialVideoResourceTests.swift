import AVFoundation
import SwiftUI
import UIKit
import XCTest

@testable import DopaBreak

final class AutomationTutorialVideoResourceTests: XCTestCase {
    func testAllActualScreenshotsAreBundledAtCaptureResolution() throws {
        for language in ["ja", "en", "ko"] {
            for step in 1...7 {
                let name = automationTutorialScreenshotResourceName(step: step, for: language)
                let image = try XCTUnwrap(UIImage(named: name)?.cgImage, name)
                XCTAssertEqual(image.width, 1206, name)
                XCTAssertEqual(image.height, 2622, name)
            }
        }
    }

    func testAllRecordedVideosArePlayable() async throws {
        for language in ["ja", "en", "ko"] {
            let name = automationTutorialVideoResourceName(for: language)
            let url = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "mp4"), name)
            let asset = AVURLAsset(url: url)
            let playable = try await asset.load(.isPlayable)
            let duration = try await asset.load(.duration)
            XCTAssertTrue(playable, name)
            XCTAssertGreaterThan(duration.seconds, 20, name)
            XCTAssertLessThan(duration.seconds, 180, name)
        }
    }

    @MainActor
    func testCaptureGuideWithActualScreenshots() throws {
        let playback = AutomationTutorialPlaybackController()
        let controller = UIHostingController(rootView:
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    AutomationGuideStepList(playbackController: playback)
                }
                .padding(20)
            }
            .dopaScreenBackground()
            .preferredColorScheme(.dark)
        )
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        window.windowLevel = .alert + 1
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            playback.guideDidDisappear()
            window.isHidden = true
            window.rootViewController = nil
        }
        let appeared = expectation(description: "Guide laid out")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { appeared.fulfill() }
        wait(for: [appeared], timeout: 3)
        func scrollView(in view: UIView) -> UIScrollView? {
            if let scroll = view as? UIScrollView { return scroll }
            return view.subviews.lazy.compactMap { scrollView(in: $0) }.first
        }
        let scroll = try XCTUnwrap(scrollView(in: controller.view))
        XCTAssertGreaterThan(scroll.contentSize.height, window.bounds.height)
        scroll.setContentOffset(CGPoint(x: 0, y: 560), animated: false)
        window.layoutIfNeeded()
        let settled = expectation(description: "Screenshot card visible")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settled.fulfill() }
        wait(for: [settled], timeout: 2)
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let screenshot = renderer.image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
        let attachment = XCTAttachment(image: screenshot)
        attachment.name = "automation-guide-actual-screenshots"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testJapaneseUsesJapaneseVideo() {
        XCTAssertEqual(
            automationTutorialVideoResourceName(for: "ja"),
            "automation-tutorial-ja"
        )
    }

    func testKoreanUsesKoreanVideo() {
        XCTAssertEqual(
            automationTutorialVideoResourceName(for: "ko"),
            "automation-tutorial-ko"
        )
    }

    func testEnglishUsesEnglishVideo() {
        XCTAssertEqual(
            automationTutorialVideoResourceName(for: "en"),
            "automation-tutorial-en"
        )
    }

    func testUnknownLanguageFallsBackToEnglishVideo() {
        XCTAssertEqual(
            automationTutorialVideoResourceName(for: "fr"),
            "automation-tutorial-en"
        )
    }

    func testNilLanguageFallsBackToEnglishVideo() {
        XCTAssertEqual(
            automationTutorialVideoResourceName(for: nil),
            "automation-tutorial-en"
        )
    }

    func testUppercaseJapaneseUsesJapaneseVideo() {
        XCTAssertEqual(
            automationTutorialVideoResourceName(for: "JA"),
            "automation-tutorial-ja"
        )
    }
}
