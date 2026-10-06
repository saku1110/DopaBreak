import DopaBreakCore
import Foundation

/// 1日に開ける回数（Pro）の操作と、画面向けの読み出し。
///
/// 実体は `DailyOpenLimitController`。ここでは権利の確認と、画面へ変化を配る版番号の更新だけを足す。
extension AppModel {
    /// 今日の回数の状態。Freeではオフとして返す（設定値は残したまま効かせない）。
    var dailyOpenLimitStatus: DailyOpenLimitStatus {
        _ = dailyOpenLimitRevision
        guard entitlementGate.dailyOpenLimitAllowed else {
            return .off(dayEndsAt: currentDate)
        }
        return dailyOpenLimit.status()
    }

    /// 回数上限のシールドがいま掛かっている窓。掛かっていなければ `nil`。
    var dailyOpenLimitBlockSnapshot: DailyOpenLimitShieldSnapshot? {
        _ = dailyOpenLimitRevision
        guard entitlementGate.dailyOpenLimitAllowed else { return nil }
        return dailyOpenLimit.activeSnapshot()
    }

    /// 使い切ったあと、まだ開けている時間の終わり（最後の1回の決めた時間・緊急で開いた時間）。
    /// このあいだは「明日まで開けません」ではなく「{時刻}まで開けます」と出す。
    var dailyOpenLimitOpenUntil: Date? {
        _ = dailyOpenLimitRevision
        guard entitlementGate.dailyOpenLimitAllowed else { return nil }
        return dailyOpenLimit.openUntil()
    }

    /// 最近の1日あたりの開いた回数。上限を決めるときの目安として出す。
    var dailyOpenLimitAverageOpens: Int? {
        _ = dailyOpenLimitRevision
        return dailyOpenLimit.averageDailyOpens()
    }

    var dailyOpenLimitEmergencyState: DailyOpenLimitPolicy.EmergencyState {
        _ = dailyOpenLimitRevision
        return dailyOpenLimit.emergencyState()
    }

    /// 夜・予定・手動の完全ブロックがいま効いているか。
    /// 緊急で外せるのは回数上限ぶんだけなので、このあいだは緊急の導線を出さない。
    var isOtherHardBlockActive: Bool {
        ReinterventionShield.suppressesIntervention(now: currentDate)
    }

    func setDailyOpenLimit(_ limit: Int?) {
        guard entitlementGate.dailyOpenLimitAllowed else { return }
        dailyOpenLimit.setLimit(
            limit,
            isPro: true,
            hasConfirmedEntitlement: storeService.hasConfirmedEntitlement
        )
        dailyOpenLimitRevision += 1
    }

    /// 一呼吸のあと開いた回を記録した直後に呼ぶ。
    /// - Parameter durationSeconds: 決めた時間。時間なしで開いたときは `nil`。
    func didRecordOpenForDailyOpenLimit(durationSeconds: Int?) {
        dailyOpenLimit.didRecordOpen(
            durationSeconds: durationSeconds,
            isPro: entitlementGate.dailyOpenLimitAllowed,
            hasConfirmedEntitlement: storeService.hasConfirmedEntitlement
        )
        dailyOpenLimitRevision += 1
    }

    func requestDailyOpenLimitEmergency() {
        guard entitlementGate.dailyOpenLimitAllowed else { return }
        dailyOpenLimit.requestEmergency()
        dailyOpenLimitRevision += 1
    }

    /// 30秒待ち終わったあとに、決めた時間だけ開けるようにする。
    ///
    /// 回数上限のシールドを外し、一呼吸の対象アプリをその時間だけ素通しにする。
    /// 一呼吸から来たときは、開いた回として記録する。
    /// - Returns: 開いてよいか。
    func openForDailyOpenLimitEmergency(durationSeconds: Int, catalogTarget: SNSAppCatalogItem?) -> Bool {
        guard entitlementGate.dailyOpenLimitAllowed, !isOtherHardBlockActive,
              dailyOpenLimit.openForEmergency(durationSeconds: durationSeconds) else {
            dailyOpenLimitRevision += 1
            return false
        }
        let until = currentDate.addingTimeInterval(TimeInterval(durationSeconds))
        for catalogID in (try? targetStore.selectedCatalogIDs()) ?? [] {
            // 利用時間の通知・制限（再介入）が同じアプリで効いていると、30秒待っても開けない。
            // 緊急で開く時間はそちらの区切りも終える。終了は素通しの許可を取り消すため、許可より先に行う。
            if reinterventionSession(catalogID: catalogID) != nil {
                try? finishReintervention(catalogID: catalogID)
            }
            catalogAllowanceStore.grant(catalogID: catalogID, until: until)
        }
        if let catalogTarget, let engine = interventionEngine,
           let rule = try? ruleStore.catalogTargetRule(for: catalogTarget) {
            try? engine.recordLimitOverrideOpen(ruleId: rule.id, durationSeconds: durationSeconds)
        }
        dailyOpenLimitRevision += 1
        refresh()
        return true
    }
}
