import Foundation

public struct SNSAppCatalogItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String { catalogID }

    public let catalogID: String
    public let displayName: String
    public let urlScheme: String?
    public let automationBundleID: String
    public let symbolName: String

    public init(
        catalogID: String,
        displayName: String,
        urlScheme: String?,
        automationBundleID: String,
        symbolName: String
    ) {
        self.catalogID = catalogID
        self.displayName = displayName
        self.urlScheme = urlScheme
        self.automationBundleID = automationBundleID
        self.symbolName = symbolName
    }
}

public enum SNSAppCatalog {
    public static let all: [SNSAppCatalogItem] = [
        SNSAppCatalogItem(
            catalogID: "instagram",
            displayName: "Instagram",
            urlScheme: "instagram://app",
            automationBundleID: "com.burbn.instagram",
            symbolName: "camera"
        ),
        SNSAppCatalogItem(
            catalogID: "x",
            displayName: "X",
            urlScheme: "twitter://",
            automationBundleID: "com.atebits.Tweetie2",
            symbolName: "xmark"
        ),
        SNSAppCatalogItem(
            catalogID: "tiktok",
            displayName: "TikTok",
            urlScheme: "snssdk1233://",
            automationBundleID: "com.zhiliaoapp.musically",
            symbolName: "music.note"
        ),
        SNSAppCatalogItem(
            catalogID: "youtube",
            displayName: "YouTube",
            urlScheme: "youtube://",
            automationBundleID: "com.google.ios.youtube",
            symbolName: "play.rectangle"
        ),
        SNSAppCatalogItem(
            catalogID: "facebook",
            displayName: "Facebook",
            urlScheme: "fb://",
            automationBundleID: "com.facebook.Facebook",
            symbolName: "person.2"
        ),
        SNSAppCatalogItem(
            catalogID: "threads",
            displayName: "Threads",
            urlScheme: "barcelona://",
            automationBundleID: "com.burbn.barcelona",
            symbolName: "at"
        ),
        SNSAppCatalogItem(
            catalogID: "line",
            displayName: "LINE",
            urlScheme: "line://",
            automationBundleID: "jp.naver.line",
            symbolName: "message"
        ),
        SNSAppCatalogItem(
            catalogID: "safari",
            displayName: "Safari",
            urlScheme: nil,
            automationBundleID: "com.apple.mobilesafari",
            symbolName: "safari"
        )
    ]

    public static func app(catalogID: String) -> SNSAppCatalogItem? {
        all.first { $0.catalogID == catalogID }
    }

    public static func contains(catalogID: String) -> Bool {
        app(catalogID: catalogID) != nil
    }
}
