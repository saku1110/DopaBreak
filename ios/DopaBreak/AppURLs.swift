import Foundation

enum AppURLs {
    static let terms = URL(string: "https://dopabreak.app/terms")!
    static let privacy = URL(string: "https://dopabreak.app/privacy")!
    static let supportEmail = "rebirth.sakuraya@gmail.com"

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
