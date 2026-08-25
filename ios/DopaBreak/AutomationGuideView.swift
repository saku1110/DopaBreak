import AVFoundation
import AVKit
import DopaBreakCore
import SwiftUI
import UIKit

func automationTutorialVideoResourceName(for languageCode: String?) -> String {
    switch languageCode?.lowercased() {
    case "ja":
        return "automation-tutorial-ja"
    case "ko":
        return "automation-tutorial-ko"
    default:
        return "automation-tutorial-en"
    }
}

/// ショートカットのオートメーション設定ガイド（doc12 §4 / doc11 §4c）。
/// 対象アプリから介入Intentが発火した事実を設定済み判定として表示する。
struct AutomationGuideView: View {
    let model: AppModel
    let settingsStore: SettingsStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var tutorialPlayback = AutomationTutorialPlaybackController()
    @State private var selectedTargets: [SNSAppCatalogItem] = []
    @State private var verifiedAutomationCatalogIDs: Set<String> = []
    @State private var didFailToLoadSelectedTargets = false
    @State private var isShortcutsMissingAlertPresented = false

    private var progress: AutomationVerification.Progress {
        AutomationVerification.progress(
            selectedCatalogIDs: selectedTargets.map(\.catalogID),
            verifiedCatalogIDs: Array(verifiedAutomationCatalogIDs)
        )
    }

    private var persistedInterventionMode: InterventionMode {
        guard let rawValue = settingsStore.pendingInterventionMode,
              let mode = InterventionMode(rawValue: rawValue) else {
            return .standard
        }
        return mode
    }

    private var shouldShowGrayscaleGuidance: Bool {
        persistedInterventionMode == .deepFocus
    }

    private var shouldShowVideoTutorial: Bool {
        tutorialPlayback.isAvailable
    }

    private var guideSteps: [AutomationGuideStep] {
        [
            AutomationGuideStep(
                number: 1,
                instruction: String(
                    localized: "automation_guide.step.1",
                    defaultValue: "ショートカットApp下部の「オートメーション」を選ぶ"
                ),
                diagram: .automationTab
            ),
            AutomationGuideStep(
                number: 2,
                instruction: String(
                    localized: "automation_guide.step.2",
                    defaultValue: "右上の＋で新規オートメーションを作る"
                ),
                diagram: .newAutomation
            ),
            AutomationGuideStep(
                number: 3,
                instruction: String(
                    localized: "automation_guide.step.3",
                    defaultValue: "「アプリ」を選ぶ"
                ),
                diagram: .appTrigger
            ),
            AutomationGuideStep(
                number: 4,
                instruction: String(
                    localized: "automation_guide.step.4",
                    defaultValue: "対象アプリを選び、「開いている」と「すぐに実行」を選び、「実行時に通知」はオフのまま「次へ」"
                ),
                diagram: .triggerOptions
            ),
            AutomationGuideStep(
                number: 5,
                instruction: String(
                    localized: "automation_guide.step.5",
                    defaultValue: "「新規ショートカットを作成」をタップ"
                ),
                diagram: .blankAutomation
            ),
            AutomationGuideStep(
                number: 6,
                instruction: String(
                    localized: "automation_guide.step.6",
                    defaultValue: "シート下部のアプリ一覧で「DopaBreak」→「DopaBreakで一呼吸」を選ぶ（検索でも可）"
                ),
                diagram: .dopabreakAction
            ),
            AutomationGuideStep(
                number: 7,
                instruction: String(
                    localized: "automation_guide.step.7",
                    defaultValue: "アクション内の「アプリ」で対象アプリを選び、右上のチェックで完了"
                ),
                diagram: .finishAction
            )
        ]
    }

