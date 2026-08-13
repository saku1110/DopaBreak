import Foundation

/// 月額課金者への年額移行オファー通知（docs/18 §4「年額移行オファー」）。
///
/// 一生に1回だけ。判定が成立した最初の再スケジュールで、次に送信可能な時刻へ予約する。
/// 予約済みの発火時刻を永続化して渡すのは、再スケジュールのたびに pending を全消ししてから
/// 積み直す実装のため、まだ発火していない予約を落とさないようにするため。
public enum AnnualUpgradeOfferPolicy {
    /// 月額を続けた日数のしきい値（3ヶ月）。
    public static let minimumSubscriptionDays = 90

    /// - Parameter scheduledFireDate: 過去に予約した発火時刻（未予約なら nil）。
    /// - Returns: 予約すべき発火時刻。予約しない場合は nil。
    public static func fireDate(
        subscription: SubscriptionEntitlementSnapshot?,
        isEnabled: Bool,
        scheduledFireDate: Date?,
        now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        // 対象者の確認を予約済み時刻より先に置く（解約セーブ側と同じ順序）。
        // 逆順だと、予約済みマーカーがあるだけで年額へ切り替えた直後の人や
        // 失効した人にも「月額3ヶ月目」の文面が届く。
        guard isEnabled,
              let subscription,
              subscription.isSubscription,
              subscription.isMonthly else {
            return nil
        }

        if let scheduledFireDate {
            // 送るのは1回だけ。まだ発火前のあいだは同じ時刻で予約し直す。
            return scheduledFireDate > now ? scheduledFireDate : nil
        }

        guard let eligibleFrom = calendar.date(
            byAdding: .day,
            value: minimumSubscriptionDays,
            to: subscription.initialPurchaseDate
        ),
            now >= eligibleFrom else {
            return nil
        }

        return NotificationQuietHours.nextDeliverableFireDate(after: now, calendar: calendar)
    }

    /// 予約済みマーカーを取り消して、次に条件が揃ったときへ持ち越すべきか。
    ///
    /// プラン通知をオフにすると予約自体が消える。それがまだ発火前なら誰にも届いていないので、
    /// マーカーを残すと一生に1回の機会を「数十秒オフにした」だけで失う。
    /// 発火時刻を過ぎているものは届いた可能性があるため残す（二重送信を作らない）。
    public static func shouldClearScheduledFireDate(
        isEnabled: Bool,
        scheduledFireDate: Date?,
        now: Date
    ) -> Bool {
        guard !isEnabled,
              let scheduledFireDate else {
            return false
        }
        return scheduledFireDate > now
    }
}

/// 自動更新オフを検知したときの引き止め通知（docs/18 §4「解約検知→セーブ通知」）。
///
/// 期限の3日前に1回だけ。期限日をキーに送信済みを記録するため、自動更新のオフ→オン→オフを
/// 繰り返しても同じ期間に二重で送らない。期限が更新されて別の期間になったときだけ再び対象になる。
public enum CancelSaveNotificationPolicy {
    /// 期限の何日前に出すか。
    public static let leadDays = 3

    /// - Parameters:
    ///   - sentExpirationDate: 送信済みマーカーの期限日（未送信なら nil）。
    ///   - sentFireDate: そのマーカーの発火時刻。まだ未来なら予約を積み直す。
    /// - Returns: 予約すべき発火時刻。予約しない場合は nil。
    ///   期限3日前が既に過ぎている場合は必ず nil（遅れて出す通知は作らない）。
    public static func fireDate(
        subscription: SubscriptionEntitlementSnapshot?,
        isEnabled: Bool,
        sentExpirationDate: Date?,
        sentFireDate: Date?,
        now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard isEnabled,
              let subscription,
              subscription.isSubscription,
              subscription.willAutoRenew == false,
              let expirationDate = subscription.expirationDate else {
            return nil
        }

        if let sentExpirationDate,
           isSamePeriod(sentExpirationDate, expirationDate) {
            // 同じ期間には1回だけ。まだ発火前のあいだは同じ時刻で予約し直す。
            guard let sentFireDate, sentFireDate > now else {
                return nil
            }
            return sentFireDate
        }

        guard let candidate = calendar.date(
            byAdding: .day,
            value: -leadDays,
            to: expirationDate
        ) else {
            return nil
        }

        return NotificationQuietHours.futureFireDate(
            for: candidate,
            now: now,
            calendar: calendar
        )
    }

    /// 期限日が同じ請求期間を指すか。UserDefaults を往復した Date の誤差を吸収する。
    public static func isSamePeriod(_ lhs: Date, _ rhs: Date) -> Bool {
        abs(lhs.timeIntervalSince(rhs)) < 1
    }
}
