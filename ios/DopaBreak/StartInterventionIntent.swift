import AppIntents
import DopaBreakCore
import Foundation

/// SNSAppCatalog の catalogID と1対1で対応する AppIntents 用の列挙。
/// ショートカットのオートメーション（doc12 §4）から選べるアプリ一覧として表示される。
enum SNSAppEnum: String, AppEnum {
    case instagram
    case x
    case tiktok
    case youtube
    case facebook
    case threads
    case line
    case safari

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "SNSアプリ"

    static var caseDisplayRepresentations: [SNSAppEnum: DisplayRepresentation] = [
        .instagram: DisplayRepresentation(title: "Instagram"),
        .x: DisplayRepresentation(title: "X"),
        .tiktok: DisplayRepresentation(title: "TikTok"),
        .youtube: DisplayRepresentation(title: "YouTube"),
        .facebook: DisplayRepresentation(title: "Facebook"),
        .threads: DisplayRepresentation(title: "Threads"),
        .line: DisplayRepresentation(title: "LINE"),
        .safari: DisplayRepresentation(title: "Safari")
    ]

    /// SNSAppCatalog.catalogID と同一の文字列（rawValue）。
    var catalogID: String { rawValue }
}

/// ショートカットのオートメーションから実行される、DopaBreak起動用のAppIntent（doc12 §2）。
/// `openAppWhenRun = true` により、対象アプリが開かれた瞬間にDopaBreakを前面起動する。
struct StartInterventionIntent: AppIntent {
    static var title: LocalizedStringResource = "DopaBreakで一呼吸"
    static var description = IntentDescription("対象アプリを開く前にDopaBreakの一呼吸フローを表示します。")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "アプリ")
    var app: SNSAppEnum

    init() {}

    init(app: SNSAppEnum) {
        self.app = app
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // AppIntentはアプリ本体とは別インスタンスで実行されるため、
        // SettingsStore（App Group UserDefaults）経由で起動要求を橋渡しする。
        if let settingsStore = try? SettingsStore() {
            settingsStore.pendingStartInterventionCatalogID = app.catalogID
        }
        return .result()
    }
}
