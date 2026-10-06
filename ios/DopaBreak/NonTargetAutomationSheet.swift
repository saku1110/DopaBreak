import DopaBreakCore
import SwiftUI
import UIKit

struct NonTargetAutomationSheet: View {
    let automation: NonTargetAutomation
    /// 「対象に戻す」が追加・入れ替え・課金導線のどれになるか。判定はCoreの純関数が持つ。
    let restoreDecision: NonTargetAutomationRestorePolicy.Decision
    /// 対象へ戻す。失敗したときは表示する文言を返す（親のアラートはこのシートに隠れて出ないため）。
    let onRestore: () -> String?
    let onShowPro: () -> Void
    let onOpenApp: () -> Void
    let onClose: () -> Void

    @State private var showsDeleteSteps = false
    @State private var errorMessage: String?

    private var target: SNSAppCatalogItem? {
        SNSAppCatalog.app(catalogID: automation.catalogID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // ビジュアル訴求のシートなので、見出しと説明は中央揃え（Large Title文脈の画面ではない）。
                    Text(titleText)
                        .dopaFont(28, weight: .black)
                        .foregroundStyle(DesignTokens.primaryText)
                        // 改行を持つ翻訳はその行数を守り、拡大時は縮小で収める（自然折返しだと語尾だけ次行へ落ちる）。
                        .lineLimit(titleLineCount)
                        .minimumScaleFactor(titleLineCount == nil ? 1 : 0.6)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text(bodyText)
                        .dopaFont(15, weight: .semibold, lineSpacing: 4)
                        .foregroundStyle(DesignTokens.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .center)

                    VStack(spacing: 10) {
                        Button(primaryActionTitle) {
                            switch restoreDecision {
                            case .add, .swap:
                                errorMessage = onRestore()
                            case .requiresPro:
                                onShowPro()
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        // 失敗しても閉じないので、押した場所のすぐ下で理由を出す。
                        if let errorMessage {
                            Text(errorMessage)
                                .dopaFont(13, weight: .semibold)
                                .foregroundStyle(DesignTokens.danger)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }

                        Button(
                            String(
                                localized: "automation.non_target.action.open",
                                defaultValue: "そのまま\(target?.displayName ?? "")を開く"
                            ),
                            action: onOpenApp
                        )
                        .buttonStyle(SecondaryButtonStyle())

                        Button {
                            withAnimation(DopaMotion.control) {
                                showsDeleteSteps.toggle()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(
                                    String(
                                        localized: "automation.non_target.action.how_to_delete",
                                        defaultValue: "自動化の削除方法"
                                    )
                                )
                                Image(systemName: showsDeleteSteps ? "chevron.up" : "chevron.down")
                                    .font(.caption.weight(.bold))
                            }
                            .dopaFont(15, weight: .semibold)
                            .foregroundStyle(DesignTokens.secondaryText)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if showsDeleteSteps {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(deleteSteps) { step in
                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        Text(
                                            String(
                                                localized: "automation_guide.step.number",
                                                defaultValue: "\(step.number)"
                                            )
                                        )
                                        .dopaFont(12, weight: .black)
                                        .foregroundStyle(DesignTokens.background)
                                        // 円の固定寸法にすると拡大時に数字がはみ出すため、文字に合わせて伸びる形にする。
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(DesignTokens.accent))
                                        .accessibilityHidden(true)

                                        Text(step.text)
                                            .dopaFont(14, weight: .semibold, lineSpacing: 4)
                                            .foregroundStyle(DesignTokens.secondaryText)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .accessibilityElement(children: .combine)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity)

                            // Pro失効でクランプされた経路は課金導線なので、
                            // 削除だけを軽くしない。案内は対象から外したときに限る。
                            if automation.reason == .removed {
                                Button(
                                    String(
                                        localized: "target_app_picker.automation_notice.action.open",
                                        defaultValue: "ショートカットを開く"
                                    ),
                                    action: openShortcuts
                                )
                                .buttonStyle(SecondaryButtonStyle())
                                .transition(.opacity)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 32)
            }
            .dopaScreenBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "target_app_picker.action.close", defaultValue: "閉じる")) {
                        onClose()
                    }
                }
            }
        }
        .tint(DesignTokens.accent)
        .preferredColorScheme(.dark)
    }

    private var bodyText: String {
        switch automation.reason {
        case .removed:
            // 入れ替えになるときは押し出す相手を名指しする。何が外れるか分からないまま押させない。
            if case .swap = restoreDecision {
                guard let displacedDisplayName else {
                    // 名指しできないときも、外れるアプリがある事実だけは必ず伝える。
                    return String(
                        localized: "automation.non_target.body.removed_swap_generic",
                        defaultValue: "対象から外したあとも、ショートカットの自動化は残っています。入れ替えると、いま対象になっているアプリは外れます。")
                }
                return String(
                    localized: "automation.non_target.body.removed_swap",
                    defaultValue: "対象から外したあとも、ショートカットの自動化は残っています。いま対象になっているのは\(displacedDisplayName)です。入れ替えると、\(displacedDisplayName)は対象から外れます。")
            }
            return String(
                localized: "automation.non_target.body.removed",
                defaultValue: "対象から外したあとも、ショートカットの自動化は残っています。対象に戻すか、自動化を削除してください。")
        case .clampedByEntitlement:
            return String(
                localized: "automation.non_target.body.clamped",
                defaultValue: "Proの期限が切れたため、対象は1つに戻りました。\(target?.displayName ?? "")でも一呼吸置くにはProを再開してください。DopaBreakが勝手に開かないようにするには、この自動化を削除してください。")
        }
    }

    /// 見出し。jaはオーナー指示で「Instagramは」の直後に改行を固定する（カタログ側が \n を持つ）。
    /// 語尾だけが次行へ落ちるのを防ぐのが目的で、en/koは改行を持たず自然折返しのまま。
    private var titleText: String {
        String(
            localized: "automation.non_target.title",
            defaultValue: "\(target?.displayName ?? "")は\n一呼吸の対象外です"
        )
    }

    /// 明示的な改行を持つ翻訳だけ行数を固定する。持たない翻訳は制限なし。
    private var titleLineCount: Int? {
        let count = titleText.components(separatedBy: "\n").count
        return count > 1 ? count : nil
    }

    private struct DeleteStep: Identifiable {
        let number: Int
        let text: String

        var id: Int { number }
    }

    /// 削除手順。1行1ステップに割って、拡大しても行の途中で折り返らないようにする。
    private var deleteSteps: [DeleteStep] {
        [
            DeleteStep(
                number: 1,
                text: String(
                    localized: "automation.non_target.delete_step.1",
                    defaultValue: "ショートカットを開く"
                )
            ),
            DeleteStep(
                number: 2,
                text: String(
                    localized: "automation.non_target.delete_step.2",
                    defaultValue: "オートメーションを開く"
                )
            ),
            DeleteStep(
                number: 3,
                text: String(
                    localized: "automation.non_target.delete_step.3",
                    defaultValue: "左へスワイプして削除"
                )
            )
        ]
    }

    /// 手順を読んだ流れでそのままショートカットAppまで送る。
    /// 自動化を消せるのはユーザーだけなので、着地点を用意するところまでが本体の仕事になる。
    private func openShortcuts() {
        guard let url = URL(string: "shortcuts://") else {
            return
        }
        UIApplication.shared.open(url)
    }

    private var primaryActionTitle: String {
        switch restoreDecision {
        case .add:
            return String(localized: "automation.non_target.action.restore", defaultValue: "対象に戻す")
        case .swap:
            // 名前が引けなくても「対象に戻す」へは落とさない。外れるアプリがある操作を無害に見せないため。
            guard let displacedDisplayName else {
                return String(
                    localized: "automation.non_target.action.swap_generic",
                    defaultValue: "入れ替える"
                )
            }
            return String(
                localized: "automation.non_target.action.swap",
                defaultValue: "\(displacedDisplayName)と入れ替える"
            )
        case .requiresPro:
            return String(localized: "automation.non_target.action.pro", defaultValue: "Proを再開する")
        }
    }

    /// 押し出される対象アプリの表示名。
    /// 名指しするのは1つだけのときに限る。複数を1つの名前で代表させると、外れる残りが隠れる。
    private var displacedDisplayName: String? {
        guard case .swap(let displacedCatalogIDs) = restoreDecision,
              displacedCatalogIDs.count == 1,
              let displacedCatalogID = displacedCatalogIDs.first else {
            return nil
        }
        return SNSAppCatalog.app(catalogID: displacedCatalogID)?.displayName
    }
}
