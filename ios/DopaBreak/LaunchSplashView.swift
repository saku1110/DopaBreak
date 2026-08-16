import AVFoundation
import Combine
import SwiftUI
import UIKit

enum LaunchSplashLaunchContext: Equatable {
    case coldLaunch
    case backgroundResume
}

enum LaunchSplashCompletionReason: Equatable {
    case playbackCompleted
    case userSkipped
    case resourceUnavailable
    case playbackFailed
    case startupTimedOut
    case maximumDurationReached
    case reduceMotion
    case voiceOver
    case backgroundResume
    case displayPolicy
    case deepLink
}

enum LaunchSplashPresentationDecision: Equatable {
    case present
    case skip(LaunchSplashCompletionReason)
}

enum LaunchSplashDisplayPolicy: Equatable {
    case everyColdLaunch
    case firstColdLaunchOnly

    func presentationDecision(
        for launchContext: LaunchSplashLaunchContext,
        reduceMotion: Bool,
        voiceOverRunning: Bool = false,
        hasShownBefore: Bool
    ) -> LaunchSplashPresentationDecision {
        guard launchContext == .coldLaunch else {
            return .skip(.backgroundResume)
        }
        guard !reduceMotion else {
            return .skip(.reduceMotion)
        }
        guard !voiceOverRunning else {
            return .skip(.voiceOver)
        }

        switch self {
        case .everyColdLaunch:
            return .present
        case .firstColdLaunchOnly:
            return hasShownBefore ? .skip(.displayPolicy) : .present
        }
    }
}

enum LaunchSplashEvent: Equatable {
    case playbackStarted
    case playbackCompleted
    case userSkipped
    case resourceUnavailable
    case playbackFailed
    case startupTimedOut
    case maximumDurationReached
}

struct LaunchSplashStateMachine: Equatable {
    enum Phase: Equatable {
        case waitingForPlayback
        case playing
        case completed(LaunchSplashCompletionReason)
    }

    private(set) var phase: Phase

    init(presentationDecision: LaunchSplashPresentationDecision) {
        switch presentationDecision {
        case .present:
            phase = .waitingForPlayback
        case let .skip(reason):
            phase = .completed(reason)
        }
    }

    var isCompleted: Bool {
        if case .completed = phase {
            return true
        }
        return false
    }

    @discardableResult
    mutating func handle(_ event: LaunchSplashEvent) -> LaunchSplashCompletionReason? {
        guard !isCompleted else {
            return nil
        }

        if event == .playbackStarted {
            guard phase == .waitingForPlayback else {
                return nil
            }
            phase = .playing
            return nil
        }

        let completionReason: LaunchSplashCompletionReason
        switch event {
        case .playbackStarted:
            return nil
        case .playbackCompleted:
            completionReason = .playbackCompleted
        case .userSkipped:
            completionReason = .userSkipped
        case .resourceUnavailable:
            completionReason = .resourceUnavailable
        case .playbackFailed:
            completionReason = .playbackFailed
        case .startupTimedOut:
            completionReason = .startupTimedOut
        case .maximumDurationReached:
            completionReason = .maximumDurationReached
        }

        phase = .completed(completionReason)
        return completionReason
    }
}

enum LaunchSplashConfiguration {
    /// Change this one constant to `.firstColdLaunchOnly` if the owner changes the policy.
    static let displayPolicy: LaunchSplashDisplayPolicy = .everyColdLaunch

    static let videoResourceName = "launch-animation"
    static let firstLaunchShownKey = "dopabreak.launchSplash.hasShown"
    static let videoDuration: TimeInterval = 3.0
    static let playbackCompletionMargin: TimeInterval = 0.4
    /// Guards startup only. Keep this shorter than `maximumPlaybackDuration`.
    static let startupTimeout: TimeInterval = 0.8
    /// Starts at `.playbackStarted` and must cover the video plus its completion margin.
    static let maximumPlaybackDuration: TimeInterval = videoDuration + playbackCompletionMargin
    static let crossfadeDuration: TimeInterval = 0.25

