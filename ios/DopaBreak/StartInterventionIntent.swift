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

    static var typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource(
            "shortcuts.app.type_name",
            defaultValue: "SNSアプリ"
        )
    )

    static var caseDisplayRepresentations: [SNSAppEnum: DisplayRepresentation] = [
        .instagram: DisplayRepresentation(
            title: LocalizedStringResource("shortcuts.app.instagram", defaultValue: "Instagram")
        ),
        .x: DisplayRepresentation(
            title: LocalizedStringResource("shortcuts.app.x", defaultValue: "X")
        ),
        .tiktok: DisplayRepresentation(
            title: LocalizedStringResource("shortcuts.app.tiktok", defaultValue: "TikTok")
        ),
        .youtube: DisplayRepresentation(
            title: LocalizedStringResource("shortcuts.app.youtube", defaultValue: "YouTube")
        ),
        .facebook: DisplayRepresentation(
            title: LocalizedStringResource("shortcuts.app.facebook", defaultValue: "Facebook")
        ),
        .threads: DisplayRepresentation(
            title: LocalizedStringResource("shortcuts.app.threads", defaultValue: "Threads")
        ),
        .line: DisplayRepresentation(
            title: LocalizedStringResource("shortcuts.app.line", defaultValue: "LINE")
        ),
        .safari: DisplayRepresentation(
            title: LocalizedStringResource("shortcuts.app.safari", defaultValue: "Safari")
        )
    ]

    /// SNSAppCatalog.catalogID と同一の文字列（rawValue）。
    var catalogID: String { rawValue }
}

/// ショートカットのオートメーションから実行される、DopaBreak起動用のAppIntent（doc12 §2）。
/// `openAppWhenRun = true` により、対象アプリが開かれた瞬間にDopaBreakを前面起動する。
struct StartInterventionIntent: AppIntent {
    static var title = LocalizedStringResource(
        "shortcuts.intervention.title",
        defaultValue: "DopaBreakで一呼吸"
    )
    static var description = IntentDescription(
        LocalizedStringResource(
            "shortcuts.intervention.description",
            defaultValue: "対象アプリを開く前にDopaBreakの一呼吸フローを表示します。"
        )
    )
    static var openAppWhenRun: Bool = true

    @Parameter(
        title: LocalizedStringResource(
            "shortcuts.intervention.parameter.app",
            defaultValue: "アプリ"
        )
    )
    var app: SNSAppEnum?

    init() {}

    init(app: SNSAppEnum?) {
        self.app = app
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // AppIntentはアプリ本体とは別インスタンスで実行されるため、
        // SettingsStore（App Group UserDefaults）経由で起動要求を橋渡しする。
        if let settingsStore = try? SettingsStore() {
            guard !ReinterventionShield.suppressesIntervention() else {
                settingsStore.pendingStartInterventionCatalogID = nil
                settingsStore.pendingStartInterventionAutoResolve = false
                settingsStore.pendingStartInterventionRequestedAt = nil
                return .result()
            }
            settingsStore.pendingStartInterventionRequestedAt = Date()
            if let app {
                settingsStore.pendingStartInterventionCatalogID = app.catalogID
                settingsStore.pendingStartInterventionAutoResolve = false
            } else {
                settingsStore.pendingStartInterventionCatalogID = nil
                settingsStore.pendingStartInterventionAutoResolve = true
            }
        }
        return .result()
    }
}
