/// 設定画面が保持しているルール配列だけから、完全ブロック対象の有無を判定する。
public enum DeepFocusTargetGuard {
    public static func hasTargets(in rules: [TargetRule]) -> Bool {
        rules.contains { !$0.activitySelectionData.isEmpty }
    }
}
