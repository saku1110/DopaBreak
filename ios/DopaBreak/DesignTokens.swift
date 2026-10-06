import SwiftUI
import DopaBreakCore
import UIKit

extension Color {
    init(lockThemeColor color: LockThemeColor) {
        self.init(
            red: Double(color.red) / 255,
            green: Double(color.green) / 255,
            blue: Double(color.blue) / 255
        )
    }
}

enum DesignTokens {
    static let background = Color(red: 11.0 / 255.0, green: 13.0 / 255.0, blue: 15.0 / 255.0)
    static let backgroundRaised = Color(red: 15.0 / 255.0, green: 18.0 / 255.0, blue: 21.0 / 255.0)
    static let card = Color(red: 20.0 / 255.0, green: 23.0 / 255.0, blue: 27.0 / 255.0)
    static let cardPressed = Color(red: 25.0 / 255.0, green: 29.0 / 255.0, blue: 33.0 / 255.0)
    static let primaryText = Color(red: 244.0 / 255.0, green: 245.0 / 255.0, blue: 242.0 / 255.0)
    static let secondaryText = Color(red: 126.0 / 255.0, green: 134.0 / 255.0, blue: 148.0 / 255.0)
    static let tertiaryText = Color(red: 91.0 / 255.0, green: 98.0 / 255.0, blue: 108.0 / 255.0)
    static let accent = Color(red: 199.0 / 255.0, green: 249.0 / 255.0, blue: 77.0 / 255.0)
    static let danger = Color(red: 255.0 / 255.0, green: 107.0 / 255.0, blue: 90.0 / 255.0)
    static let hairline = Color.white.opacity(0.11)
    static let strongHairline = Color.white.opacity(0.18)
    static let cardRadius: CGFloat = 16
    static let horizontalPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 16

    /// キャラクターの役割別サイズ。画面ごとの微調整ではなく、情報階層で使い分ける。
    enum CharacterSize {
        static let hero: CGFloat = 200
        static let lead: CGFloat = 152
        static let header: CGFloat = 120
        static let support: CGFloat = 88
        static let inline: CGFloat = 44
    }

    /// タップ領域の最小辺。HIGの44×44ptを全操作要素の下限として使う。
    static let minTapTarget: CGFloat = 44
}

// MARK: - モーション

/// アニメーションの意味づけ。減衰比と応答時間はAppleの Designing Fluid Interfaces に合わせる。
/// 既定は臨界減衰（オーバーシュートなし）。跳ねを足すのは、ジェスチャ自身が勢いを持っていたときだけ。
enum DopaMotion {
    /// タップ・トグル・状態切替。減衰比1.0相当でオーバーシュートしない。
    static let control = Animation.smooth(duration: 0.3)
    /// 位置の移動・画面内の入れ替え。Appleの move 用 damping 1.0 / response 0.4 に対応。
    static let transition = Animation.smooth(duration: 0.4)
    /// ドロワー・シート等、指の勢いを引き継ぐ動き。damping 0.8 / response 0.3 に対応。
    static let momentum = Animation.snappy(duration: 0.3, extraBounce: 0.1)
    /// 達成の瞬間だけ使う祝福モーション。ここ以外で跳ねさせない。
    static let celebrate = Animation.bouncy(duration: 0.5, extraBounce: 0.15)
    /// 選択マーカーなど、押した指へ即座に返す小さな跳ね。
    static let select = Animation.spring(response: 0.25, dampingFraction: 0.72)
    /// グラフ・バッジなど、同じ面が形を変える遷移。
    static let morph = Animation.spring(response: 0.45, dampingFraction: 0.72)
}

// MARK: - タイポグラフィ（Dynamic Type）

extension Font.TextStyle {
    /// 指定ptに最も近い標準テキストスタイル。
    /// Dynamic Typeの拡大カーブをAppleの標準に合わせるための基準として使う。
    static func nearest(toPointSize size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<11.5: return .caption2      // 11pt
        case ..<12.5: return .caption       // 12pt
        case ..<14.0: return .footnote      // 13pt
        case ..<15.5: return .subheadline   // 15pt
        case ..<16.5: return .callout       // 16pt
        case ..<18.5: return .body          // 17pt
        case ..<21.0: return .title3        // 20pt
        case ..<25.0: return .title2        // 22pt
        case ..<31.0: return .title         // 28pt
        default: return .largeTitle         // 34pt
        }
    }
}

