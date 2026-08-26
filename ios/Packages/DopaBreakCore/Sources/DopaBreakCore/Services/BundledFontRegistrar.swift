import CoreText
import Foundation

public enum DopaBreakBundledFont: String, CaseIterable, Sendable {
    case dotGothic16 = "DotGothic16-Regular"
    case zenKurenaido = "ZenKurenaido-Regular"
    case galmuri11 = "Galmuri11-Regular"
    case nanumPenScript = "NanumPen-Regular"

    fileprivate var resourceName: String {
        switch self {
        case .dotGothic16: return "DotGothic16"
        case .zenKurenaido: return "ZenKurenaido"
        case .galmuri11: return "Galmuri11"
        case .nanumPenScript: return "NanumPenScript"
        }
    }
}

/// Registers the app-bundled OFL fonts in each process that renders a theme.
public enum DopaBreakFontRegistrar {
    private static let lock = NSLock()
    private static var registeredFontNames = Set<String>()
    private static var failedDefaultFontNames = Set<String>()

    @discardableResult
    public static func registerBundledFonts(resourceBundleURL: URL? = nil) -> Set<String> {
        lock.lock()
        defer { lock.unlock() }

        var resolvedNames = Set<String>()
        for font in DopaBreakBundledFont.allCases {
            if resourceBundleURL == nil, failedDefaultFontNames.contains(font.rawValue) {
                continue
            }
            guard let url = resourceURL(for: font, resourceBundleURL: resourceBundleURL) else {
                if resourceBundleURL == nil {
                    failedDefaultFontNames.insert(font.rawValue)
                }
                continue
            }
            if registeredFontNames.contains(font.rawValue) {
                resolvedNames.insert(font.rawValue)
                continue
            }
            var unmanagedError: Unmanaged<CFError>?
            let registered = CTFontManagerRegisterFontsForURL(
                url as CFURL,
                .process,
                &unmanagedError
            )
            if registered || availablePostScriptNames().contains(font.rawValue) {
                registeredFontNames.insert(font.rawValue)
                failedDefaultFontNames.remove(font.rawValue)
                resolvedNames.insert(font.rawValue)
            } else if resourceBundleURL == nil {
                failedDefaultFontNames.insert(font.rawValue)
            }
        }
        return resolvedNames
    }

    /// Returns nil after any resource/registration failure so callers can choose a
    /// system font. SwiftUI never receives a missing custom-font name.
    public static func registeredName(for font: DopaBreakBundledFont) -> String? {
        registerBundledFonts().contains(font.rawValue) ? font.rawValue : nil
    }

    public static func resourceURL(
        for font: DopaBreakBundledFont,
        resourceBundleURL: URL? = nil
    ) -> URL? {
        for root in resourceRoots(explicitURL: resourceBundleURL) {
            for url in [
                root.appendingPathComponent("\(font.resourceName).ttf"),
                root.appendingPathComponent("Fonts/\(font.resourceName).ttf")
            ] where FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    private static func resourceRoots(explicitURL: URL?) -> [URL] {
        // An explicit URL is an exact resource scope. Falling through to another
        // bundle would let a missing app payload pass tests after process registration.
        if let explicitURL {
            return [explicitURL]
        }

        // App: Bundle.main is the .app. Widget: ascend from .appex through PlugIns
        // to the parent .app, which owns the only font payload.
        var roots = [Bundle.main.bundleURL]
        var ancestor = Bundle.main.bundleURL
        for _ in 0..<6 {
            ancestor.deleteLastPathComponent()
            roots.append(ancestor)
        }
        return roots
    }

    private static func availablePostScriptNames() -> Set<String> {
        Set((CTFontManagerCopyAvailablePostScriptNames() as? [String]) ?? [])
    }
}
