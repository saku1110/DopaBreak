import Foundation
import UIKit

/// ホーム画面クイックアクション（アイコン長押し）の設定値。
///
/// アイコン長押しは「アプリを削除する」操作と同じ導線にあるため、ここに離脱防止の選択肢を置く。
enum QuickActionsConfiguration {
    /// 引き止めオファー枠のフィーチャーフラグ。
    ///
    /// App Store Connect 側に実オファー（Offer Code）を作るまでは必ず false のままにする。
    /// 表示している割引の条件が実体と食い違うとガイドライン2.3（誤解を招く表示）に触れるため、
    /// 実体ができるまでは枠そのものを登録しない。
    static let offerSlotEnabled = false
}

/// クイックアクションの3枠。順序がそのまま長押しメニューの並びになる。
enum QuickActionType: String, CaseIterable, Sendable {
    /// コア機能。介入フロー（一呼吸）を直接開く。
    case intervene
    /// 引き止めオファー。非課金ユーザーにだけ登録する。
    case offer
    /// サポート。既存の問い合わせ導線（mailto）へ送る。
    case support

    /// `UIApplicationShortcutItem.type` に載せる識別子。
    /// バンドルIDは環境変数で変わるため、識別子には混ぜず固定文字列にする。
    var shortcutItemType: String {
        "com.dopabreak.quickaction.\(rawValue)"
    }

    init?(shortcutItemType: String) {
        guard let matched = Self.allCases.first(where: { $0.shortcutItemType == shortcutItemType }) else {
            return nil
        }
        self = matched
    }

    var localizedTitle: String {
        switch self {
        case .intervene:
            return String(localized: "quick_action.intervene.title", defaultValue: "いま一呼吸")
        case .offer:
            return String(localized: "quick_action.offer.title", defaultValue: "オファーを使う")
        case .support:
            return String(localized: "quick_action.support.title", defaultValue: "フィードバックを送る")
        }
    }

    var systemImageName: String {
        switch self {
        case .intervene:
            return "wind"
        case .offer:
            return "gift"
        case .support:
            return "envelope"
        }
    }
}

/// 登録する枠を決める純粋関数群。UIに触らないため単体テストできる。
enum QuickActionPolicy {
    /// 引き止めオファー枠を出すか。
    ///
    /// 判断は `hasResolvedEntitlement`（＝解決を1度試した）ではなく
    /// `hasConfirmedEntitlement`（＝StoreKitへ届いたうえで解決できた）で行う。
    /// 権利の取得に失敗しただけの課金者へ割引を見せると、既存課金者の不公平感から
    /// 低評価・返金請求を招くため、確定していない間は課金者扱いにして出さない。
    static func showsOfferSlot(
        isPro: Bool,
        hasConfirmedEntitlement: Bool,
        offerSlotEnabled: Bool = QuickActionsConfiguration.offerSlotEnabled
    ) -> Bool {
        guard offerSlotEnabled else {
            return false
        }
        guard hasConfirmedEntitlement else {
            return false
        }
        return !isPro
    }

    /// 登録する枠を並び順どおりに返す。
    ///
    /// オンボーディング未完了のうちは対象アプリもルールも無いため、介入は着地先を持たない。
    /// この段階ではサポートだけを残す。
    ///
    /// 設定で対象アプリを全部外したあとも同じく着地先が無い。
    /// 枠を残すと、押しても何も起きないメニュー項目になるため `hasInterventionTargets` で落とす。
    static func types(
        isOnboardingCompleted: Bool,
        hasInterventionTargets: Bool,
        isPro: Bool,
        hasConfirmedEntitlement: Bool,
        offerSlotEnabled: Bool = QuickActionsConfiguration.offerSlotEnabled
    ) -> [QuickActionType] {
        guard isOnboardingCompleted else {
            return [.support]
        }

        var types: [QuickActionType] = []
        if hasInterventionTargets {
            types.append(.intervene)
        }
        if showsOfferSlot(
            isPro: isPro,
            hasConfirmedEntitlement: hasConfirmedEntitlement,
            offerSlotEnabled: offerSlotEnabled
        ) {
            types.append(.offer)
        }
        types.append(.support)
        return types
    }
}

/// クイックアクションの登録と、押された枠の受け渡しを1か所にまとめる。
///
/// 押された枠は `UIApplicationDelegate` / `UISceneDelegate`（SwiftUIのViewの外）で受け取るため、
/// ここに置いてSwiftUI側から観測する。
@MainActor
final class QuickActionCenter: ObservableObject {
    static let shared = QuickActionCenter()

    /// まだ消費していない押下。`DopaBreakApp` の `consumePendingQuickAction()` が消費する。
    ///
    /// オンボーディング中でもサポート枠は押せるため、消費点はRootTabViewではなくApp階層に置く。
    @Published private(set) var pendingAction: QuickActionType?

    private(set) var registeredTypes: [QuickActionType] = []

    init() {}

    /// 押された枠を受け取る。未知の識別子は受け付けない。
    @discardableResult
    func enqueue(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let type = QuickActionType(shortcutItemType: shortcutItem.type) else {
            return false
        }
        pendingAction = type
        return true
    }

    func enqueue(_ type: QuickActionType) {
        pendingAction = type
    }

    func consumePendingAction() -> QuickActionType? {
        let value = pendingAction
        pendingAction = nil
        return value
    }

    func clearPendingAction() {
        pendingAction = nil
    }

    /// 権利・オンボーディング状態・対象アプリの有無に合わせて登録し直す。
    ///
    /// 課金状態が変わるたびに呼ぶこと。呼ばないと、解約した人にオファーが出ないままになり、
    /// 課金した人にオファーが残り続ける。
    /// 対象アプリの増減でも呼ぶこと。呼ばないと、対象を全部外したあとも介入枠が残り、
    /// 押しても何も起きないメニューになる。
    func updateShortcutItems(
        isOnboardingCompleted: Bool,
        hasInterventionTargets: Bool,
        isPro: Bool,
        hasConfirmedEntitlement: Bool,
        application: UIApplication = .shared
    ) {
        let types = QuickActionPolicy.types(
            isOnboardingCompleted: isOnboardingCompleted,
            hasInterventionTargets: hasInterventionTargets,
            isPro: isPro,
            hasConfirmedEntitlement: hasConfirmedEntitlement
        )
        guard types != registeredTypes else {
            return
        }
        registeredTypes = types
        application.shortcutItems = types.map { type in
            UIApplicationShortcutItem(
                type: type.shortcutItemType,
                localizedTitle: type.localizedTitle,
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: type.systemImageName),
                userInfo: nil
            )
        }
        // 登録から外れた枠の押下が残っていたら捨てる（着地先を持たないため）。
        if let pendingAction, !types.contains(pendingAction) {
            self.pendingAction = nil
        }
    }
}