    private var grayscaleGuideSteps: [GrayscaleGuideStep] {
        let appsTitle = String(
            localized: "automation_guide.grayscale.mock.apps",
            defaultValue: "対象アプリをまとめて選択"
        )
        let colorFiltersTitle = String(
            localized: "automation_guide.grayscale.mock.color_filters",
            defaultValue: "カラーフィルタを設定"
        )

        return [
            GrayscaleGuideStep(
                number: 1,
                instruction: String(
                    localized: "automation_guide.grayscale.step.1",
                    defaultValue: "新規オートメーションで「アプリ」を選び、対象アプリをまとめて全部選んで「開いている」と「すぐに実行」を選び「次へ」"
                ),
                diagram: GrayscaleAutomationDiagram(
                    rows: [
                        GrayscaleAutomationDiagram.Row(
                            symbol: "square.stack.3d.up.fill",
                            title: appsTitle,
                            subtitle: String(
                                localized: "automation_guide.mock.opened",
                                defaultValue: "開いている"
                            ),
                            trailingSymbol: "checkmark.circle.fill"
                        )
                    ],
                    showsNextButton: true
                )
            ),
            GrayscaleGuideStep(
                number: 2,
                instruction: String(
                    localized: "automation_guide.grayscale.step.2",
                    defaultValue: "アクション「カラーフィルタを設定」を選び「オン」にして完了"
                ),
                diagram: GrayscaleAutomationDiagram(
                    rows: [
                        GrayscaleAutomationDiagram.Row(
                            symbol: "circle.lefthalf.filled",
                            title: colorFiltersTitle,
                            subtitle: String(
                                localized: "automation_guide.grayscale.mock.on",
                                defaultValue: "オン"
                            ),
                            trailingSymbol: "checkmark.circle.fill"
                        )
                    ],
                    showsNextButton: false
                )
            ),
            GrayscaleGuideStep(
                number: 3,
                instruction: String(
                    localized: "automation_guide.grayscale.step.3",
                    defaultValue: "もう1つ作り「閉じている」で同じアプリを選び「カラーフィルタを設定」を「オフ」にする"
                ),
                diagram: GrayscaleAutomationDiagram(
                    rows: [
                        GrayscaleAutomationDiagram.Row(
                            symbol: "square.stack.3d.up.fill",
                            title: appsTitle,
                            subtitle: String(
                                localized: "automation_guide.grayscale.mock.closed",
                                defaultValue: "閉じている"
                            ),
                            trailingSymbol: "checkmark.circle.fill"
                        ),
                        GrayscaleAutomationDiagram.Row(
                            symbol: "circle.lefthalf.filled",
                            title: colorFiltersTitle,
                            subtitle: String(
                                localized: "automation_guide.grayscale.mock.off",
                                defaultValue: "オフ"
                            ),
                            trailingSymbol: "circle"
                        )
                    ],
                    showsNextButton: false
                )
            )
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    Text(String(localized: "automation_guide.title", defaultValue: "自動で一呼吸を出す設定"))
                        .dopaFont(28, weight: .black, tracking: -0.5, lineSpacing: 3)
                        .foregroundStyle(DesignTokens.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    progressView

                    Button {
                        openShortcutsApp()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.up.forward.app.fill")
                                .accessibilityHidden(true)
                            Text(String(localized: "automation_guide.action.open_shortcuts", defaultValue: "ショートカットを開く"))
                            Spacer(minLength: 8)
                            Image(systemName: "arrow.up.right")
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 18)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    if shouldShowVideoTutorial {
                        AutomationTutorialVideoCard(playbackController: tutorialPlayback)
                    }

                    Text(String(localized: "automation_guide.guide.section", defaultValue: "設定手順"))
                        .dopaFont(21, weight: .black, tracking: -0.25)
                        .foregroundStyle(DesignTokens.primaryText)

                    ForEach(guideSteps) { step in
                        AutomationStepCard(step: step)
                    }

                    checklistSection
                    finalConfirmationCard

                    if shouldShowGrayscaleGuidance {
                        grayscaleGuidanceSection
                    }
                }
                .padding(.horizontal, DesignTokens.horizontalPadding)
                .padding(.top, 24)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
            .dopaScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "automation_guide.action.close", defaultValue: "閉じる")) {
                        dismiss()
                    }
                    .dopaFont(15, weight: .semibold)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .dopaHitTarget()
                }
            }
        }
        .tint(DesignTokens.accent)
        .preferredColorScheme(.dark)
        .alert(
            String(
                localized: "automation_guide.shortcuts_missing.title",
                defaultValue: "ショートカットAppが見つかりません"
            ),
            isPresented: $isShortcutsMissingAlertPresented
        ) {
            Button(
                String(
                    localized: "automation_guide.action.open_app_store",
                    defaultValue: "App Storeを開く"
                )
            ) {
                openShortcutsAppStore()
            }
            Button(
                String(localized: "automation_guide.action.cancel", defaultValue: "キャンセル"),
                role: .cancel
            ) {}
        } message: {
            Text(
                String(
                    localized: "automation_guide.shortcuts_missing.message",
                    defaultValue: "App Storeから再インストールしてください。"
                )
            )
        }
        .onAppear {
            tutorialPlayback.guideDidAppear(reduceMotion: reduceMotion)
            refreshGuideState()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                tutorialPlayback.applicationDidBecomeActive()
                refreshGuideStateAfterActivation()
            case .background:
                tutorialPlayback.applicationDidEnterBackground()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .onDisappear {
            tutorialPlayback.guideDidDisappear()
        }
    }

    private var progressView: some View {
        let progressText = String(
            localized: "automation_guide.progress",
            defaultValue: "\(progress.verifiedCount)/\(progress.totalCount) 設定済み"
        )

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .dopaFont(16, weight: .bold)
                    .foregroundStyle(DesignTokens.accent)
                    .accessibilityHidden(true)

                Text(progressText)
                    .dopaFont(17, weight: .bold)
                    .foregroundStyle(DesignTokens.primaryText)
            }

            ProgressView(
                value: Double(progress.verifiedCount),
                total: Double(max(progress.totalCount, 1))
            )
            .tint(DesignTokens.accent)
            .accessibilityHidden(true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.backgroundRaised)
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.cardRadius, style: .continuous)
                .stroke(DesignTokens.strongHairline, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cardRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progressText)
    }

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "automation_guide.checklist.section", defaultValue: "アプリ別チェックリスト"))
                .dopaFont(21, weight: .black, tracking: -0.25)
                .foregroundStyle(DesignTokens.primaryText)

            CardContainer {
                VStack(alignment: .leading, spacing: 0) {
                    if didFailToLoadSelectedTargets {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .dopaFont(15, weight: .bold)
                                .foregroundStyle(DesignTokens.danger)
                                .accessibilityHidden(true)

                            Text(
                                String(
                                    localized: "automation_guide.apps.load_error",
                                    defaultValue: "対象アプリを読み込めませんでした"
                                )
                            )
                            .dopaFont(15, weight: .semibold, lineSpacing: 4)
                            .foregroundStyle(DesignTokens.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(minHeight: DesignTokens.minTapTarget, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    } else if selectedTargets.isEmpty {
                        Text(String(localized: "automation_guide.apps.empty", defaultValue: "先に止めるアプリを選んでください。"))
                            .dopaFont(15, weight: .semibold, lineSpacing: 4)
                            .foregroundStyle(DesignTokens.secondaryText)
                            .frame(minHeight: DesignTokens.minTapTarget, alignment: .leading)
                    } else {
                        ForEach(Array(selectedTargets.enumerated()), id: \.element.id) { index, target in
                            if index > 0 {
                                Rectangle()
                                    .fill(DesignTokens.hairline)
                                    .frame(height: 1)
                                    .padding(.vertical, 8)
                                    .accessibilityHidden(true)
                            }
                            automationChecklistRow(target)
                        }
                    }
                }
            }
        }
    }

    private var finalConfirmationCard: some View {
        CardContainer {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "checkmark.seal.fill")
                    .dopaFont(21, weight: .bold)
                    .foregroundStyle(DesignTokens.accent)
                    .frame(width: 32, height: 32)
                    .background(DesignTokens.accent.opacity(0.12))
                    .clipShape(Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "automation_guide.final.section", defaultValue: "最終確認"))
                        .dopaFont(16, weight: .bold)
                        .foregroundStyle(DesignTokens.primaryText)

                    Text(
                        String(
                            localized: "automation_guide.final.body",
                            defaultValue: "対象アプリを開いて一呼吸が出れば設定完了です"
                        )
                    )
                    .dopaFont(15, weight: .semibold, lineSpacing: 4)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var grayscaleGuidanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(
                    String(
                        localized: "automation_guide.grayscale.section",
                        defaultValue: "画面を白黒にする（任意）"
                    )
                )
                .dopaFont(21, weight: .black, tracking: -0.25)
                .foregroundStyle(DesignTokens.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

                SmallLabel(
                    text: String(
                        localized: "automation_guide.grayscale.label",
                        defaultValue: "Deep Focus向け"
                    )
                )

                Text(
                    String(
                        localized: "automation_guide.grayscale.lead",
                        defaultValue: "SNSから色を消すと刺激が減り、見続ける力が弱まります。Deep Focusと相性のいい追加設定です。"
                    )
                )
                .dopaFont(15, weight: .semibold, lineSpacing: 4)
                .foregroundStyle(DesignTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(grayscaleGuideSteps) { step in
                GrayscaleAutomationStepCard(step: step)
            }

            CardContainer {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "hand.tap.fill")
                        .dopaFont(17, weight: .bold)
                        .foregroundStyle(DesignTokens.accent)
                        .frame(width: 32, height: 32)
                        .background(DesignTokens.accent.opacity(0.12))
                        .clipShape(Circle())
                        .accessibilityHidden(true)

                    Text(
                        String(
                            localized: "automation_guide.grayscale.manual",
                            defaultValue: "自動化しない場合: 設定→アクセシビリティ→ショートカット→カラーフィルタをオン。以後サイドボタン（ホームボタンがある機種はホームボタン）を3回押すと、白黒とカラーを切り替えられます。"
                        )
                    )
                    .dopaFont(14, weight: .semibold, lineSpacing: 4)
                    .foregroundStyle(DesignTokens.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }

            Text(
                String(
                    localized: "automation_guide.grayscale.note",
                    defaultValue: "アクション名・トリガー名はiOSのバージョンで表記が変わることがあります。"
                )
            )
            .dopaFont(12, weight: .medium, lineSpacing: 3)
            .foregroundStyle(DesignTokens.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func automationChecklistRow(_ target: SNSAppCatalogItem) -> some View {
        let isVerified = verifiedAutomationCatalogIDs.contains(target.catalogID)
        let statusText = isVerified
            ? String(localized: "automation_guide.status.verified", defaultValue: "設定済み")
            : String(localized: "automation_guide.status.not_configured", defaultValue: "未設定")
        let accessibilityText = String(
            localized: "automation_guide.app.accessibility_label",
            defaultValue: "\(target.displayName) \(statusText)"
        )

        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                checklistAppIdentity(target)
                Spacer(minLength: 12)
                automationStatus(isVerified: isVerified, text: statusText)
            }

            VStack(alignment: .leading, spacing: 8) {
                checklistAppIdentity(target)
                automationStatus(isVerified: isVerified, text: statusText)
                    .padding(.leading, 46)
            }
        }
        .frame(maxWidth: .infinity, minHeight: DesignTokens.minTapTarget, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func checklistAppIdentity(_ target: SNSAppCatalogItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: target.symbolName)
                .dopaFont(15, weight: .semibold)
                .foregroundStyle(DesignTokens.accent)
                .frame(width: 36, height: 36)
                .background(DesignTokens.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(target.displayName)
                .dopaFont(16, weight: .bold)
                .foregroundStyle(DesignTokens.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func automationStatus(isVerified: Bool, text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .dopaFont(13, weight: .bold)

            Image(systemName: isVerified ? "checkmark.circle.fill" : "circle")
                .dopaFont(15, weight: .bold)
                .accessibilityHidden(true)
        }
        .foregroundStyle(isVerified ? DesignTokens.accent : DesignTokens.secondaryText)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func openShortcutsApp() {
        tutorialPlayback.prepareForExternalTransition()

        guard let url = URL(string: "shortcuts://") else {
            tutorialPlayback.cancelExternalTransitionPreparation()
            isShortcutsMissingAlertPresented = true
            return
        }
        UIApplication.shared.open(url, options: [:]) { didOpen in
            guard !didOpen else {
                return
            }
            Task { @MainActor in
                tutorialPlayback.cancelExternalTransitionPreparation()
                isShortcutsMissingAlertPresented = true
            }
        }
    }

    private func openShortcutsAppStore() {
        guard let url = URL(string: "https://apps.apple.com/app/id915249334") else {
            return
        }
        UIApplication.shared.open(url)
    }

    private func refreshGuideState() {
        do {
            selectedTargets = try model.targetStore.selectedTargets()
            didFailToLoadSelectedTargets = false
        } catch {
            selectedTargets = []
            didFailToLoadSelectedTargets = true
        }
        verifiedAutomationCatalogIDs = Set(settingsStore.verifiedAutomationCatalogIDs)
    }

    private func refreshGuideStateAfterActivation() {
        refreshGuideState()
        Task { @MainActor in
            await Task.yield()
            refreshGuideState()
        }
    }
}

private struct AutomationGuideStep: Identifiable {
    let number: Int
    let instruction: String
    let diagram: AutomationMockDiagramKind

    var id: Int { number }
}

private struct GrayscaleGuideStep: Identifiable {
    let number: Int
    let instruction: String
    let diagram: GrayscaleAutomationDiagram

    var id: Int { number }
}

private struct GrayscaleAutomationDiagram {
    struct Row {
        let symbol: String
        let title: String
        let subtitle: String
        let trailingSymbol: String
    }

    let rows: [Row]
    let showsNextButton: Bool
}

private enum AutomationMockDiagramKind {
    case automationTab
    case newAutomation
    case appTrigger
    case triggerOptions
    case blankAutomation
    case dopabreakAction
    case finishAction
}

private struct AutomationStepCard: View {
    let step: AutomationGuideStep

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Text(String(localized: "automation_guide.step.number", defaultValue: "\(step.number)"))
                        .dopaFont(14, weight: .black)
                        .foregroundStyle(DesignTokens.background)
                        .frame(width: 32, height: 32)
                        .background(DesignTokens.accent)
                        .clipShape(Circle())
                        .accessibilityHidden(true)

                    Text(step.instruction)
                        .dopaFont(16, weight: .bold, lineSpacing: 4)
                        .foregroundStyle(DesignTokens.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ShortcutsMockDiagram(kind: step.diagram, stepNumber: step.number)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                localized: "automation_guide.step.accessibility_label",
                defaultValue: "手順\(step.number) \(step.instruction)"
            )
        )
    }
}

private struct GrayscaleAutomationStepCard: View {
    let step: GrayscaleGuideStep

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Text(String(localized: "automation_guide.step.number", defaultValue: "\(step.number)"))
                        .dopaFont(14, weight: .black)
                        .foregroundStyle(DesignTokens.background)
                        .frame(width: 32, height: 32)
                        .background(DesignTokens.accent)
                        .clipShape(Circle())
                        .accessibilityHidden(true)

                    Text(step.instruction)
                        .dopaFont(16, weight: .bold, lineSpacing: 4)
                        .foregroundStyle(DesignTokens.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                GrayscaleAutomationMockDiagram(diagram: step.diagram)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                localized: "automation_guide.step.accessibility_label",
                defaultValue: "手順\(step.number) \(step.instruction)"
            )
        )
    }
}

