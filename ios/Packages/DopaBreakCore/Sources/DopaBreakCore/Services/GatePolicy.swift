import Foundation

public enum HardKind: Equatable, Sendable {
    case deepFocus
    case night
}

public enum GateShieldState: Equatable, Sendable {
    case hardWindow(kind: HardKind)
    case canUnlock(opensToday: Int, limit: Int?)
    case waitingForApp(requestedAt: Date)
    case limitReached(limit: Int)
    case cooldown(until: Date)
    case alreadyOpen(until: Date)
}

public enum GateDenial: Error, Equatable, Sendable {
    case limitReached(limit: Int)
    case cooldown(until: Date)
    case alreadyOpen(until: Date)
}

public struct GateReshieldDecision: Equatable, Sendable {
    public let shouldReshield: Bool
    public let shouldStopMonitoring: Bool
}

/// DeviceActivityの開始・終了callbackで、再シールドと監視停止を同じ基準から決める。
public enum GateReshieldPolicy {
    public static func decision(
        grant: GateGrant?,
        now: Date,
        tolerance: TimeInterval
    ) -> GateReshieldDecision {
        guard let grant else {
            return GateReshieldDecision(
                shouldReshield: false,
                shouldStopMonitoring: true
            )
        }

        let effectiveTolerance = max(0, tolerance)
        let shouldReshield = now >= grant.endsAt.addingTimeInterval(-effectiveTolerance)
        return GateReshieldDecision(
            shouldReshield: shouldReshield,
            shouldStopMonitoring: shouldReshield
        )
    }
}

/// ゲートの表示・許可・期限切れを決める純関数。
///
/// 時計・カレンダー・設定はすべて呼び出し側から受け取る。拡張とアプリで同じ入力なら
/// 必ず同じ判断になり、テストでも日付境界や期限を固定できる。
public enum GatePolicy {
    /// 表示の優先順は、完全ブロック > アプリ待ち > 上限 > 待ち時間 > 開放可能。
    public static func shieldState(
        tokenData: Data,
        now: Date,
        settings: GateAppSetting,
        ledger: GateLedger,
        pendingUnlockRequest: GateUnlockRequest?,
        isDeepFocusWindowActive: Bool,
        isNightWindow: Bool,
        calendar: Calendar
    ) -> GateShieldState {
        if isDeepFocusWindowActive {
            return .hardWindow(kind: .deepFocus)
        }
        if isNightWindow {
            return .hardWindow(kind: .night)
        }

        if let request = validPendingRequest(
            tokenData: tokenData,
            request: pendingUnlockRequest,
            ledger: ledger,
            now: now
        ) {
            return .waitingForApp(requestedAt: request.requestedAt)
        }

        switch canGrant(
            tokenData: tokenData,
            now: now,
            settings: settings,
            ledger: ledger,
            calendar: calendar
        ) {
        case .failure(.limitReached(let limit)):
            return .limitReached(limit: limit)
        case .failure(.cooldown(let until)):
            return .cooldown(until: until)
        case .failure(.alreadyOpen(let until)):
            return .alreadyOpen(until: until)
        case .success:
            let entry = entry(for: tokenData, ledger: ledger, now: now, calendar: calendar)
            let effectiveSettings = setting(for: tokenData, supplied: settings)
            return .canUnlock(
                opensToday: entry?.opensToday ?? 0,
                limit: effectiveSettings.dailyOpenLimit
            )
        }
    }

    public static func shieldState(
        tokenData: Data,
        now: Date,
        settings: GateAppSettingsSnapshot,
        ledger: GateLedger,
        pendingUnlockRequest: GateUnlockRequest?,
        isDeepFocusWindowActive: Bool,
        isNightWindow: Bool,
        calendar: Calendar
    ) -> GateShieldState {
        shieldState(
            tokenData: tokenData,
            now: now,
            settings: settings.setting(for: tokenData),
            ledger: ledger,
            pendingUnlockRequest: pendingUnlockRequest,
            isDeepFocusWindowActive: isDeepFocusWindowActive,
            isNightWindow: isNightWindow,
            calendar: calendar
        )
    }

