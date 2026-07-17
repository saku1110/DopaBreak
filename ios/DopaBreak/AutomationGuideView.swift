import DopaBreakCore
import SwiftUI
import UIKit

/// ショートカットのオートメーション設定ガイド（doc12 §4 / doc11 §4c）。
/// 対象アプリから介入Intentが発火した事実を設定済み判定として表示する。
struct AutomationGuideView: View {
    let model: AppModel
    let settingsStore: SettingsStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTargets: [SNSAppCatalogItem] = []
    @State private var verifiedAutomationCatalogIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("自動で一呼吸を出す設定")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(DesignTokens.primaryText)

                    Text("ショートカットのオートメーションで、選んだアプリを開いたときにDopaBreakを起動します。")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DesignTokens.secondaryText)
                        .lineSpacing(4)

                    Button("ショートカットを開く") {
                        openShortcutsApp()
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    CardContainer {
                        VStack(alignment: .leading, spacing: 14) {
                            numberedStep(1, "オートメーションを開く")
                            numberedStep(2, "＋を押してAppを選ぶ")
                            numberedStep(3, "対象アプリを選び開かれたときを選ぶ")
                            numberedStep(4, "すぐに実行を選ぶ")
                            numberedStep(5, "アクションでDopaBreakで一呼吸を選ぶ")
                        }
                    }

                    CardContainer {
                        VStack(alignment: .leading, spacing: 0) {
                            SmallLabel(text: "設定するアプリ")
                                .padding(.bottom, 12)

                            if selectedTargets.isEmpty {
                                Text("先に止めるアプリを選んでください。")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(DesignTokens.secondaryText)
                            } else {
                                ForEach(Array(selectedTargets.enumerated()), id: \.element.id) { index, target in
                                    if index > 0 {
                                        Rectangle()
                                            .fill(DesignTokens.hairline)
                                            .frame(height: 1)
                                            .padding(.vertical, 16)
                                    }
                                    automationRow(target)
                                }
                            }
                        }
                    }

                    Text("設定できたかどうかは 対象アプリを開いたときに自動で確認されます")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DesignTokens.secondaryText)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 60)
            }
            .dopaScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundStyle(DesignTokens.secondaryText)
                }
            }
        }
        .tint(DesignTokens.accent)
        .preferredColorScheme(.dark)
        .onAppear {
            refreshGuideState()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }
            refreshGuideState()
        }
    }

    private func automationRow(_ target: SNSAppCatalogItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: target.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignTokens.accent)

                Text(target.displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DesignTokens.primaryText)

                Spacer()

                automationStatusBadge(catalogID: target.catalogID)
            }

            if target.urlScheme == nil {
                Text("Safariはホーム画面から開いて確認してください")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignTokens.secondaryText)
                    .lineSpacing(3)
            } else {
                Button("テストする") {
                    testAutomation(target)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private func automationStatusBadge(catalogID: String) -> some View {
        let isVerified = verifiedAutomationCatalogIDs.contains(catalogID)
        return Text(isVerified ? "設定済み" : "未確認")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isVerified ? DesignTokens.accent : DesignTokens.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isVerified
                    ? DesignTokens.accent.opacity(0.12)
                    : DesignTokens.secondaryText.opacity(0.12)
            )
            .clipShape(Capsule())
    }

    private func numberedStep(_ index: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index)")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(DesignTokens.background)
                .frame(width: 22, height: 22)
                .background(DesignTokens.accent)
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DesignTokens.primaryText)
        }
    }

    private func openShortcutsApp() {
        guard let url = URL(string: "shortcuts://") else {
            return
        }
        UIApplication.shared.open(url)
    }

    private func testAutomation(_ target: SNSAppCatalogItem) {
        guard let scheme = target.urlScheme, let url = URL(string: scheme) else {
            return
        }
        UIApplication.shared.open(url)
    }

    private func refreshGuideState() {
        selectedTargets = (try? model.targetStore.selectedTargets()) ?? []
        verifiedAutomationCatalogIDs = Set(settingsStore.verifiedAutomationCatalogIDs)
    }
}