private struct GrayscaleAutomationMockDiagram: View {
    let diagram: GrayscaleAutomationDiagram

    var body: some View {
        VStack(spacing: 10) {
            ForEach(diagram.rows.indices, id: \.self) { index in
                let row = diagram.rows[index]

                MockRow(
                    symbol: row.symbol,
                    title: row.title,
                    subtitle: row.subtitle,
                    trailingSymbol: row.trailingSymbol
                )
            }

            if diagram.showsNextButton {
                Text(String(localized: "automation_guide.mock.next", defaultValue: "次へ"))
                    .dopaFont(12, weight: .bold)
                    .foregroundStyle(DesignTokens.background)
                    .frame(minWidth: 72, minHeight: 36)
                    .background(DesignTokens.accent)
                    .clipShape(Capsule())
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(DesignTokens.background)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DesignTokens.strongHairline, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private final class AutomationTutorialPlaybackController: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var isAvailable = false

    private let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var timeControlObservation: NSKeyValueObservation?
    private var currentItemObservation: NSKeyValueObservation?
    private var currentItemStatusObservation: NSKeyValueObservation?
    private var looperStatusObservation: NSKeyValueObservation?
    private weak var attachedPlayerLayer: AVPlayerLayer?
    private var pictureInPictureController: AVPictureInPictureController?
    private var backgroundFallbackWorkItem: DispatchWorkItem?
    private var isGuideVisible = false
    private var isVideoCardVisible = false
    private var isAudioSessionActive = false
    private var isAutomaticPictureInPictureStartArmed = false
    private var didPauseForBackgroundFallback = false

    override init() {
        let resourceName = automationTutorialVideoResourceName(
            for: Locale.current.language.languageCode?.identifier
        )
        let bundledVideoURL = Bundle.main.url(
            forResource: resourceName,
            withExtension: "mp4"
        ) ?? Bundle.main.url(
            forResource: resourceName,
            withExtension: "mp4",
            subdirectory: "Resources"
        )

        super.init()

        guard let bundledVideoURL else {
            return
        }
        isAvailable = true

        player.isMuted = true
        player.volume = 0
        let looper = AVPlayerLooper(
            player: player,
            templateItem: AVPlayerItem(url: bundledVideoURL)
        )
        self.looper = looper
        timeControlObservation = player.observe(
            \.timeControlStatus,
            options: [.initial, .new]
        ) { [weak self] observedPlayer, _ in
            DispatchQueue.main.async {
                self?.isPlaying = observedPlayer.timeControlStatus == .playing
            }
        }
        currentItemObservation = player.observe(
            \.currentItem,
            options: [.initial, .new]
        ) { [weak self] observedPlayer, _ in
            let currentItem = observedPlayer.currentItem
            DispatchQueue.main.async {
                self?.observeStatus(of: currentItem)
            }
        }
        looperStatusObservation = looper.observe(
            \.status,
            options: [.initial, .new]
        ) { [weak self] observedLooper, _ in
            guard observedLooper.status == .failed else {
                return
            }
            DispatchQueue.main.async {
                self?.handlePlaybackFailure()
            }
        }
    }

    deinit {
        backgroundFallbackWorkItem?.cancel()
        timeControlObservation?.invalidate()
        currentItemObservation?.invalidate()
        currentItemStatusObservation?.invalidate()
        looperStatusObservation?.invalidate()
        player.pause()
        deactivateAudioSession()
    }

    func attach(to playerLayer: AVPlayerLayer) {
        guard isAvailable else {
            return
        }

        guard attachedPlayerLayer !== playerLayer else {
            return
        }

        if pictureInPictureController?.isPictureInPictureActive == true {
            pictureInPictureController?.stopPictureInPicture()
        }
        attachedPlayerLayer?.player = nil

        attachedPlayerLayer = playerLayer
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect

        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            pictureInPictureController = nil
            return
        }

        guard let pictureInPictureController = AVPictureInPictureController(playerLayer: playerLayer) else {
            self.pictureInPictureController = nil
            return
        }
        pictureInPictureController.delegate = self
        pictureInPictureController.canStartPictureInPictureAutomaticallyFromInline =
            isAutomaticPictureInPictureStartArmed
        self.pictureInPictureController = pictureInPictureController
    }

    func detach(from playerLayer: AVPlayerLayer) {
        guard attachedPlayerLayer === playerLayer else {
            return
        }

        if pictureInPictureController?.isPictureInPictureActive == true {
            pictureInPictureController?.stopPictureInPicture()
        }
        pictureInPictureController = nil
        playerLayer.player = nil
        attachedPlayerLayer = nil
    }

    func guideDidAppear(reduceMotion: Bool) {
        isGuideVisible = true
        guard isVideoCardVisible else {
            return
        }
        if reduceMotion {
            pausePreservingAudioSession()
        } else {
            play()
        }
    }

    func videoCardDidAppear(reduceMotion: Bool) {
        isVideoCardVisible = true
        guard isGuideVisible else {
            return
        }
        if reduceMotion {
            pausePreservingAudioSession()
        } else {
            play()
        }
    }

    func videoCardDidDisappear() {
        isVideoCardVisible = false
        pausePreservingAudioSession()
    }

    func reduceMotionDidChange(to reduceMotion: Bool) {
        guard isGuideVisible, isVideoCardVisible else {
            return
        }

        if reduceMotion {
            if pictureInPictureController?.isPictureInPictureActive == true {
                pictureInPictureController?.stopPictureInPicture()
            }
            pause()
        } else {
            play()
        }
    }

    func guideDidDisappear() {
        backgroundFallbackWorkItem?.cancel()
        backgroundFallbackWorkItem = nil
        didPauseForBackgroundFallback = false
        setAutomaticPictureInPictureStartArmed(false)
        isGuideVisible = false
        isVideoCardVisible = false
        if pictureInPictureController?.isPictureInPictureActive == true {
            pictureInPictureController?.stopPictureInPicture()
        }
        player.pause()
        player.seek(to: .zero)
        deactivateAudioSession()
    }

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    func prepareForExternalTransition() {
        guard isGuideVisible else {
            return
        }
        setAutomaticPictureInPictureStartArmed(true)
        guard player.timeControlStatus == .playing else {
            return
        }
        activateAudioSession()
    }

    func cancelExternalTransitionPreparation() {
        setAutomaticPictureInPictureStartArmed(false)
    }

    func applicationDidEnterBackground() {
        backgroundFallbackWorkItem?.cancel()

        guard isGuideVisible, player.timeControlStatus == .playing else {
            return
        }

        let fallbackWorkItem = DispatchWorkItem { [weak self] in
            guard let self,
                  UIApplication.shared.applicationState != .active,
                  self.pictureInPictureController?.isPictureInPictureActive != true else {
                return
            }
            self.pauseForBackgroundFallback()
        }
        backgroundFallbackWorkItem = fallbackWorkItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 1.5,
            execute: fallbackWorkItem
        )
    }

    func applicationDidBecomeActive() {
        backgroundFallbackWorkItem?.cancel()
        backgroundFallbackWorkItem = nil
        setAutomaticPictureInPictureStartArmed(false)

        if isGuideVisible,
           pictureInPictureController?.isPictureInPictureActive == true {
            pictureInPictureController?.stopPictureInPicture()
        }

        guard didPauseForBackgroundFallback else {
            return
        }
        didPauseForBackgroundFallback = false
        play()
    }

    private func play() {
        guard isAvailable, isGuideVisible else {
            return
        }
        activateAudioSession()
        player.play()
    }

    private func pause() {
        player.pause()
        if pictureInPictureController?.isPictureInPictureActive != true {
            deactivateAudioSession()
        }
    }

    private func pausePreservingAudioSession() {
        player.pause()
    }

    private func pauseForBackgroundFallback() {
        guard pictureInPictureController?.isPictureInPictureActive != true else {
            return
        }
        didPauseForBackgroundFallback = true
        pause()
    }

    private func setAutomaticPictureInPictureStartArmed(_ isArmed: Bool) {
        isAutomaticPictureInPictureStartArmed = isArmed
        pictureInPictureController?.canStartPictureInPictureAutomaticallyFromInline = isArmed
    }

    private func observeStatus(of playerItem: AVPlayerItem?) {
        currentItemStatusObservation?.invalidate()
        currentItemStatusObservation = nil

        guard let playerItem else {
            return
        }
        currentItemStatusObservation = playerItem.observe(
            \.status,
            options: [.initial, .new]
        ) { [weak self] observedItem, _ in
            guard observedItem.status == .failed else {
                return
            }
            DispatchQueue.main.async {
                self?.handlePlaybackFailure()
            }
        }
    }

    private func handlePlaybackFailure() {
        guard isAvailable else {
            return
        }
        isAvailable = false
        backgroundFallbackWorkItem?.cancel()
        backgroundFallbackWorkItem = nil
        didPauseForBackgroundFallback = false
        setAutomaticPictureInPictureStartArmed(false)
        if pictureInPictureController?.isPictureInPictureActive == true {
            pictureInPictureController?.stopPictureInPicture()
        }
        player.pause()
        deactivateAudioSession()
    }

    private func activateAudioSession() {
        guard !isAudioSessionActive else {
            return
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playback,
                mode: .moviePlayback,
                options: [.mixWithOthers]
            )
            try audioSession.setActive(true)
            isAudioSessionActive = true
        } catch {
            // PiP is an enhancement. Inline playback remains available if audio setup fails.
        }
    }