    static var crossfadeAnimation: Animation {
        .easeOut(duration: crossfadeDuration)
    }
}

private enum LaunchSplashPalette {
    static let background = Color(
        red: 11.0 / 255.0,
        green: 13.0 / 255.0,
        blue: 15.0 / 255.0
    )
    static let uiBackground = UIColor(
        red: 11.0 / 255.0,
        green: 13.0 / 255.0,
        blue: 15.0 / 255.0,
        alpha: 1
    )
}

final class LaunchSplashCoordinator: ObservableObject {
    @Published private(set) var completionReason: LaunchSplashCompletionReason?

    private let displayPolicy: LaunchSplashDisplayPolicy
    private let launchContext: LaunchSplashLaunchContext
    private let userDefaults: UserDefaults
    private let hadShownBeforeLaunch: Bool
    private var didRecordPresentation = false

    init(
        displayPolicy: LaunchSplashDisplayPolicy = LaunchSplashConfiguration.displayPolicy,
        launchContext: LaunchSplashLaunchContext = .coldLaunch,
        userDefaults: UserDefaults = .standard
    ) {
        self.displayPolicy = displayPolicy
        self.launchContext = launchContext
        self.userDefaults = userDefaults
        self.hadShownBeforeLaunch = userDefaults.bool(
            forKey: LaunchSplashConfiguration.firstLaunchShownKey
        )
    }

    func presentationDecision(
        reduceMotion: Bool,
        voiceOverRunning: Bool = false
    ) -> LaunchSplashPresentationDecision {
        if let completionReason {
            return .skip(completionReason)
        }
        return displayPolicy.presentationDecision(
            for: launchContext,
            reduceMotion: reduceMotion,
            voiceOverRunning: voiceOverRunning,
            hasShownBefore: hadShownBeforeLaunch
        )
    }

    func recordPresentationIfNeeded() {
        guard !didRecordPresentation else {
            return
        }
        didRecordPresentation = true

        guard displayPolicy == .firstColdLaunchOnly else {
            return
        }
        userDefaults.set(true, forKey: LaunchSplashConfiguration.firstLaunchShownKey)
    }

    func complete(_ reason: LaunchSplashCompletionReason) {
        guard completionReason == nil else {
            return
        }
        completionReason = reason
    }
}

struct LaunchSplashHost<Content: View>: View {
    @ObservedObject var coordinator: LaunchSplashCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private let content: Content

    init(
        coordinator: LaunchSplashCoordinator,
        @ViewBuilder content: () -> Content
    ) {
        self.coordinator = coordinator
        self.content = content()
    }

    private var presentationDecision: LaunchSplashPresentationDecision {
        coordinator.presentationDecision(
            reduceMotion: reduceMotion,
            voiceOverRunning: UIAccessibility.isVoiceOverRunning
        )
    }

    private var isPresentingSplash: Bool {
        presentationDecision == .present
    }