    /// 上限を先に、待ち時間を次に評価する。両方に該当するときは上限を表示する。
    public static func canGrant(
        tokenData: Data,
        now: Date,
        settings: GateAppSetting,
        ledger: GateLedger,
        calendar: Calendar
    ) -> Result<Void, GateDenial> {
        let effectiveSettings = setting(for: tokenData, supplied: settings)
        if let activeGrant = ledger.activeGrants
            .filter({ $0.tokenData == tokenData && now < $0.endsAt })
            .max(by: { $0.endsAt < $1.endsAt }) {
            return .failure(.alreadyOpen(until: activeGrant.endsAt))
        }

        let normalizedEntry = entry(
            for: tokenData,
            ledger: ledger,
            now: now,
            calendar: calendar
        )
        let opensToday = normalizedEntry?.opensToday ?? 0

        if let limit = effectiveSettings.dailyOpenLimit, opensToday >= limit {
            return .failure(.limitReached(limit: limit))
        }

        if effectiveSettings.cooldownMinutes > 0,
           let endedAt = normalizedEntry?.lastGrantEndedAt {
            let until = endedAt.addingTimeInterval(
                TimeInterval(effectiveSettings.cooldownMinutes * 60)
            )
            if until > now {
                return .failure(.cooldown(until: until))
            }
        }

        return .success(())
    }

    public static func canGrant(
        tokenData: Data,
        now: Date,
        settings: GateAppSettingsSnapshot,
        ledger: GateLedger,
        calendar: Calendar
    ) -> Result<Void, GateDenial> {
        canGrant(
            tokenData: tokenData,
            now: now,
            settings: settings.setting(for: tokenData),
            ledger: ledger,
            calendar: calendar
        )
    }

    /// 日が変わった回数だけを0へ戻す。待ち時間は日をまたいでも継続するため、
    /// `lastGrantEndedAt` はそのまま残す。
    public static func normalized(
        _ entry: GateLedgerEntry,
        now: Date,
        calendar: Calendar
    ) -> GateLedgerEntry {
        let currentDayKey = dayKey(for: now, calendar: calendar)
        guard entry.dayKey != currentDayKey else {
            return entry
        }

        var normalized = entry
        normalized.dayKey = currentDayKey
        normalized.opensToday = 0
        return normalized
    }

    /// 回数を進めて進行中解除を追加する。更新時刻は外から渡されたgrantの開始時刻を使う。
    public static func applyingGrant(
        ledger: GateLedger,
        grant: GateGrant,
        calendar: Calendar
    ) -> (expired: [GateGrant], ledger: GateLedger) {
        var updated = ledger
        if let index = updated.entries.firstIndex(where: { $0.tokenData == grant.tokenData }) {
            var entry = normalized(
                updated.entries[index],
                now: grant.startedAt,
                calendar: calendar
            )
            entry.opensToday += 1
            updated.entries[index] = entry
        } else {
            updated.entries.append(
                GateLedgerEntry(
                    tokenData: grant.tokenData,
                    dayKey: dayKey(for: grant.startedAt, calendar: calendar),
                    opensToday: 1,
                    lastGrantEndedAt: nil
                )
            )
        }
        updated.activeGrants.append(grant)

        let overflowCount = max(
            0,
            updated.activeGrants.count - GateConstants.maximumConcurrentGrants
        )
        let expired = Array(
            updated.activeGrants
                .sorted(by: grantPrecedes)
                .prefix(overflowCount)
        )
        if !expired.isEmpty {
            let expiredIDs = Set(expired.map(\.id))
            updated.activeGrants.removeAll { expiredIDs.contains($0.id) }
            for expiredGrant in expired {
                recordGrantEnded(
                    tokenData: expiredGrant.tokenData,
                    endedAt: grant.startedAt,
                    referenceDate: grant.startedAt,
                    calendar: calendar,
                    ledger: &updated
                )
            }
        }
        updated.updatedAt = grant.startedAt
        return (expired, updated)
    }