    private func deactivateAudioSession() {
        guard isAudioSessionActive else {
            return
        }

        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: [.notifyOthersOnDeactivation]
            )
            isAudioSessionActive = false
        } catch {
            // Avoid surfacing media-session errors in the setup guide.
        }
    }
}

extension AutomationTutorialPlaybackController: AVPictureInPictureControllerDelegate {
    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: any Error
    ) {
        DispatchQueue.main.async { [weak self] in
            guard UIApplication.shared.applicationState != .active else {
                return
            }
            self?.pauseForBackgroundFallback()
        }
    }

    func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        DispatchQueue.main.async { [weak self] in
            guard UIApplication.shared.applicationState != .active else {
                return
            }
            self?.pause()
        }
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(isGuideVisible)
    }
}

private final class AutomationTutorialPlayerUIView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    private weak var playbackController: AutomationTutorialPlaybackController?

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with playbackController: AutomationTutorialPlaybackController) {
        self.playbackController = playbackController
        playbackController.attach(to: playerLayer)
    }

    func detachPlayer() {
        playbackController?.detach(from: playerLayer)
        playbackController = nil
    }
}

private struct AutomationTutorialPlayerSurface: UIViewRepresentable {
    let playbackController: AutomationTutorialPlaybackController

    func makeUIView(context: Context) -> AutomationTutorialPlayerUIView {
        let playerView = AutomationTutorialPlayerUIView()
        playerView.configure(with: playbackController)
        return playerView
    }

