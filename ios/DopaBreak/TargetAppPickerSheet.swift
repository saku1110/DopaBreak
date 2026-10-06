import DopaBreakCore
import SwiftUI
import UIKit

/// 一呼吸をはさむアプリ（通常介入の対象）をカタログから複数選択するシート（doc12 §3 / doc11 §4c）。
/// Freeは1個まで。上限到達後の追加でPaywallを表示する。
struct TargetAppPickerSheet: View {
    let model: AppModel
    let onPaywallNeeded: () -> Void
    /// 対象アプリを1つ追加して保存できたときに、そのカタログIDを親へ渡す。
    /// 追加した人はショートカットを作るまで一呼吸が出ないので、閉じたあと案内へ送る判断に使う。
    let onTargetAdded: (String) -> Void
    /// 対象アプリを1つ外して保存できたときに、そのカタログIDを親へ渡す。
    /// 同じピッカーの中で足して外し直したときに、案内の予約を取り消すために要る。
    let onTargetRemoved: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedCatalogIDs: [String] = []
    @State private var errorMessage: String?
    /// 対象から外した直後に、自動化が残っている事実を伝える相手。
    @State private var automationNoticeTarget: SNSAppCatalogItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(String(localized: "target_app_picker.title", defaultValue: "一呼吸をはさむアプリを選ぶ"))
                        .dopaFont(28, weight: .black)
                        .foregroundStyle(DesignTokens.primaryText)

                    Text(String(localized: "target_app_picker.description", defaultValue: "開く前に一呼吸はさみたいアプリを選びます。"))
                        .dopaFont(15, weight: .semibold, lineSpacing: 4)
                        .foregroundStyle(DesignTokens.secondaryText)

                    if let targetLimitDescription {
                        Text(targetLimitDescription)
                            .dopaFont(13, weight: .semibold)
                            .foregroundStyle(DesignTokens.secondaryText)
                    }

                    TargetAppGrid(
                        items: SNSAppCatalog.all,
                        selectedCatalogIDs: Set(selectedCatalogIDs),
                        style: .large,
                        onToggle: toggle
                    )

                    if let errorMessage {
                        Text(errorMessage)
                            .dopaFont(13, weight: .semibold)
                            .foregroundStyle(DesignTokens.danger)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .dopaScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "target_app_picker.action.close", defaultValue: "閉じる")) {
                        dismiss()
                    }
                    .foregroundStyle(DesignTokens.secondaryText)
                }
            }
        }
        .tint(DesignTokens.accent)
        .preferredColorScheme(.dark)
        .onAppear {
            selectedCatalogIDs = (try? model.targetStore.selectedCatalogIDs()) ?? []
        }
        .alert(
            automationNoticeTitle,
            isPresented: isAutomationNoticePresented
        ) {
            Button(
                String(
                    localized: "target_app_picker.automation_notice.action.open",
                    defaultValue: "ショートカットを開く"
                )
            ) {
                openShortcuts()
            }
            Button(
                String(
                    localized: "target_app_picker.automation_notice.action.later",
                    defaultValue: "あとで"
                ),
                role: .cancel
            ) {}
        } message: {
            Text(automationNoticeBody)
        }
    }

    private var isAutomationNoticePresented: Binding<Bool> {
        Binding(
            get: { automationNoticeTarget != nil },
            set: { isPresented in
                if !isPresented {
                    automationNoticeTarget = nil
                }
            }
        )
    }

    private var automationNoticeTitle: String {
        String(
            localized: "target_app_picker.automation_notice.title",
            defaultValue: "\(automationNoticeTarget?.displayName ?? "")の自動化が残っています"
        )
    }

    private var automationNoticeBody: String {
        String(
            localized: "target_app_picker.automation_notice.body",
            defaultValue: "ショートカットの自動化はDopaBreakからは消せません。残したままだと\(automationNoticeTarget?.displayName ?? "")を開くたびにDopaBreakが開きます"
        )
    }

    private func openShortcuts() {
        guard let url = URL(string: "shortcuts://") else {
            return
        }
        UIApplication.shared.open(url)
    }

    private var targetLimitDescription: String? {
        guard model.entitlementGate.targetAppTokensLimit == 1 else {
            return nil
        }
        return String(localized: "target_app_picker.limit.free", defaultValue: "無料プランでは1つまで")
    }

    private func toggle(_ item: SNSAppCatalogItem) {
        errorMessage = nil

        if selectedCatalogIDs.contains(item.catalogID) {
            selectedCatalogIDs.removeAll { $0 == item.catalogID }
            HapticFeedback.selection()
            // 外す操作自体は取り消さない。残った自動化は本体からは消せないため、
            // ショートカットAppまで送る案内だけを重ねる。
            // 保存に失敗したときはまだ対象のままなので、案内は出さない。
            let didPersist = persist()
            if didPersist {
                onTargetRemoved(item.catalogID)
                if TargetRemovalNoticePolicy.shouldNotify(
                    removedCatalogID: item.catalogID,
                    verifiedAutomationCatalogIDs: model.verifiedAutomationCatalogIDs
                ) {
                    automationNoticeTarget = item
                }
            }
            return
        }

        guard model.entitlementGate.canAddTargetTokens(currentCount: selectedCatalogIDs.count) else {
            model.purchaseContinuation = .addTarget(catalogID: item.catalogID)
            onPaywallNeeded()
            dismiss()
            return
        }

        selectedCatalogIDs.append(item.catalogID)
        HapticFeedback.selection()
        // 保存できたときだけ知らせる。まだ対象になっていない状態で設定の案内へ送らない。
        if persist() {
            onTargetAdded(item.catalogID)
        }
    }

    @discardableResult
    private func persist() -> Bool {
        do {
            try model.setTargetCatalogIDs(selectedCatalogIDs)
            return true
        } catch CoreError.validation(let message) {
            errorMessage = message
            return false
        } catch {
            errorMessage = String(localized: "target_app_picker.error.save", defaultValue: "保存できませんでした")
            return false
        }
    }
}
