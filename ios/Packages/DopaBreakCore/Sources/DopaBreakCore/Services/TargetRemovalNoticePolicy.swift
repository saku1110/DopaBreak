/// 対象アプリから外した直後に「ショートカットの自動化が残っている」案内を出すかを決める。
///
/// iOSにはアプリ側からユーザーのオートメーションを削除するAPIがない。
/// 自動化を残したままだと、対象から外したアプリを開いてもDopaBreakが前面に出る。
/// 外した瞬間だけがその事実を伝えられる接点なので、
/// 実際に自動化が動いた記録（検収済み）があるアプリに限って案内する。
public enum TargetRemovalNoticePolicy {
    /// 対象から外した直後に「自動化が残っている」案内を出すか。
    /// - Parameters:
    ///   - removedCatalogID: いま対象から外したアプリのカタログID。
    ///   - verifiedAutomationCatalogIDs: 自動化の発火を確認済みのカタログID。
    public static func shouldNotify(
        removedCatalogID: String,
        verifiedAutomationCatalogIDs: [String]
    ) -> Bool {
        guard SNSAppCatalog.contains(catalogID: removedCatalogID) else {
            return false
        }
        return verifiedAutomationCatalogIDs.contains(removedCatalogID)
    }
}
