import Foundation

enum AppURLs {
    private static let legalBase = "https://saku1110.github.io/dopabreak-legal"

    static var terms: URL { legalPage("terms") }
    static var privacy: URL { legalPage("privacy") }
    static var support: URL { legalPage("support") }

    static let supportEmail = "rebirth.sakuraya@gmail.com"

    private static func legalPage(_ name: String) -> URL {
        URL(string: "\(legalBase)/\(name)-\(legalLanguageSuffix).html")!
    }

    /// アプリの対応3言語（ja/en/ko）のうち、ユーザーの言語設定に最も近いページへ誘導する。
    /// Bundle.main.preferredLocalizations はCFBundleDevelopmentRegion(ja)へフォールバック済みの
    /// 値を返し、未対応言語の端末が ja に化けるため、生の端末設定 Locale.preferredLanguages を使う。
    private static var legalLanguageSuffix: String {
        legalLanguageSuffix(preferredLanguages: Locale.preferredLanguages)
    }

    static func legalLanguageSuffix(preferredLanguages: [String]) -> String {
        for language in preferredLanguages {
            switch language.split(separator: "-").first {
            case "ja": return "ja"
            case "ko": return "ko"
            case "en": return "en"
            default: continue
            }
        }
        return "en"
    }

    static func feedbackEmail(appVersion: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(
                name: "subject",
                value: "DopaBreak フィードバック (v\(appVersion))"
            )
        ]
        return components.url
    }
}