    func updateUIView(_ playerView: AutomationTutorialPlayerUIView, context: Context) {
        playerView.configure(with: playbackController)
    }

    static func dismantleUIView(
        _ playerView: AutomationTutorialPlayerUIView,
        coordinator: Void
    ) {
        playerView.detachPlayer()
    }
}

private struct AutomationTutorialVideoCard: View {
    @ObservedObject var playbackController: AutomationTutorialPlaybackController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let videoHeight: CGFloat = 320
    private let videoAspectRatio: CGFloat = 720 / 1_566

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                ZStack {
                    AutomationTutorialPlayerSurface(playbackController: playbackController)
                    playbackControlOverlay
                }
                .frame(width: videoHeight * videoAspectRatio, height: videoHeight)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(DesignTokens.hairline, lineWidth: 1)
                }
                .frame(maxWidth: .infinity)

                Text(String(localized: "automation_guide.video.section", defaultValue: "動画ガイド"))
                    .dopaFont(16, weight: .bold)
                    .foregroundStyle(DesignTokens.primaryText)

                Text(String(localized: "automation_guide.video.body", defaultValue: "iOS 26の動画を見ながら設定できます"))
                    .dopaFont(14, weight: .semibold, lineSpacing: 4)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            String(
                localized: "automation_guide.video.accessibility_label",
                defaultValue: "設定手順のデモ動画"
            )
        )
        .onAppear {
            playbackController.videoCardDidAppear(reduceMotion: reduceMotion)
        }
        .onChange(of: reduceMotion) { _, newValue in
            playbackController.reduceMotionDidChange(to: newValue)
        }
        .onDisappear {
            playbackController.videoCardDidDisappear()
        }
    }

    @ViewBuilder
    private var playbackControlOverlay: some View {
        if reduceMotion && !playbackController.isPlaying {
            playbackButton
        } else {
            playbackButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(10)
        }
    }

    private var playbackButton: some View {
        Button {
            playbackController.togglePlayback()
        } label: {
            Image(systemName: playbackController.isPlaying ? "pause.fill" : "play.fill")
                .dopaFont(17, weight: .bold)
                .foregroundStyle(Color.white)
                .frame(width: DesignTokens.minTapTarget, height: DesignTokens.minTapTarget)
                .background(Color.black.opacity(0.72))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            String(
                localized: playbackController.isPlaying
                    ? "automation_guide.video.pause"
                    : "automation_guide.video.play",
                defaultValue: playbackController.isPlaying ? "動画を一時停止" : "動画を再生"
            )
        )
    }
}

