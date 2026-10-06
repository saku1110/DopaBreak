import ManagedSettings
import DopaBreakCore
import Foundation

/// 完全ブロックは閉じるだけ。利用時間の区切りは、対応OSで親アプリの振り返りへ案内する。
/// 回数上限だけで止めているときは、対応OSでDopaBreakを開き、30秒待って開く導線へつなぐ。
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        if #available(iOS 26.5, *), action == .secondaryButtonPressed,
           DailyOpenLimitShield.isBlocking(application: application),
           !ReinterventionShield.hasWindowBlock(for: application) {
            completionHandler(.openParentalControlsApp)
            return
        }
        if #available(iOS 26.5, *), action == .primaryButtonPressed,
           !ReinterventionShield.hasHardBlock(for: application),
           ReinterventionShield.session(for: application) != nil {
            completionHandler(.openParentalControlsApp)
            return
        }
        completionHandler(.close)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.close)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.close)
    }
}