    var body: some View {
        ZStack {
            content
                .allowsHitTesting(!isPresentingSplash)
                .accessibilityHidden(isPresentingSplash)

            if isPresentingSplash {
                LaunchSplashView { reason in
                    withAnimation(LaunchSplashConfiguration.crossfadeAnimation) {
                        coordinator.complete(reason)
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .background(LaunchSplashPalette.background)
        .onAppear {
            resolveInitialPresentationDecision()
        }
        .onChange(of: reduceMotion) { _, isReduceMotionEnabled in
            guard isReduceMotionEnabled else {
                return
            }
            coordinator.complete(.reduceMotion)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIAccessibility.voiceOverStatusDidChangeNotification
            )
        ) { _ in
            guard UIAccessibility.isVoiceOverRunning else {
                return
            }
            coordinator.complete(.voiceOver)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .background else {
                return
            }
            // Once a cold-launch splash is interrupted, never replay it on resume.
            withAnimation(LaunchSplashConfiguration.crossfadeAnimation) {
                coordinator.complete(.backgroundResume)
            }
        }
    }

    private func resolveInitialPresentationDecision() {
        switch presentationDecision {
        case .present:
            coordinator.recordPresentationIfNeeded()
        case let .skip(reason):
            coordinator.complete(reason)
        }
    }
}

struct LaunchSplashView: View {
    @StateObject private var playbackController: LaunchSplashPlaybackController
    private let onCompletion: (LaunchSplashCompletionReason) -> Void

    init(onCompletion: @escaping (LaunchSplashCompletionReason) -> Void) {
        _playbackController = StateObject(
            wrappedValue: LaunchSplashPlaybackController()
        )
        self.onCompletion = onCompletion
    }

    var body: some View {
        ZStack {
            LaunchSplashPalette.background

            LaunchSplashPlayerSurface(playbackController: playbackController)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            playbackController.skip()
        }
        .onAppear {
            playbackController.start(onCompletion: onCompletion)
        }
        .onDisappear {
            playbackController.stop()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private final class LaunchSplashPlaybackController: NSObject, ObservableObject {
    private let player: AVPlayer?
    private let playerItem: AVPlayerItem?
    private var stateMachine = LaunchSplashStateMachine(presentationDecision: .present)
    private var completionHandler: ((LaunchSplashCompletionReason) -> Void)?
    private var didStart = false

    private var playerStatusObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var playbackEndObserver: NSObjectProtocol?
    private var playbackFailureObserver: NSObjectProtocol?
    private var startupTimeoutWorkItem: DispatchWorkItem?
    private var maximumDurationWorkItem: DispatchWorkItem?
    private weak var attachedPlayerLayer: AVPlayerLayer?

    override init() {
        let bundledVideoURL = Bundle.main.url(
            forResource: LaunchSplashConfiguration.videoResourceName,
            withExtension: "mp4"
        ) ?? Bundle.main.url(
            forResource: LaunchSplashConfiguration.videoResourceName,
            withExtension: "mp4",
            subdirectory: "Resources"
        )

        if let bundledVideoURL {
            let playerItem = AVPlayerItem(url: bundledVideoURL)
            let player = AVPlayer(playerItem: playerItem)
            player.isMuted = true
            player.volume = 0
            player.automaticallyWaitsToMinimizeStalling = false
            player.actionAtItemEnd = .pause
            player.preventsDisplaySleepDuringVideoPlayback = false
            self.playerItem = playerItem
            self.player = player
        } else {
            self.playerItem = nil
            self.player = nil
        }

        super.init()
    }

    deinit {
        stop()
    }

    func start(onCompletion: @escaping (LaunchSplashCompletionReason) -> Void) {
        guard !didStart else {
            return
        }
        didStart = true
        completionHandler = onCompletion

        guard let player, let playerItem else {
            process(.resourceUnavailable)
            return
        }

        installObservers(player: player, playerItem: playerItem)
        scheduleStartupTimeout()
        player.play()
    }

    func skip() {
        process(.userSkipped)
    }

    func stop() {
        player?.pause()
        cancelFailSafeTimers()
        removeObservers()
        completionHandler = nil
    }

    func attach(to playerLayer: AVPlayerLayer) {
        guard attachedPlayerLayer !== playerLayer else {
            return
        }

        attachedPlayerLayer?.player = nil
        attachedPlayerLayer = playerLayer
        playerLayer.backgroundColor = LaunchSplashPalette.uiBackground.cgColor
        playerLayer.videoGravity = .resizeAspect
        playerLayer.player = player
    }

    func detach(from playerLayer: AVPlayerLayer) {
        guard attachedPlayerLayer === playerLayer else {
            return
        }
        playerLayer.player = nil
        attachedPlayerLayer = nil
    }

    private func installObservers(player: AVPlayer, playerItem: AVPlayerItem) {
        playerStatusObservation = player.observe(
            \.status,
            options: [.initial, .new]
        ) { [weak self] observedPlayer, _ in
            guard observedPlayer.status == .failed else {
                return
            }
            DispatchQueue.main.async {
                self?.process(.playbackFailed)
            }
        }

        itemStatusObservation = playerItem.observe(
            \.status,
            options: [.initial, .new]
        ) { [weak self] observedItem, _ in
            guard observedItem.status == .failed else {
                return
            }
            DispatchQueue.main.async {
                self?.process(.playbackFailed)
            }
        }

        timeControlObservation = player.observe(
            \.timeControlStatus,
            options: [.initial, .new]
        ) { [weak self] observedPlayer, _ in
            guard observedPlayer.timeControlStatus == .playing else {
                return
            }
            DispatchQueue.main.async {
                self?.process(.playbackStarted)
            }
        }

        playbackEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.process(.playbackCompleted)
        }

        playbackFailureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.process(.playbackFailed)
        }
    }

    private func scheduleStartupTimeout() {
        let startupTimeoutWorkItem = DispatchWorkItem { [weak self] in
            self?.process(.startupTimedOut)
        }
        self.startupTimeoutWorkItem = startupTimeoutWorkItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + LaunchSplashConfiguration.startupTimeout,
            execute: startupTimeoutWorkItem
        )
    }

    private func scheduleMaximumPlaybackDuration() {
        let maximumDurationWorkItem = DispatchWorkItem { [weak self] in
            self?.process(.maximumDurationReached)
        }
        self.maximumDurationWorkItem = maximumDurationWorkItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + LaunchSplashConfiguration.maximumPlaybackDuration,
            execute: maximumDurationWorkItem
        )
    }

    private func process(_ event: LaunchSplashEvent) {
        let phaseBeforeEvent = stateMachine.phase
        let completionReason = stateMachine.handle(event)

        if event == .playbackStarted,
           phaseBeforeEvent == .waitingForPlayback,
           stateMachine.phase == .playing {
            startupTimeoutWorkItem?.cancel()
            startupTimeoutWorkItem = nil
            scheduleMaximumPlaybackDuration()
        }

        guard let reason = completionReason else {
            return
        }

        player?.pause()
        cancelFailSafeTimers()
        removeObservers()

        let handler = completionHandler
        completionHandler = nil
        handler?(reason)
    }

    private func cancelFailSafeTimers() {
        startupTimeoutWorkItem?.cancel()
        startupTimeoutWorkItem = nil
        maximumDurationWorkItem?.cancel()
        maximumDurationWorkItem = nil
    }

    private func removeObservers() {
        playerStatusObservation?.invalidate()
        playerStatusObservation = nil
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil

        if let playbackEndObserver {
            NotificationCenter.default.removeObserver(playbackEndObserver)
            self.playbackEndObserver = nil
        }
        if let playbackFailureObserver {
            NotificationCenter.default.removeObserver(playbackFailureObserver)
            self.playbackFailureObserver = nil
        }
    }
}

private final class LaunchSplashPlayerUIView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    private weak var playbackController: LaunchSplashPlaybackController?

    private var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = LaunchSplashPalette.uiBackground
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with playbackController: LaunchSplashPlaybackController) {
        self.playbackController = playbackController
        playbackController.attach(to: playerLayer)
    }

    func detachPlayer() {
        playbackController?.detach(from: playerLayer)
        playbackController = nil
    }
}

private struct LaunchSplashPlayerSurface: UIViewRepresentable {
    let playbackController: LaunchSplashPlaybackController

    func makeUIView(context: Context) -> LaunchSplashPlayerUIView {
        let playerView = LaunchSplashPlayerUIView()
        playerView.configure(with: playbackController)
        return playerView
    }

    func updateUIView(_ playerView: LaunchSplashPlayerUIView, context: Context) {
        playerView.configure(with: playbackController)
    }

    static func dismantleUIView(
        _ playerView: LaunchSplashPlayerUIView,
        coordinator: Void
    ) {
        playerView.detachPlayer()
    }
}
