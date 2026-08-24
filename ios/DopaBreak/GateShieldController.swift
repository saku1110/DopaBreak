import DopaBreakCore
import FamilyControls
import Foundation
import ManagedSettings

/// 日常の「開く前にひと呼吸」だけを、専用のシールドストアへ同期する。
///
/// 夜とディープフォーカスは別ストアに置かれているため、ここから触らない。
/// 権利が未確認なら現状を保ち、Freeだと確定したときだけ控えごと解除する。
@MainActor
final class GateShieldController {
    private let ruleStore: RuleStore
    private let ledgerStore: GateLedgerStore
    private let snapshotStore: GateShieldSnapshotStore
    private let managedSettingsStore: ManagedSettingsStore
    private let decoder = JSONDecoder()
    private let now: () -> Date

    init(
        ruleStore: RuleStore,
        ledgerStore: GateLedgerStore,
        snapshotStore: GateShieldSnapshotStore,
        managedSettingsStore: ManagedSettingsStore = ManagedSettingsStore(
            named: .init(GateConstants.shieldStoreName)
        ),
        now: @escaping () -> Date = { Date() }
    ) {
        self.ruleStore = ruleStore
        self.ledgerStore = ledgerStore
        self.snapshotStore = snapshotStore
        self.managedSettingsStore = managedSettingsStore
        self.now = now
    }

    /// 現在の権利・選択・一時開放へゲートを合わせる。
    ///
    /// 読み取り失敗は現状維持へ倒す。Free確定時だけは読み取りより先に無条件解除し、
    /// 壊れたルールがあっても降格後に開けない状態を残さない。
    func sync(
        entitlementGate: EntitlementGate,
        hasConfirmedEntitlement: Bool
    ) {
        var prepared: PreparedGateSelection?
        let action = GateSyncPolicy.action(
            tokensProvider: {
                prepared = try self.prepareSelection()
                return !(prepared?.applications.isEmpty ?? true)
            },
            gateAllowed: entitlementGate.gateAllowed,
            hasConfirmedEntitlement: hasConfirmedEntitlement
        )

        switch action {
        case .preserve:
            return
        case .clear:
            clearForDowngrade()
        case .apply:
            guard let prepared else {
                return
            }
            applyPreparedSelection(prepared)
        }
    }

    /// 保存済みの権利確認済み控えから、進行中の一時開放を除いて掛け直す。
    ///
    /// 解除開始・期限回収・設定変更が同じ再計算を使うことで、個別差分の取りこぼしを避ける。
    func reapply(now referenceDate: Date) throws {
        guard let snapshot = try snapshotStore.snapshot() else {
            clearManagedSettings()
            return
        }

        let applications = try decodedApplications(from: snapshot.selectionDataList)
        let ledger = try ledgerStore.ledger()
        let tokens = GatePolicy.tokensToShield(
            selectionTokens: applications,
            ledger: ledger,
            now: referenceDate
        )
        apply(applications: tokens)
    }

    /// Free確定時の非破壊解除。アプリ別設定と台帳は再契約に備えて残す。
    func clearForDowngrade() {
        clearManagedSettings()
        try? snapshotStore.remove()
    }

    /// 全データ削除時の解除。設定と台帳の削除は呼び出し側が同じ処理単位で行う。
    func clearAllData() throws {
        clearManagedSettings()
        try snapshotStore.remove()
    }

    private func prepareSelection() throws -> PreparedGateSelection {
        let selectionDataList = try ruleStore.enabledRules()
            .map(\.activitySelectionData)
            .filter { !$0.isEmpty }
        let applications = try decodedApplications(from: selectionDataList)
        return PreparedGateSelection(
            selectionDataList: selectionDataList,
            applications: applications,
            ledger: try ledgerStore.ledger(),
            referenceDate: now()
        )
    }

    private func applyPreparedSelection(_ prepared: PreparedGateSelection) {
        // 控えを先に確定する。書けなければ、拡張が後で復旧できないため現状を保つ。
        do {
            try snapshotStore.save(
                GateShieldSnapshot(
                    selectionDataList: prepared.selectionDataList,
                    updatedAt: prepared.referenceDate
                )
            )
        } catch {
            return
        }

        let tokens = GatePolicy.tokensToShield(
            selectionTokens: prepared.applications,
            ledger: prepared.ledger,
            now: prepared.referenceDate
        )
        apply(applications: tokens)
    }

    private func decodedApplications(from selectionDataList: [Data]) throws -> Set<ApplicationToken> {
        var applications = Set<ApplicationToken>()
        for selectionData in selectionDataList {
            let selection = try decoder.decode(
                FamilyActivitySelection.self,
                from: selectionData
            )
            applications.formUnion(selection.applicationTokens)
        }
        return applications
    }

    private func apply(applications: Set<ApplicationToken>) {
        managedSettingsStore.shield.applications = applications.isEmpty ? nil : applications
        // v1.1はアプリ単位だけ。過去値が混ざってもここで必ず空にする。
        managedSettingsStore.shield.applicationCategories = nil
        managedSettingsStore.shield.webDomains = nil
    }

    private func clearManagedSettings() {
        apply(applications: [])
    }
}

private struct PreparedGateSelection {
    let selectionDataList: [Data]
    let applications: Set<ApplicationToken>
    let ledger: GateLedger
    let referenceDate: Date
}
