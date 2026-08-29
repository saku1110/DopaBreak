import Foundation

public enum NightShieldConstants {
    /// 夜の窓を跨ぐたびに拡張を起こすためのDeviceActivity名。
    /// 他のDeviceActivity監視とは別枠で登録し、拡張側は活動名で分岐する。
    public static let activityName = "dopabreak.nightwindow"

    /// 夜間だけの完全ブロックを置くManagedSettingsストア名。
    /// 常時ブロック（"dopabreak.rules"）と分けておくと、夜明けに拡張が
    /// 夜間分だけを剥がせる。同じストアに混ぜると、朝の解除でディープフォーカスまで外れる。
    public static let shieldStoreName = "dopabreak.night"

    /// 就寝・起床が未設定の端末で使う既定値（23:00 / 7:00）。
    /// 設定画面の初期化と同じ値で、夜の窓を「未設定だから無効」にしないためのもの。
    public static let defaultBedTimeMinutes = 1_380
    public static let defaultWakeTimeMinutes = 420
}

/// いまが「夜」かを決める純関数。
///
/// 夜の範囲は設定済みの就寝時刻→起床時刻をそのまま使う（夜専用の時間帯設定は持たない）。
/// 跨日（23:00→7:00）と同日内（1:00→5:00）の両方が起きるため、大小関係で判定を分ける。
public enum NightWindowPolicy {
    /// DeviceActivityが受け付ける最短の区間（15分）。
    ///
    /// これを下回る窓で `startMonitoring` すると必ず `intervalTooShort` で失敗する。
    /// 失敗してから気づくのではなく、窓として成立しない時点で「窓なし」に倒す。
    public static let minimumWindowMinutes = 15

    /// 就寝から起床までの長さ（分）。跨日は翌日の起床までとして数える。
    /// 就寝と起床が同時刻なら0を返す（24時間とは読まない）。
    public static func windowLengthMinutes(bedTimeMinutes: Int, wakeTimeMinutes: Int) -> Int {
        let bed = normalizedMinutes(bedTimeMinutes)
        let wake = normalizedMinutes(wakeTimeMinutes)
        return ((wake - bed) % 1_440 + 1_440) % 1_440
    }

    /// 夜の窓として成立するか。
    ///
    /// 幅ゼロを「24時間ぶん」と読むこともできるが、それだと設定の初期化に失敗した端末が
    /// 終日ブロックになる。15分未満の窓も、監視を張れないので同じく窓なしとして扱う。
    public static func hasWindow(bedTimeMinutes: Int, wakeTimeMinutes: Int) -> Bool {
        windowLengthMinutes(
            bedTimeMinutes: bedTimeMinutes,
            wakeTimeMinutes: wakeTimeMinutes
        ) >= minimumWindowMinutes
    }

    public static func isNight(
        now: Date,
        bedTimeMinutes: Int,
        wakeTimeMinutes: Int,
        calendar: Calendar
    ) -> Bool {
        guard hasWindow(bedTimeMinutes: bedTimeMinutes, wakeTimeMinutes: wakeTimeMinutes) else {
            return false
        }

        let bed = normalizedMinutes(bedTimeMinutes)
        let wake = normalizedMinutes(wakeTimeMinutes)
        let components = calendar.dateComponents([.hour, .minute], from: now)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        if bed < wake {
            return minute >= bed && minute < wake
        }
        return minute >= bed || minute < wake
    }

    /// 拡張が受け取った境界コールバックを、控えに書かれた窓で検算するための入口。
    ///
    /// DeviceActivityのコールバックは、就寝・起床を変えた後に古いスケジュールぶんが
    /// 遅れて届くことがある。時刻で確かめずに従うと、新しい窓のまっただ中で
    /// 朝の解除が走る。適用も解除も「いま窓の内か外か」を見てから決める。
    public static func isNight(
        now: Date,
        snapshot: NightShieldSnapshot,
        calendar: Calendar
    ) -> Bool {
        isNight(
            now: now,
            bedTimeMinutes: snapshot.bedTimeMinutes,
            wakeTimeMinutes: snapshot.wakeTimeMinutes,
            calendar: calendar
        )
    }

    /// `SettingsStore` と同じ丸め。負値や24時間超も一度0...1439へ寄せてから比べる。
    ///
    /// 監視スケジュールの時分へ割る側も同じ丸めを通す。片方だけ素通しにすると、
    /// 古い保存値が入った端末で判定とスケジュールがずれる。
    public static func normalizedMinutes(_ value: Int) -> Int {
        ((value % 1_440) + 1_440) % 1_440
    }
}