/// 実寸ptを保ったままDynamic Typeに追従させる書体モディファイア。
///
/// 既定の文字サイズ（Large）では `\.font(.system(size:weight:design:))` と完全に同じ見え方になる。
/// ユーザーが文字サイズを変えたときだけ、最も近い標準テキストスタイルと同じ比率で拡縮する。
/// tracking と lineSpacing も同じ比率で追従させる（固定ptのままだと拡大時に字間・行間だけ詰まって見えるため）。
private struct DopaFontModifier: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat
    private let baseSize: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design
    private let tracking: CGFloat
    private let lineSpacing: CGFloat?

    init(
        size: CGFloat,
        weight: Font.Weight,
        design: Font.Design,
        tracking: CGFloat,
        lineSpacing: CGFloat?,
        relativeTo textStyle: Font.TextStyle
    ) {
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.baseSize = size
        self.weight = weight
        self.design = design
        self.tracking = tracking
        self.lineSpacing = lineSpacing
    }

    /// 拡大率。baseSizeが0になることはないが、割り算前に保険をかける。
    private var scale: CGFloat {
        guard baseSize > 0 else { return 1 }
        return scaledSize / baseSize
    }

    func body(content: Content) -> some View {
        // 未指定の字間・行間には触らない。触ると子や親が持つ値を0で上書きしてしまう。
        content
            .font(.system(size: scaledSize, weight: weight, design: design))
            .modifier(OptionalTracking(value: tracking == 0 ? nil : tracking * scale))
            .modifier(OptionalLineSpacing(value: lineSpacing.map { $0 * scale }))
    }

    private struct OptionalTracking: ViewModifier {
        let value: CGFloat?

        func body(content: Content) -> some View {
            if let value {
                content.tracking(value)
            } else {
                content
            }
        }
    }

    private struct OptionalLineSpacing: ViewModifier {
        let value: CGFloat?

        func body(content: Content) -> some View {
            if let value {
                content.lineSpacing(value)
            } else {
                content
            }
        }
    }
}

extension View {
    /// E1のディスプレイ階層をDynamic Typeへ載せる。
    ///
    /// - Parameters:
    ///   - size: 既定文字サイズでの実寸pt。現行デザインの値をそのまま渡す。
    ///   - tracking: 字間。大きい文字ほど負に、小さい文字ほど正に振るAppleの原則に従う。
    ///   - lineSpacing: 行間。指定したときだけ適用する。
    ///   - textStyle: 拡縮の基準。省略時はsizeから最も近い標準スタイルを選ぶ。
    func dopaFont(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        tracking: CGFloat = 0,
        lineSpacing: CGFloat? = nil,
        relativeTo textStyle: Font.TextStyle? = nil
    ) -> some View {
        modifier(
            DopaFontModifier(
                size: size,
                weight: weight,
                design: design,
                tracking: tracking,
                lineSpacing: lineSpacing,
                relativeTo: textStyle ?? .nearest(toPointSize: size)
            )
        )
    }

    /// 巨大なディスプレイ数値が最大文字サイズでレイアウトを壊さないための上限。
    /// 本文は上限なしのまま、数字ヒーローにだけ使う。
    func dopaDisplayClamp() -> some View {
        dynamicTypeSize(...DynamicTypeSize.accessibility2)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }

    /// 操作要素の当たり判定を44×44pt以上にそろえる。見た目の寸法は変えない。
    func dopaHitTarget() -> some View {
        frame(minWidth: DesignTokens.minTapTarget, minHeight: DesignTokens.minTapTarget)
            .contentShape(Rectangle())
    }
}

// MARK: - ナビゲーションバー

enum DopaNavigationBar {
    /// システムのナビゲーションバーを使いつつ、見出しの書体だけE1（ブラックウェイト＋詰め字間）にそろえる。
    ///
    /// 背景はシステム既定のままにする。ここを不透明色で塗るとiOS 26のスクロール端の素材効果が消えるため、
    /// 上端では透明・スクロールで潜り込んだときだけ素材、という標準の挙動を保つ。
    /// 書体は `UIFontMetrics` を通してDynamic Typeにも追従させる。
    static func apply() {
        let primary = UIColor(DesignTokens.primaryText)

        let largeTitleAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: primary,
            .font: UIFontMetrics(forTextStyle: .largeTitle)
                .scaledFont(for: .systemFont(ofSize: 34, weight: .black)),
            .kern: -0.7
        ]
        let inlineTitleAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: primary,
            .font: UIFontMetrics(forTextStyle: .headline)
                .scaledFont(for: .systemFont(ofSize: 17, weight: .bold))
        ]

        let scrollEdge = UINavigationBarAppearance()
        scrollEdge.configureWithTransparentBackground()
        scrollEdge.largeTitleTextAttributes = largeTitleAttributes
        scrollEdge.titleTextAttributes = inlineTitleAttributes

        let standard = UINavigationBarAppearance()
        standard.configureWithDefaultBackground()
        standard.largeTitleTextAttributes = largeTitleAttributes
        standard.titleTextAttributes = inlineTitleAttributes

        let proxy = UINavigationBar.appearance()
        proxy.scrollEdgeAppearance = scrollEdge
        proxy.standardAppearance = standard
        proxy.compactAppearance = standard
    }
}