private struct ShortcutsMockDiagram: View {
    let kind: AutomationMockDiagramKind
    let stepNumber: Int

    var body: some View {
        diagramContent
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 178, alignment: .topLeading)
            .background(DesignTokens.background)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DesignTokens.strongHairline, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var diagramContent: some View {
        switch kind {
        case .automationTab:
            automationTabDiagram
        case .newAutomation:
            newAutomationDiagram
        case .appTrigger:
            appTriggerDiagram
        case .triggerOptions:
            triggerOptionsDiagram
        case .blankAutomation:
            blankAutomationDiagram
        case .dopabreakAction:
            dopabreakActionDiagram
        case .finishAction:
            finishActionDiagram
        }
    }

    private var automationTabDiagram: some View {
        VStack(spacing: 14) {
            MockTopBar(
                title: String(localized: "automation_guide.mock.shortcuts", defaultValue: "ショートカット")
            )

            VStack(spacing: 9) {
                MockSkeletonRow()
                MockSkeletonRow(short: true)
            }

            HStack(spacing: 6) {
                MockTabItem(
                    symbol: "square.grid.2x2",
                    title: String(localized: "automation_guide.mock.shortcuts", defaultValue: "ショートカット")
                )

                MockTapTarget(number: stepNumber, cornerRadius: 10) {
                    MockTabItem(
                        symbol: "clock.arrow.circlepath",
                        title: String(localized: "automation_guide.mock.automation", defaultValue: "オートメーション"),
                        emphasized: true
                    )
                }

                MockTabItem(
                    symbol: "square.stack.3d.up",
                    title: String(localized: "automation_guide.mock.gallery", defaultValue: "ギャラリー")
                )
            }
            .padding(8)
            .background(DesignTokens.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var newAutomationDiagram: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Text(String(localized: "automation_guide.mock.automation", defaultValue: "オートメーション"))
                    .dopaFont(14, weight: .bold)
                    .foregroundStyle(DesignTokens.primaryText)

                Spacer(minLength: 8)

                MockCircularTapTarget(number: stepNumber) {
                    Image(systemName: "plus")
                        .dopaFont(18, weight: .bold)
                        .foregroundStyle(DesignTokens.primaryText)
                        .frame(width: DesignTokens.minTapTarget, height: DesignTokens.minTapTarget)
                        .background(DesignTokens.card)
                        .clipShape(Circle())
                }
            }

            Text(String(localized: "automation_guide.mock.new_automation", defaultValue: "新規オートメーション"))
                .dopaFont(12, weight: .semibold)
                .foregroundStyle(DesignTokens.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            MockSkeletonRow()
            MockSkeletonRow(short: true)
        }
    }

    private var appTriggerDiagram: some View {
        VStack(spacing: 10) {
            MockTopBar(
                title: String(localized: "automation_guide.mock.choose_trigger", defaultValue: "トリガーを選択")
            )

            MockSkeletonRow(short: true)

            MockTapTarget(number: stepNumber, cornerRadius: 12) {
                MockRow(
                    symbol: "app.fill",
                    title: String(localized: "automation_guide.mock.app", defaultValue: "アプリ")
                )
            }

            MockSkeletonRow()
        }
    }

    private var triggerOptionsDiagram: some View {
        VStack(spacing: 12) {
            MockTapTarget(number: stepNumber, cornerRadius: 12) {
                VStack(spacing: 0) {
                    MockRow(
                        symbol: "app.badge",
                        title: String(localized: "automation_guide.mock.target_app", defaultValue: "アプリ"),
                        trailingSymbol: "checkmark.circle.fill"
                    )

                    Rectangle()
                        .fill(DesignTokens.hairline)
                        .frame(height: 1)
                        .padding(.horizontal, 12)

                    MockChoiceRow(
                        title: String(localized: "automation_guide.mock.opened", defaultValue: "開いている")
                    )

                    MockChoiceRow(
                        title: String(localized: "automation_guide.mock.run_immediately", defaultValue: "すぐに実行")
                    )

                    MockToggleRow(
                        title: String(
                            localized: "automation_guide.mock.notify_when_run",
                            defaultValue: "実行時に通知"
                        ),
                        isOn: false
                    )
                }
                .background(DesignTokens.card)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Text(String(localized: "automation_guide.mock.next", defaultValue: "次へ"))
                .dopaFont(12, weight: .bold)
                .foregroundStyle(DesignTokens.background)
                .frame(minWidth: 72, minHeight: 36)
                .background(DesignTokens.accent)
                .clipShape(Capsule())
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var dopabreakActionDiagram: some View {
        VStack(spacing: 12) {
            Text(String(localized: "automation_guide.mock.apps", defaultValue: "アプリ"))
                .dopaFont(12, weight: .bold)
                .foregroundStyle(DesignTokens.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            MockTapTarget(number: stepNumber, cornerRadius: 12) {
                VStack(spacing: 8) {
                    MockRow(
                        symbol: "app.fill",
                        title: String(localized: "automation_guide.mock.dopabreak", defaultValue: "DopaBreak")
                    )

                    MockRow(
                        symbol: "wind",
                        title: String(
                            localized: "automation_guide.mock.start_breath",
                            defaultValue: "DopaBreakで一呼吸"
                        ),
                        trailingSymbol: "checkmark.circle.fill"
                    )
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .dopaFont(12, weight: .semibold)
                    .foregroundStyle(DesignTokens.secondaryText)

                Text(String(localized: "automation_guide.mock.search", defaultValue: "Appとアクションを検索"))
                    .dopaFont(12, weight: .medium)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: DesignTokens.minTapTarget)
            .background(DesignTokens.card)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
    }

    private var blankAutomationDiagram: some View {
        VStack(spacing: 10) {
            MockTopBar(
                title: String(localized: "automation_guide.mock.automation", defaultValue: "オートメーション")
            )

            MockTapTarget(number: stepNumber, cornerRadius: 12) {
                MockRow(
                    symbol: "plus.square.fill",
                    title: String(
                        localized: "automation_guide.mock.blank_automation",
                        defaultValue: "新規ショートカットを作成"
                    )
                )
            }

            MockSkeletonRow(short: true)
        }
    }

    private var finishActionDiagram: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text(String(localized: "automation_guide.mock.action", defaultValue: "アクション"))
                    .dopaFont(14, weight: .bold)
                    .foregroundStyle(DesignTokens.primaryText)

                Spacer(minLength: 8)

                MockCircularTapTarget(number: stepNumber) {
                    Image(systemName: "checkmark")
                        .dopaFont(17, weight: .bold)
                        .foregroundStyle(DesignTokens.primaryText)
                        .frame(width: DesignTokens.minTapTarget, height: DesignTokens.minTapTarget)
                        .background(DesignTokens.card)
                        .clipShape(Circle())
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "wind")
                        .dopaFont(13, weight: .bold)
                        .foregroundStyle(DesignTokens.accent)

                    Text(String(localized: "automation_guide.mock.start_breath", defaultValue: "DopaBreakで一呼吸"))
                        .dopaFont(12, weight: .bold)
                        .foregroundStyle(DesignTokens.primaryText)
                }

                Rectangle()
                    .fill(DesignTokens.hairline)
                    .frame(height: 1)

                HStack(spacing: 8) {
                    MockTapOutline(cornerRadius: 8) {
                        Text(String(localized: "automation_guide.mock.target_app", defaultValue: "アプリ"))
                            .dopaFont(12, weight: .bold)
                            .foregroundStyle(DesignTokens.primaryText)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 36)
                            .background(DesignTokens.backgroundRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    Spacer(minLength: 0)
                }
            }
            .padding(12)
            .background(DesignTokens.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct MockTopBar: View {
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(DesignTokens.secondaryText.opacity(0.35))
                .frame(width: 24, height: 24)

            Text(title)
                .dopaFont(13, weight: .bold)
                .foregroundStyle(DesignTokens.primaryText)

            Spacer(minLength: 8)

            Circle()
                .fill(DesignTokens.secondaryText.opacity(0.25))
                .frame(width: 24, height: 24)
        }
        .frame(minHeight: 32)
    }
}

private struct MockRow: View {
    let symbol: String
    let title: String
    var subtitle: String? = nil
    var trailingSymbol = "chevron.right"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .dopaFont(13, weight: .semibold)
                .foregroundStyle(DesignTokens.primaryText)
                .frame(width: 32, height: 32)
                .background(DesignTokens.secondaryText.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .dopaFont(12, weight: .bold)
                    .foregroundStyle(DesignTokens.primaryText)
                    .lineLimit(2)

                if let subtitle {
                    Text(subtitle)
                        .dopaFont(10, weight: .medium)
                        .foregroundStyle(DesignTokens.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: trailingSymbol)
                .dopaFont(11, weight: .bold)
                .foregroundStyle(
                    trailingSymbol == "checkmark.circle.fill"
                        ? DesignTokens.accent
                        : DesignTokens.secondaryText
                )
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 52)
        .background(DesignTokens.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct MockChoiceRow: View {
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .dopaFont(11, weight: .semibold)
                .foregroundStyle(DesignTokens.primaryText)

            Spacer(minLength: 8)

            Image(systemName: "checkmark.circle.fill")
                .dopaFont(14, weight: .bold)
                .foregroundStyle(DesignTokens.accent)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 42)
    }
}

private struct MockToggleRow: View {
    let title: String
    let isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .dopaFont(11, weight: .semibold)
                .foregroundStyle(DesignTokens.primaryText)

            Spacer(minLength: 8)

            Capsule()
                .fill(isOn ? DesignTokens.accent : DesignTokens.secondaryText.opacity(0.28))
                .frame(width: 34, height: 20)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(DesignTokens.primaryText)
                        .frame(width: 16, height: 16)
                        .padding(2)
                }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 42)
    }
}

private struct MockTabItem: View {
    let symbol: String
    let title: String
    var emphasized = false

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .dopaFont(14, weight: .semibold)

            Text(title)
                .dopaFont(9, weight: .semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(emphasized ? DesignTokens.primaryText : DesignTokens.secondaryText)
        .frame(maxWidth: .infinity, minHeight: DesignTokens.minTapTarget)
    }
}

private struct MockSkeletonRow: View {
    var short = false

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DesignTokens.secondaryText.opacity(0.15))
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 6) {
                Capsule()
                    .fill(DesignTokens.secondaryText.opacity(0.22))
                    .frame(width: short ? 92 : 132, height: 7)

                Capsule()
                    .fill(DesignTokens.secondaryText.opacity(0.12))
                    .frame(width: short ? 54 : 88, height: 6)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(DesignTokens.card.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct MockTapTarget<Content: View>: View {
    let number: Int
    let cornerRadius: CGFloat
    let content: Content

    init(
        number: Int,
        cornerRadius: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.number = number
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DesignTokens.danger, lineWidth: 2)
            }
            .overlay(alignment: .topTrailing) {
                MockTapBadge(number: number)
                    .offset(x: 8, y: -8)
            }
    }
}

private struct MockTapOutline<Content: View>: View {
    let cornerRadius: CGFloat
    let content: Content

    init(
        cornerRadius: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DesignTokens.danger, lineWidth: 2)
            }
    }
}

private struct MockCircularTapTarget<Content: View>: View {
    let number: Int
    let content: Content

    init(number: Int, @ViewBuilder content: () -> Content) {
        self.number = number
        self.content = content()
    }

    var body: some View {
        content
            .overlay {
                Circle()
                    .stroke(DesignTokens.danger, lineWidth: 2)
            }
            .overlay(alignment: .topTrailing) {
                MockTapBadge(number: number)
                    .offset(x: 7, y: -7)
            }
    }
}

private struct MockTapBadge: View {
    let number: Int

    var body: some View {
        Text(String(localized: "automation_guide.step.number", defaultValue: "\(number)"))
            .dopaFont(11, weight: .black)
            .foregroundStyle(DesignTokens.background)
            .frame(width: 24, height: 24)
            .background(DesignTokens.danger)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
            }
    }
}