    /// 終了時刻を過ぎた解除を台帳から落とし、その終了時刻を待ち時間の起点へ移す。
    public static func expiringGrants(
        ledger: GateLedger,
        now: Date,
        additionallyExpiring grantIDs: Set<UUID> = [],
        calendar: Calendar = .autoupdatingCurrent
    ) -> (expired: [GateGrant], ledger: GateLedger) {
        let expired = ledger.activeGrants.filter {
            $0.endsAt <= now || grantIDs.contains($0.id)
        }
        guard !expired.isEmpty else {
            return ([], ledger)
        }

        let expiredIDs = Set(expired.map(\.id))
        var updated = ledger
        updated.activeGrants.removeAll { expiredIDs.contains($0.id) }

        for grant in expired {
            recordGrantEnded(
                tokenData: grant.tokenData,
                endedAt: grant.endsAt,
                referenceDate: now,
                calendar: calendar,
                ledger: &updated
            )
        }
        updated.updatedAt = now
        return (expired, updated)
    }

    /// 選択全体から、いま開放中のトークンだけを除く。
    ///
    /// CoreはmacOSでもテストするためiOS専用の`ApplicationToken`を型として固定せず、
    /// 同じCodable/Hashable契約へ一般化する。iOSからは`Set<ApplicationToken>`をそのまま渡せる。
    public static func tokensToShield<Token: Codable & Hashable>(
        selectionTokens: Set<Token>,
        ledger: GateLedger,
        now: Date
    ) -> Set<Token> {
        let grantedTokenData = Set(
            ledger.activeGrants
                .filter { now < $0.endsAt }
                .map(\.tokenData)
        )
        guard !grantedTokenData.isEmpty else {
            return selectionTokens
        }

        var tokensToShield = Set<Token>()
        tokensToShield.reserveCapacity(selectionTokens.count)
        for token in selectionTokens {
            // トークンを符号化できない場合は解除せず、シールド対象に残す。
            guard let tokenData = try? GateTokenCoding.encode(token) else {
                tokensToShield.insert(token)
                continue
            }
            if !grantedTokenData.contains(tokenData) {
                tokensToShield.insert(token)
            }
        }
        return tokensToShield
    }

    public static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04lld-%02lld-%02lld",
            Int64(components.year ?? 0),
            Int64(components.month ?? 0),
            Int64(components.day ?? 0)
        )
    }

    private static func validPendingRequest(
        tokenData: Data,
        request: GateUnlockRequest?,
        ledger: GateLedger,
        now: Date
    ) -> GateUnlockRequest? {
        guard let request,
              request.tokenData == tokenData,
              request.requestedAt <= now,
              now < request.requestedAt.addingTimeInterval(GateConstants.pendingRequestTTL) else {
            return nil
        }

        let latestActiveGrantStart = ledger.activeGrants
            .filter { $0.tokenData == tokenData }
            .map(\.startedAt)
            .max()
        let latestEndedGrant = ledger.entries
            .first { $0.tokenData == tokenData }?
            .lastGrantEndedAt
        if let latestGrantReference = [latestActiveGrantStart, latestEndedGrant]
            .compactMap({ $0 })
            .max(),
           request.requestedAt < latestGrantReference {
            return nil
        }
        return request
    }

    private static func grantPrecedes(_ lhs: GateGrant, _ rhs: GateGrant) -> Bool {
        if lhs.startedAt == rhs.startedAt {
            return lhs.id.uuidString < rhs.id.uuidString
        }
        return lhs.startedAt < rhs.startedAt
    }

    private static func recordGrantEnded(
        tokenData: Data,
        endedAt: Date,
        referenceDate: Date,
        calendar: Calendar,
        ledger: inout GateLedger
    ) {
        if let index = ledger.entries.firstIndex(where: { $0.tokenData == tokenData }) {
            if ledger.entries[index].lastGrantEndedAt.map({ $0 >= endedAt }) == true {
                return
            }
            ledger.entries[index].lastGrantEndedAt = endedAt
            return
        }

        ledger.entries.append(
            GateLedgerEntry(
                tokenData: tokenData,
                dayKey: dayKey(for: referenceDate, calendar: calendar),
                opensToday: 0,
                lastGrantEndedAt: endedAt
            )
        )
    }

    private static func entry(
        for tokenData: Data,
        ledger: GateLedger,
        now: Date,
        calendar: Calendar
    ) -> GateLedgerEntry? {
        ledger.entries
            .first { $0.tokenData == tokenData }
            .map { normalized($0, now: now, calendar: calendar) }
    }

    private static func setting(
        for tokenData: Data,
        supplied setting: GateAppSetting
    ) -> GateAppSetting {
        setting.tokenData == tokenData ? setting : GateDefaults.setting(for: tokenData)
    }
}