// MARK: - ボタン

struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        ScaledLabel(configuration: configuration, isEnabled: isEnabled)
    }

    /// `@ScaledMetric` は環境を読むため、ButtonStyle本体ではなく実Viewの中で解決させる。
    private struct ScaledLabel: View {
        let configuration: Configuration
        let isEnabled: Bool
        @ScaledMetric(relativeTo: .callout) private var minHeight: CGFloat = 56

        var body: some View {
            configuration.label
                .dopaFont(16, weight: .bold)
                .foregroundStyle(DesignTokens.background)
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .background(isEnabled ? DesignTokens.accent : DesignTokens.secondaryText.opacity(0.3))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(isEnabled ? 0.18 : 0))
                        .frame(height: 1)
                        .padding(.horizontal, 12)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .scaleEffect(configuration.isPressed ? 0.985 : 1)
                .opacity(configuration.isPressed ? 0.9 : 1)
                // 押下は即時・臨界減衰。離した瞬間に元へ戻る動きも同じばねで中断可能にする。
                .animation(DopaMotion.control, value: configuration.isPressed)
        }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ScaledLabel(configuration: configuration)
    }

    private struct ScaledLabel: View {
        let configuration: Configuration
        @ScaledMetric(relativeTo: .subheadline) private var minHeight: CGFloat = 54

        var body: some View {
            configuration.label
                .dopaFont(15, weight: .bold)
                .foregroundStyle(DesignTokens.primaryText)
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .background(configuration.isPressed ? DesignTokens.cardPressed : DesignTokens.backgroundRaised)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(DesignTokens.strongHairline, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .animation(DopaMotion.control, value: configuration.isPressed)
        }
    }
}

// MARK: - コンテナ・部品

struct CardContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.cardRadius, style: .continuous)
                    .stroke(DesignTokens.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cardRadius, style: .continuous))
    }
}

struct SmallLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .dopaFont(11, weight: .bold, design: .monospaced, tracking: 1.5)
            .foregroundStyle(DesignTokens.secondaryText)
            .textCase(.none)
    }
}

extension View {
    func dopaScreenBackground() -> some View {
        background(
            LinearGradient(
                colors: [DesignTokens.backgroundRaised.opacity(0.72), DesignTokens.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

// MARK: - Localized display copy

/// U+200B in a localized string is an optional semantic boundary, never a forced newline.
/// Try the full copy at its design size first; only use the two phrases when it cannot fit.
/// At accessibility sizes, allow additional natural lines instead of clipping or shrinking text.
struct DopaDisplayText: View {
    let text: String
    var size: CGFloat = 34
    var weight: Font.Weight = .black
    @Environment(\.locale) private var locale

    static let semanticBreak = "\u{200B}"

    static func plainText(_ text: String) -> String {
        // Preserve an existing separator; insert one when the marker is the only boundary.
        phrases(text).joined(separator: " ")
    }

    static func phrases(_ text: String) -> [String] {
        text.components(separatedBy: semanticBreak).map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Hangul otherwise permits breaks between syllables. Keep each space-delimited word intact.
    static func protectingWords(_ text: String, language: String?) -> String {
        guard language == "ko" || language == "en" else { return text }
        return text.split(separator: " ", omittingEmptySubsequences: false)
            .map { $0.map(String.init).joined(separator: "\u{2060}") }
            .joined(separator: " ")
    }

    private func label(_ value: String) -> some View {
        Text(verbatim: value)
            .typesettingLanguage(locale.language)
    }

    var body: some View {
        let plain = Self.plainText(text)
        let phrases = Self.phrases(text)
        ViewThatFits(in: .horizontal) {
            label(plain).fixedSize()
            if phrases.count == 2 {
                VStack(spacing: 5) {
                    ForEach(phrases.indices, id: \.self) { index in
                        label(phrases[index]).fixedSize()
                    }
                }
                .fixedSize()
            }
            label(Self.protectingWords(plain, language: locale.language.languageCode?.identifier))
                .fixedSize(horizontal: false, vertical: true)
        }
        .dopaFont(size, weight: weight, lineSpacing: 5)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: plain))
    }
}
