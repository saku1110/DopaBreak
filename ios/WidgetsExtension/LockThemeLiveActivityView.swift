import DopaBreakCore
import SwiftUI
import UIKit

enum LockThemeLayoutElement: Hashable {
    case contentBounds
    case cardBounds
    case eyebrow
    case goal(Int)
    case goalMarker(Int)
    case cancelledSummary
    case attemptedSummary
    case blueprintCancelledCell
    case blueprintCancelledText
    case blueprintAttemptedCell
    case blueprintAttemptedText
    case e1Goal(Int)
    case e1Divider
    case e1Summary
}

enum LockThemeFontPolicy {
    static func bundledFont(for theme: LockTheme, locale: Locale) -> DopaBreakBundledFont? {
        let isKorean = locale.language.languageCode?.identifier == "ko"
        switch theme {
        case .gaming:
            return isKorean ? .galmuri11 : .dotGothic16
        case .note:
            return isKorean ? .nanumPenScript : .zenKurenaido
        default:
            return nil
        }
    }
}

enum LockThemeSurfaceShape: Equatable {
    /// Live Activity / ウィジェット本番。システムのコンテナ角丸へ自動一致。
    case containerRelative
    /// アプリ内プレビュー。コンテナが無いので固定値を使う。
    case fixed(CGFloat)
}

/// The canonical lock-screen card used by both the Widget Extension and the in-app preview.
/// A full-height 160pt canvas and shrinking goal rows keep every theme within WidgetKit's limit.
struct LockThemeLiveActivityView: View {
    static let maximumHeight: CGFloat = 160
    static let maximumGoals = 5
    static let cardInset: CGFloat = 16
    /// iPhone 17 Pro Max / iOS 26.5で実測した23.5ptに近いプレビュー用代表値。
    static let previewCornerRadius: CGFloat = 22

    static func goalFontIncrease(forGoalCount count: Int) -> CGFloat {
        switch count {
        case ...1: 5
        case 2: 4
        case 3: 3
        case 4: 0
        default: -2
        }
    }

    static func summaryFontIncrease(forGoalCount count: Int) -> CGFloat {
        switch count {
        case ...2: 1.5
        case 3: 1
        case 4: 0.5
        default: 0
        }
    }

    static func e1GoalMinimumHeight(forGoalCount count: Int) -> CGFloat {
        let lineHeight = e1GoalLineHeight(forGoalCount: count)
        switch count {
        case ...1:
            return 60
        case 2:
            return lineHeight * 2 + 1
        default:
            return lineHeight + 2
        }
    }

    static func e1GoalLineHeight(forGoalCount count: Int) -> CGFloat {
        let fontSize = 15 + goalFontIncrease(forGoalCount: count)
        return UIFont.systemFont(ofSize: fontSize, weight: .bold).lineHeight
    }

    let theme: LockTheme
    let goalTitles: [String]
    let cancelledCount: Int
    let attemptCount: Int
    var blockWindows: [BlockWindowStatus] = []
    var surfaceShape: LockThemeSurfaceShape = .fixed(Self.previewCornerRadius)
    var isMeasuring = false
    var localizationBundle: Bundle = .main
    var locale: Locale = .autoupdatingCurrent
    var layoutObserver: (([LockThemeLayoutElement: CGRect]) -> Void)? = nil

    private var titles: [String] { Array(goalTitles.prefix(Self.maximumGoals)) }
    private var goalCount: Int { max(titles.count, 1) }
    private var surfaceClipShape: AnyShape {
        switch surfaceShape {
        case .containerRelative:
            return AnyShape(ContainerRelativeShape())
        case .fixed(let radius):
            return AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }

    @ViewBuilder
    private func surfaceBorder<S: ShapeStyle>(
        _ style: S,
        lineWidth: CGFloat
    ) -> some View {
        switch surfaceShape {
        case .containerRelative:
            ContainerRelativeShape().strokeBorder(style, lineWidth: lineWidth)
        case .fixed(let radius):
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(style, lineWidth: lineWidth)
        }
    }
    private var goalFontIncrease: CGFloat { Self.goalFontIncrease(forGoalCount: goalCount) }
    private var summaryFontIncrease: CGFloat { Self.summaryFontIncrease(forGoalCount: goalCount) }
    private var eyebrow: String {
        localizationBundle.localizedString(
            forKey: "live_activity.goal.eyebrow",
            value: "あなたの目標",
            table: nil
        )
    }
    private var blockOrCancelledText: Text {
        Self.blockStatusText(blockWindows, localizationBundle: localizationBundle) ?? Text(cancelled)
    }

    static func blockStatusText(_ windows: [BlockWindowStatus], localizationBundle: Bundle = .main) -> Text? {
        guard let block = windows.first(where: { $0.endsAt.map { $0 > Date() } ?? true }) else { return nil }
        let key: String
        let fallback: String
        switch block.trigger {
        case .manual: key = "block.live.manual"; fallback = "手動 残り "
        case .weeklySchedule: key = "block.live.weekly"; fallback = "予定 終了 "
        case .night: key = "block.live.night"; fallback = "就寝中 起床 "
        }
        let label = localizationBundle.localizedString(forKey: key, value: fallback, table: nil)
        guard let end = block.endsAt else {
            return Text(localizationBundle.localizedString(forKey: "block.live.continues", value: "ブロック中", table: nil))
        }
        if block.trigger == .manual {
            return Text(label) + Text(timerInterval: min(Date(), end)...end, countsDown: true)
        }
        return Text(label) + Text(end, style: .time)
    }

    private var cancelled: String {
        localizedFormat(
            key: "live_activity.summary.cancelled",
            defaultValue: "今日は%lld回 開くのをやめた",
            count: cancelledCount
        )
    }
    private var attempted: String {
        localizedFormat(
            key: "live_activity.summary.attempted",
            defaultValue: "開こうとした %lld回",
            count: attemptCount
        )
    }

    var body: some View {
        Group {
            if isMeasuring {
                contentBody
            } else {
                contentBody
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(height: Self.maximumHeight)
                    .clipped()
            }
        }
        .background {
            if theme == .liquidGlass, case .fixed = surfaceShape {
                LockThemeGlassPreviewBackdrop()
                    .clipShape(surfaceClipShape)
            }
        }
        .modifier(LockThemeOuterSurface(
            surfaceShape: surfaceShape,
            enabled: theme == .liquidGlass || theme == .monochrome || theme == .spiderWeb,
            showsPreviewRim: theme == .liquidGlass
        ))
        .layoutAnchor(.cardBounds)
        .overlayPreferenceValue(LockThemeLayoutAnchorKey.self) { anchors in
            GeometryReader { proxy in
                Color.clear
                    .onAppear { publishLayout(anchors, in: proxy) }
                    .onChange(of: anchors.count) { _, _ in publishLayout(anchors, in: proxy) }
                    .onChange(of: proxy.size) { _, _ in publishLayout(anchors, in: proxy) }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var contentBody: some View {
        Group {
            switch theme {
            case .e1: blackLime
            case .gaming: gaming
            case .asagiri: asagiri
            case .monochrome: monochrome
            case .liquidGlass: liquidGlass
            case .kpop: kpop
            case .kawaiiPink: kawaiiPink
            case .note: note
            case .blueprint: blueprint
            case .spiderWeb: spiderWeb
            }
        }
    }

    private var blackLime: some View {
        let goalSize = adaptiveGoalSize(15)
        let goalUIFont = UIFont.systemFont(ofSize: goalSize, weight: .bold)
        let markerScale = goalSize / 15
        let markerHeight = 2 * markerScale
        return VStack(alignment: .leading, spacing: densityValue(one: 14, two: 4, three: 6, four: 4.5, five: 3.5)) {
            eyebrowText(color: rgb(139, 146, 158), tracking: 1.5)
                .textCase(.uppercase)
            VStack(alignment: .leading, spacing: densityValue(one: 5, two: 3, three: 6, four: 4.5, five: 3.5)) {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Rectangle()
                            .fill(rgb(184, 255, 61))
                            .frame(width: 10 * markerScale, height: markerHeight)
                            .offset(
                                y: scaledGoalCapCenterOffset(
                                    title: title,
                                    font: goalUIFont,
                                    availableWidth: 335
                                )
                            )
                            .layoutAnchor(.goalMarker(index))
                            .markerCenterAlignedToCapHeight(of: goalUIFont)
                        Text(title)
                            .font(.system(size: goalSize, weight: .bold))
                            .foregroundStyle(rgb(244, 242, 236))
                            .lineLimit(goalCount <= 2 ? 2 : 1)
                            .lineSpacing(densityValue(one: 1, two: 1, three: 0, four: 0, five: 0))
                            .minimumScaleFactor(goalMinimumScaleFactor)
                            .truncationMode(.tail)
                            .allowsTightening(true)
                            .accessibilityLabel(title)
                            .layoutAnchor(.goal(index))
                    }
                    .frame(minHeight: Self.e1GoalMinimumHeight(forGoalCount: goalCount))
                    .layoutAnchor(.e1Goal(index))
                }
            }
            Rectangle().fill(rgb(139, 146, 158).opacity(0.25)).frame(height: 1)
                .layoutAnchor(.e1Divider)
            HStack(spacing: 14) {
                blockOrCancelledText.foregroundStyle(rgb(184, 255, 61)).layoutAnchor(.cancelledSummary)
                Text(attempted).foregroundStyle(rgb(139, 146, 158)).layoutAnchor(.attemptedSummary)
            }
            .font(.system(size: adaptiveSummarySize(12), weight: .semibold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.62)
            .layoutAnchor(.e1Summary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .layoutAnchor(.contentBounds)
        .padding(.horizontal, Self.cardInset)
        .padding(.vertical, densityValue(one: 8, two: 6, three: 6, four: 6, five: 6))
        .frame(height: Self.maximumHeight)
        .background(rgb(20, 23, 27))
        .overlay(alignment: .leading) { Rectangle().fill(rgb(184, 255, 61)).frame(width: 3) }
        .clipShape(surfaceClipShape)
    }

    private var gaming: some View {
        let font = LockThemeFontPolicy.bundledFont(for: .gaming, locale: locale) ?? .dotGothic16
        let goalSize = adaptiveGoalSize(15.5)
        let goalUIFont = uiFont(font, size: goalSize, fallbackWeight: .regular)
        let markerSize = 12 * goalSize / 15
        return ZStack {
            rgb(10, 10, 20)
            RepeatingLines(spacing: 4).stroke(.white.opacity(0.035), lineWidth: 1)
            VStack(alignment: .leading, spacing: densityValue(one: 13, two: 8, three: 6, four: 4.5, five: 3)) {
                Text(eyebrow)
                    .font(customFont(font, size: 11, fallbackWeight: .regular))
                    .tracking(1.2)
                    .foregroundStyle(rgb(0, 229, 255))
                    .shadow(color: rgb(0, 229, 255).opacity(0.65), radius: 3)
                    .layoutAnchor(.eyebrow)
                VStack(spacing: densityValue(one: 4, two: 3, three: 6, four: 4.5, five: 3)) {
                    ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Rectangle()
                                .stroke(rgb(0, 229, 255), lineWidth: 1.5)
                                .frame(width: markerSize, height: markerSize)
                                .offset(
                                    y: scaledGoalCapCenterOffset(
                                        title: title,
                                        font: goalUIFont,
                                        availableWidth: 339,
                                        unscaledOffset: goalCount >= 3 ? 1 : 0
                                    )
                                )
                                .shadow(color: rgb(0, 229, 255).opacity(0.8), radius: 2)
                                .layoutAnchor(.goalMarker(index))
                                .markerCenterAlignedToCapHeight(of: goalUIFont)
                            goalText(
                                title,
                                font: customFont(font, size: goalSize, fallbackWeight: .regular),
                                color: rgb(234, 234, 242)
                            )
                            .layoutAnchor(.goal(index))
                        }
                        // The 52pt one-goal row keeps a stable >2pt margin over the 120pt
                        // typography-span floor while preserving the 160pt card height.
                        .frame(height: densityValue(one: 52, two: 34, three: 24, four: 20, five: 17))
                    }
                }
                RepeatingDashes().stroke(rgb(0, 229, 255).opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [5, 5])).frame(height: 1)
                HStack(spacing: 12) {
                    blockOrCancelledText.foregroundStyle(rgb(0, 229, 255)).layoutAnchor(.cancelledSummary)
                    Spacer(minLength: 4)
                    Text(attempted).foregroundStyle(rgb(138, 143, 168)).layoutAnchor(.attemptedSummary)
                }
                .font(customFont(font, size: adaptiveSummarySize(10.5), fallbackWeight: .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutAnchor(.contentBounds)
            .padding(.horizontal, Self.cardInset)
        }
        .frame(height: Self.maximumHeight)
        .overlay {
            surfaceBorder(
                LinearGradient(
                    colors: [rgb(0, 229, 255), rgb(124, 77, 255), rgb(255, 46, 138)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 2
            )
                .shadow(color: rgb(124, 77, 255).opacity(0.55), radius: 5)
        }
        .clipShape(surfaceClipShape)
    }

    private var asagiri: some View {
        VStack(spacing: densityValue(one: 11, two: 7, three: 5, four: 3, five: 2)) {
            eyebrowText(color: rgb(91, 105, 119), tracking: 3.2)
            VStack(spacing: densityValue(one: 4, two: 3, three: 1.25, four: 0.75, five: 0.5)) {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    centeredGoalText(title, size: adaptiveGoalSize(15), weight: .light, color: rgb(31, 37, 47))
                        .tracking(0.45)
                        .frame(height: densityValue(one: 46, two: 33, three: 23, four: 19, five: 17))
                        .layoutAnchor(.goal(index))
                    if index < titles.count - 1 {
                        Rectangle().fill(rgb(91, 126, 153).opacity(0.45)).frame(width: 26, height: 1)
                    }
                }
            }
            asagiriCancelledText()
                .lineLimit(1)
                .layoutAnchor(.cancelledSummary)
            Text(attempted)
                .font(.system(size: adaptiveSummarySize(10.5), weight: .regular))
                .foregroundStyle(rgb(91, 105, 119))
                .lineLimit(1)
                .layoutAnchor(.attemptedSummary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .layoutAnchor(.contentBounds)
        .padding(.vertical, 6)
        .padding(.horizontal, Self.cardInset)
        .frame(height: Self.maximumHeight)
        .background {
            ZStack {
                rgb(237, 241, 245)
                VStack { LinearGradient(colors: [.white.opacity(0.9), .clear], startPoint: .top, endPoint: .bottom).frame(height: 44); Spacer() }
                LinearGradient(colors: [.clear, .white.opacity(0.82), .clear], startPoint: .top, endPoint: .bottom)
            }
        }
    }

    private var monochrome: some View {
        VStack(alignment: .leading, spacing: densityValue(one: 19, two: 9, three: 6, four: 4.5, five: 3)) {
            eyebrowText(color: .primary.opacity(0.8), tracking: 2)
            VStack(spacing: 0) {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    goalText(title, size: adaptiveGoalSize(15), weight: .bold, color: .primary)
                        .frame(height: densityValue(one: 46, two: 33, three: 25, four: 20, five: 17))
                        .layoutAnchor(.goal(index))
                    if index < titles.count - 1 {
                        Rectangle().fill(Color.primary.opacity(0.18)).frame(height: 1)
                    }
                }
            }
            HStack(spacing: 7) {
                glassCapsule(blockOrCancelledText).layoutAnchor(.cancelledSummary)
                glassCapsule(Text(attempted)).layoutAnchor(.attemptedSummary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .layoutAnchor(.contentBounds)
        .padding(.vertical, 8)
        .padding(.horizontal, Self.cardInset)
        .frame(height: Self.maximumHeight)
        .background(Color(uiColor: .systemBackground))
    }

    /// Wallpaper translucency belongs to ActivityKit. Keep content out of glassEffect:
    /// WidgetKit remote rendering can flatten that modifier and lose the text.
    private var liquidGlass: some View {
        VStack(alignment: .leading, spacing: densityValue(one: 19, two: 9, three: 6, four: 4.5, five: 3)) {
            eyebrowText(color: .white.opacity(0.9), tracking: 2)
                .shadow(color: .black.opacity(0.55), radius: 1, y: 1)
            VStack(spacing: 0) {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    goalText(title, size: adaptiveGoalSize(15), weight: .bold, color: .white)
                        .shadow(color: .black.opacity(0.6), radius: 1.5, y: 1)
                        .frame(height: densityValue(one: 46, two: 33, three: 25, four: 20, five: 17))
                        .layoutAnchor(.goal(index))
                    if index < titles.count - 1 {
                        Rectangle().fill(.white.opacity(0.24)).frame(height: 1)
                    }
                }
            }
            HStack(spacing: 7) {
                glassCapsule(blockOrCancelledText, translucent: true).layoutAnchor(.cancelledSummary)
                glassCapsule(Text(attempted), translucent: true).layoutAnchor(.attemptedSummary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .layoutAnchor(.contentBounds)
        .padding(.vertical, 8)
        .padding(.horizontal, Self.cardInset)
        .frame(height: Self.maximumHeight)
        .background {
            // The translucent scrim protects white labels without painting an opaque card.
            LinearGradient(colors: [.black.opacity(0.18), .black.opacity(0.24)], startPoint: .topLeading, endPoint: .bottomTrailing)
            LinearGradient(stops: [
                .init(color: .white.opacity(0.07), location: 0),
                .init(color: .white.opacity(0.015), location: 0.28),
                .init(color: .clear, location: 0.55),
                .init(color: .white.opacity(0.025), location: 1)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        }

    }

    private var spiderWeb: some View {
        let goalSize = adaptiveGoalSize(15)
        let goalUIFont = UIFont.systemFont(ofSize: goalSize, weight: .bold)
        let markerSize = max(14, goalSize * 0.82).rounded()
        return VStack(alignment: .leading, spacing: densityValue(one: 19, two: 9, three: 6, four: 4.5, five: 3)) {
            eyebrowText(color: .white.opacity(0.9), tracking: 1.5)
            VStack(spacing: 0) {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        LockThemeSpiderMarker().fill(.white)
                            .frame(width: markerSize, height: markerSize)
                            .offset(y: scaledGoalCapCenterOffset(title: title, font: goalUIFont, availableWidth: 331))
                            .layoutAnchor(.goalMarker(index))
                            .markerCenterAlignedToCapHeight(of: goalUIFont)
                            .accessibilityHidden(true)
                        goalText(title, size: goalSize, weight: .bold, color: .white)
                            .layoutAnchor(.goal(index))
                    }
                    .frame(height: densityValue(one: 46, two: 33, three: 25, four: 20, five: 17))
                }
            }
            HStack(spacing: 7) {
                webSummaryPill(blockOrCancelledText).layoutAnchor(.cancelledSummary)
                webSummaryPill(Text(attempted)).layoutAnchor(.attemptedSummary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .layoutAnchor(.contentBounds)
        .padding(.vertical, 8)
        .padding(.horizontal, Self.cardInset)
        .frame(height: Self.maximumHeight)
        .background {
            LinearGradient(colors: [rgb(202, 22, 40), rgb(150, 12, 33)], startPoint: .topLeading, endPoint: .bottomTrailing)
            LockThemeWebPattern()
                .stroke(LinearGradient(colors: [.white.opacity(0.08), .white.opacity(0.36)], startPoint: .leading, endPoint: .trailing), lineWidth: 0.55)
        }
        .overlay(alignment: .bottom) {
            // An inset accent avoids painting over the system's curved outer edge.
            Capsule().fill(rgb(66, 153, 255).opacity(0.85))
                .frame(height: 1)
                .padding(.horizontal, 24)
                .padding(.bottom, 3)
        }
    }

    private func webSummaryPill(_ text: Text) -> some View {
        text
            .font(.system(size: adaptiveSummarySize(11.5), weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1).minimumScaleFactor(0.58)
            .padding(.horizontal, 9).frame(minHeight: 24)
            .background(Capsule().fill(.black.opacity(0.12)))
            .overlay { Capsule().strokeBorder(rgb(66, 153, 255).opacity(0.72), lineWidth: 0.75) }
    }

    private var kpop: some View {
        let goalSize = adaptiveGoalSize(15)
        let goalUIFont = UIFont.systemFont(ofSize: goalSize, weight: .black)
        let markerScale = goalSize / 15
        let markerSize = 9 * markerScale
        let markerUIFont = UIFont.systemFont(ofSize: markerSize, weight: .bold)
        return VStack(spacing: densityValue(one: 8, two: 6, three: 6, four: 4, five: 3)) {
            Text(eyebrow)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 15).frame(height: 22)
                .background(rgb(238, 52, 137)).clipShape(Capsule())
                .layoutAnchor(.eyebrow)
            VStack(spacing: densityValue(one: 4, two: 3, three: 6, four: 4, five: 3)) {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("★")
                            .font(.system(size: markerSize, weight: .bold))
                            .foregroundStyle(rgb(238, 52, 137))
                            .baselineOffset(
                                glyphCapCenterOffset(markerFont: markerUIFont, goalFont: goalUIFont) - 1.5
                            )
                            .frame(height: goalUIFont.capHeight)
                            .offset(
                                y: (goalCount == 2
                                    ? 1
                                    : ((3...4).contains(goalCount) || (goalCount == 5 && index == 2) ? 0.5 : 0))
                                    + scaledGoalCapCenterOffset(
                                        title: title,
                                        font: goalUIFont,
                                        availableWidth: 324
                                    )
                            )
                            .layoutAnchor(.goalMarker(index))
                            .markerCenterAlignedToCapHeight(of: goalUIFont)
                        goalText(title, size: goalSize, weight: .black, color: rgb(35, 31, 38))
                            .layoutAnchor(.goal(index))
                    }
                    // 削除した縦バー（5 * markerScale）とその spacing 7 を先頭余白として残し、
                    // ★の描画位置とテキストの実利用幅をバー削除前と一致させる。
                    .padding(.leading, 5 * markerScale + 7)
                    .padding(.trailing, 8)
                    .frame(maxWidth: .infinity, minHeight: densityValue(one: 64, two: 33, three: 24, four: 19, five: 16), alignment: .leading)
                    .background {
                        TicketStubShape(notchRadius: 4)
                            .fill(.white, style: FillStyle(eoFill: true))
                            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                    }
                }
            }
            HStack(spacing: 8) {
                blockOrCancelledText.layoutAnchor(.cancelledSummary)
                Text("★").foregroundStyle(rgb(238, 52, 137))
                Text(attempted).layoutAnchor(.attemptedSummary)
            }
            .font(.system(size: adaptiveSummarySize(9.5), weight: .bold))
            .tracking(0.8)
            .foregroundStyle(.white)
            .lineLimit(1).minimumScaleFactor(0.65)
            .frame(maxWidth: .infinity, minHeight: 24)
            .background(rgb(35, 31, 38))
            .padding(.horizontal, -Self.cardInset)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .layoutAnchor(.contentBounds)
        .padding(.horizontal, Self.cardInset)
        .frame(height: Self.maximumHeight)
        .background {
            ZStack {
                rgb(249, 246, 251)
                LinearGradient(colors: [.clear, rgb(53, 195, 232).opacity(0.12), rgb(238, 52, 137).opacity(0.12)], startPoint: .bottomLeading, endPoint: .topTrailing)
            }
        }
        .overlay { surfaceBorder(LinearGradient(colors: [rgb(238, 52, 137), rgb(138, 77, 232), rgb(53, 195, 232)], startPoint: .leading, endPoint: .trailing), lineWidth: 2.5) }
        .clipShape(surfaceClipShape)
    }

    private var kawaiiPink: some View {
        let goalSize = adaptiveGoalSize(13)
        let markerSize = 10 * goalSize / 15
        let goalUIFont = roundUIFont(size: goalSize)
        let markerUIFont = UIFont.systemFont(ofSize: markerSize, weight: .bold)
        return VStack(spacing: densityValue(one: 15, two: 6, three: 6, four: 4, five: 3)) {
            Text(eyebrow)
                .font(roundFont(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14).frame(height: 22)
                .background(rgb(242, 94, 137)).clipShape(Capsule())
                .layoutAnchor(.eyebrow)
            VStack(spacing: densityValue(one: 4, two: 3, three: 6, four: 4, five: 3)) {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("♥").font(.system(size: markerSize, weight: .bold)).foregroundStyle(rgb(242, 94, 137))
                            .baselineOffset(glyphCapCenterOffset(markerFont: markerUIFont, goalFont: goalUIFont))
                            .offset(
                                y: (goalCount == 4 ? -0.5 : 0)
                                    + scaledGoalCapCenterOffset(
                                    title: title,
                                    font: goalUIFont,
                                    availableWidth: 321
                                )
                            )
                            .layoutAnchor(.goalMarker(index))
                        goalText(title, font: roundFont(size: goalSize, weight: .bold), color: rgb(68, 43, 49))
                            .layoutAnchor(.goal(index))
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: densityValue(one: 44, two: 32, three: 25, four: 19, five: 16), alignment: .leading)
                    .background(rgb(255, 240, 244))
                    .overlay { Capsule().stroke(rgb(242, 94, 137).opacity(0.25), lineWidth: 1.5) }
                    .clipShape(Capsule())
                }
            }
            HStack(spacing: 8) {
                blockOrCancelledText
                    .font(roundFont(size: adaptiveSummarySize(11), weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.bottom, 3).frame(height: 25)
                    .background { SpeechBubbleShape().fill(rgb(242, 94, 137)) }
                    .layoutAnchor(.cancelledSummary)
                Text(attempted)
                    .font(roundFont(size: adaptiveSummarySize(10.5), weight: .bold)).foregroundStyle(rgb(139, 91, 102))
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .layoutAnchor(.attemptedSummary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .layoutAnchor(.contentBounds)
        .padding(.vertical, 6).padding(.horizontal, Self.cardInset)
        .frame(height: Self.maximumHeight)
        .background { ZStack { rgb(255, 253, 253); DotPattern().fill(rgb(242, 94, 137).opacity(0.16)) } }
    }

    private var note: some View {
        let font = LockThemeFontPolicy.bundledFont(for: .note, locale: locale) ?? .zenKurenaido
        let goalSize = max(adaptiveGoalSize(15.5), 15)
        let goalUIFont = uiFont(font, size: goalSize, fallbackWeight: .semibold)
        let markerSize = 12 * goalSize / 15
        return ZStack(alignment: .leading) {
            rgb(251, 247, 239)
            RepeatingLines(spacing: 28).stroke(rgb(108, 130, 153).opacity(0.16), lineWidth: 1)
            Rectangle().fill(rgb(199, 80, 80).opacity(0.4)).frame(width: 1).padding(.leading, 34)
            VStack(alignment: .leading, spacing: densityValue(one: 10, two: 7, three: 6, four: 4.5, five: 3)) {
                Text(eyebrow)
                    .font(customFont(font, size: 11, fallbackWeight: .semibold))
                    .foregroundStyle(rgb(59, 52, 40))
                    .overlay(alignment: .bottom) { WavyLine().stroke(rgb(199, 80, 80), lineWidth: 1).frame(height: 3).offset(y: 3) }
                    .layoutAnchor(.eyebrow)
                VStack(spacing: densityValue(one: 4, two: 3, three: 6, four: 4.5, five: 3)) {
                    ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                        HStack(alignment: .firstTextBaseline, spacing: 9) {
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(rgb(90, 81, 66), lineWidth: 1.6)
                                .frame(width: markerSize, height: markerSize)
                                .rotationEffect(.degrees([-1.5, 1.2, -0.8][index % 3]))
                                .offset(
                                    y: scaledGoalCapCenterOffset(
                                        title: title,
                                        font: goalUIFont,
                                        availableWidth: 308,
                                        unscaledOffset: goalCount >= 3
                                            ? (goalCount == 4 && index == 0 ? 0 : 0.5)
                                            : 0
                                    )
                                )
                                .layoutAnchor(.goalMarker(index))
                                .markerCenterAlignedToCapHeight(of: goalUIFont)
                            goalText(title, font: customFont(font, size: goalSize, fallbackWeight: .semibold), color: rgb(59, 52, 40))
                                .layoutAnchor(.goal(index))
                        }.frame(height: densityValue(one: 65, two: 34, three: 24, four: 20, five: 19))
                    }
                }
                HStack(spacing: 12) {
                    blockOrCancelledText
                        .font(customFont(font, size: adaptiveSummarySize(11.5), fallbackWeight: .regular))
                        .foregroundStyle(rgb(199, 80, 80))
                        .layoutAnchor(.cancelledSummary)
                    Spacer(minLength: 3)
                    noteAttemptedText()
                        .foregroundStyle(rgb(138, 128, 112))
                        .layoutAnchor(.attemptedSummary)
                }
                .lineLimit(1).minimumScaleFactor(0.62)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutAnchor(.contentBounds)
            .padding(.vertical, 8).padding(.leading, 46).padding(.trailing, Self.cardInset)
        }
        .frame(height: Self.maximumHeight)
        .overlay(alignment: .top) {
            Rectangle().fill(rgb(232, 214, 160).opacity(0.78)).frame(width: 76, height: 17).rotationEffect(.degrees(-2)).offset(y: 1)
        }
    }

    private var blueprint: some View {
        let goalSize = adaptiveGoalSize(14.5)
        let goalUIFont = UIFont.systemFont(ofSize: goalSize, weight: .bold)
        let markerScale = goalSize / 15
        return ZStack {
            rgb(22, 65, 138)
            GridPattern(spacing: 22).stroke(.white.opacity(0.08), lineWidth: 1)
            VStack(alignment: .leading, spacing: densityValue(one: 13, two: 10, three: 6, four: 4.5, five: 3)) {
                eyebrowText(color: .white.opacity(0.85), tracking: 3)
                VStack(spacing: densityValue(one: 4, two: 3, three: 6, four: 4.5, five: 3)) {
                    ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            HStack(spacing: 0) {
                                Circle().stroke(.white, lineWidth: 1.5).frame(width: 8 * markerScale, height: 8 * markerScale)
                                Rectangle().fill(.white).frame(width: 18 * markerScale, height: max(1, markerScale))
                            }
                            .offset(
                                y: scaledGoalCapCenterOffset(
                                    title: title,
                                    font: goalUIFont,
                                    availableWidth: 326
                                )
                            )
                            .layoutAnchor(.goalMarker(index))
                            .markerCenterAlignedToCapHeight(of: goalUIFont)
                            goalText(title, size: goalSize, weight: .bold, color: .white).tracking(0.45).padding(.leading, 7)
                                .layoutAnchor(.goal(index))
                        }.frame(height: densityValue(one: 63, two: 33, three: 24, four: 20, five: 17))
                    }
                }
                HStack(spacing: 0) {
                    blockOrCancelledText
                        .frame(maxWidth: .infinity)
                        .layoutAnchor(.blueprintCancelledText)
                        .layoutAnchor(.cancelledSummary)
                        .padding(.horizontal, 6)
                        .frame(width: 174)
                        .layoutAnchor(.blueprintCancelledCell)
                    Divider().overlay(.white)
                    Text(attempted)
                        .frame(maxWidth: .infinity)
                        .layoutAnchor(.blueprintAttemptedText)
                        .layoutAnchor(.attemptedSummary)
                        .padding(.horizontal, 6)
                        .layoutAnchor(.blueprintAttemptedCell)
                }
                .font(.system(size: adaptiveSummarySize(9.5), weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.55)
                .frame(height: 25)
                .overlay { Rectangle().stroke(.white, lineWidth: 1) }
                .frame(maxWidth: 285, alignment: .trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutAnchor(.contentBounds)
            .padding(.vertical, 8).padding(.horizontal, Self.cardInset)
        }
        .frame(height: Self.maximumHeight)
        .overlay { surfaceBorder(Color.white, lineWidth: 1.5) }
        .overlay { RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5, 4])).padding(7) }
        .clipShape(surfaceClipShape)
    }

    private func eyebrowText(color: Color, tracking: CGFloat) -> some View {
        Text(eyebrow).font(.system(size: 10, weight: .bold)).tracking(tracking).foregroundStyle(color).lineLimit(1)
            .layoutAnchor(.eyebrow)
    }

    private func asagiriCancelledText() -> Text {
        let summarySize = adaptiveSummarySize(11)
        if !blockWindows.isEmpty { return blockOrCancelledText.font(.system(size: summarySize)).foregroundColor(rgb(91, 105, 119)) }
        let count = String(cancelledCount)
        guard let range = cancelled.range(of: count) else {
            return blockOrCancelledText
                .font(.system(size: summarySize, weight: .regular))
                .foregroundColor(rgb(91, 105, 119))
        }
        let leading = String(cancelled[..<range.lowerBound])
        let trailing = String(cancelled[range.upperBound...])
        return Text(leading)
            .font(.system(size: summarySize, weight: .regular))
            .foregroundColor(rgb(91, 105, 119))
            + Text(count)
                .font(.system(size: 17 + summaryFontIncrease, weight: .medium))
                .foregroundColor(rgb(91, 126, 153))
            + Text(trailing)
                .font(.system(size: summarySize, weight: .regular))
                .foregroundColor(rgb(91, 105, 119))
    }

    private func goalText(_ title: String, size: CGFloat, weight: Font.Weight, color: Color) -> some View {
        goalText(title, font: .system(size: size, weight: weight), color: color)
    }

    private func goalText(_ title: String, font: Font, color: Color) -> some View {
        Text(title)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(goalMinimumScaleFactor)
            .truncationMode(.tail)
            .allowsTightening(true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(title)
    }

    private func centeredGoalText(
        _ title: String,
        size: CGFloat,
        weight: Font.Weight,
        color: Color
    ) -> some View {
        Text(title)
            .font(.system(size: size, weight: weight))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(goalMinimumScaleFactor)
            .truncationMode(.tail)
            .allowsTightening(true)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityLabel(title)
    }

    private func summaryRow(primary: Color, secondary: Color, size: CGFloat) -> some View {
        HStack(spacing: 10) {
            blockOrCancelledText.foregroundStyle(primary).layoutAnchor(.cancelledSummary)
            Spacer(minLength: 3)
            Text(attempted).foregroundStyle(secondary).layoutAnchor(.attemptedSummary)
        }
        .font(.system(size: size, weight: .semibold))
        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.62)
    }

    private func glassCapsule(_ text: Text, translucent: Bool = false) -> some View {
        text
            .font(.system(size: adaptiveSummarySize(11.5), weight: .bold))
            .foregroundStyle(translucent ? Color.white : Color.primary)
            .shadow(color: .black.opacity(translucent ? 0.55 : 0), radius: 1, y: 1)
            .lineLimit(1).minimumScaleFactor(0.58)
            .padding(.horizontal, 9).frame(minHeight: 24)
            .background(translucent ? Color.black.opacity(0.18) : Color.primary.opacity(0.08)).overlay { Capsule().strokeBorder(translucent ? Color.white.opacity(0.28) : Color.primary.opacity(0.18), lineWidth: 1) }.clipShape(Capsule())
    }

    private func noteAttemptedText() -> Text {
        let bundledFont = LockThemeFontPolicy.bundledFont(for: .note, locale: locale) ?? .zenKurenaido
        let handwriting = customFont(bundledFont, size: adaptiveSummarySize(11.5), fallbackWeight: .regular)
        if locale.language.languageCode?.identifier == "ko" {
            return Text(attempted).font(handwriting)
        }
        guard let multiplicationSign = attempted.range(of: "×") else {
            return Text(attempted).font(handwriting)
        }
        let leading = String(attempted[..<multiplicationSign.lowerBound])
        let trailing = String(attempted[multiplicationSign.upperBound...])
        return Text(leading).font(handwriting)
            + Text("×")
                .font(.system(size: adaptiveSummarySize(9.5), weight: .medium, design: .rounded))
                .baselineOffset(0.4)
            + Text(trailing).font(handwriting)
    }

    private func customFont(_ font: DopaBreakBundledFont, size: CGFloat, fallbackWeight: Font.Weight) -> Font {
        guard let name = DopaBreakFontRegistrar.registeredName(for: font) else {
            return .system(size: size, weight: fallbackWeight)
        }
        return .custom(name, fixedSize: size).weight(fallbackWeight)
    }

    private func uiFont(
        _ font: DopaBreakBundledFont,
        size: CGFloat,
        fallbackWeight: UIFont.Weight
    ) -> UIFont {
        guard let name = DopaBreakFontRegistrar.registeredName(for: font),
              let registeredFont = UIFont(name: name, size: size) else {
            return .systemFont(ofSize: size, weight: fallbackWeight)
        }
        return registeredFont
    }

    private func roundFont(size: CGFloat, weight: Font.Weight) -> Font {
        .custom("HiraMaruProN-W4", fixedSize: size).weight(weight)
    }

    private func roundUIFont(size: CGFloat) -> UIFont {
        UIFont(name: "HiraMaruProN-W4", size: size) ?? .systemFont(ofSize: size, weight: .bold)
    }

    private func glyphCapCenterOffset(markerFont: UIFont, goalFont: UIFont) -> CGFloat {
        (goalFont.capHeight - markerFont.capHeight) / 2
    }

    private func scaledGoalCapCenterOffset(
        title: String,
        font: UIFont,
        availableWidth: CGFloat,
        unscaledOffset: CGFloat = 0
    ) -> CGFloat {
        let naturalWidth = (title as NSString).size(withAttributes: [.font: font]).width
        guard naturalWidth > availableWidth else { return unscaledOffset }
        let effectiveScale = max(goalMinimumScaleFactor, min(1, availableWidth / naturalWidth))
        return font.capHeight * (1 - effectiveScale) / 2
    }

    private func goalTextRequiresScaling(
        title: String,
        font: UIFont,
        availableWidth: CGFloat
    ) -> Bool {
        (title as NSString).size(withAttributes: [.font: font]).width > availableWidth
    }

    private func adaptiveGoalSize(_ base: CGFloat) -> CGFloat {
        base + goalFontIncrease
    }

    private var goalMinimumScaleFactor: CGFloat {
        if theme == .note {
            return 1
        }
        if goalCount == 3 {
            return 0.85
        }
        return goalCount >= 4 ? 0.55 : 0.5
    }

    private func adaptiveSummarySize(_ base: CGFloat) -> CGFloat {
        base + summaryFontIncrease
    }

    private func densityValue<T>(one: T, two: T, three: T, four: T, five: T) -> T {
        switch goalCount {
        case 1: one
        case 2: two
        case 3: three
        case 4: four
        default: five
        }
    }

    private func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(red: red / 255, green: green / 255, blue: blue / 255)
    }

    private func localizedFormat(key: String, defaultValue: String, count: Int) -> String {
        let format = localizationBundle.localizedString(forKey: key, value: defaultValue, table: nil)
        return String(format: format, locale: locale, Int64(count))
    }

    private func publishLayout(
        _ anchors: [LockThemeLayoutElement: Anchor<CGRect>],
        in proxy: GeometryProxy
    ) {
        guard let layoutObserver else { return }
        layoutObserver(anchors.mapValues { proxy[$0] })
    }
}

private struct LockThemeLayoutAnchorKey: PreferenceKey {
    static let defaultValue: [LockThemeLayoutElement: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [LockThemeLayoutElement: Anchor<CGRect>],
        nextValue: () -> [LockThemeLayoutElement: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private extension View {
    func layoutAnchor(_ element: LockThemeLayoutElement) -> some View {
        transformAnchorPreference(key: LockThemeLayoutAnchorKey.self, value: .bounds) { value, anchor in
            value[element] = anchor
        }
    }

    func markerCenterAlignedToCapHeight(of font: UIFont) -> some View {
        alignmentGuide(.firstTextBaseline) { dimensions in
            dimensions.height / 2 + font.capHeight / 2
        }
    }
}

private struct RepeatingLines: Shape {
    let spacing: CGFloat
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for y in stride(from: rect.minY, through: rect.maxY, by: spacing) { path.move(to: CGPoint(x: rect.minX, y: y)); path.addLine(to: CGPoint(x: rect.maxX, y: y)) }
        return path
    }
}

private struct GridPattern: Shape {
    let spacing: CGFloat
    func path(in rect: CGRect) -> Path {
        var path = RepeatingLines(spacing: spacing).path(in: rect)
        for x in stride(from: rect.minX, through: rect.maxX, by: spacing) { path.move(to: CGPoint(x: x, y: rect.minY)); path.addLine(to: CGPoint(x: x, y: rect.maxY)) }
        return path
    }
}

private struct RepeatingDashes: Shape {
    func path(in rect: CGRect) -> Path { var path = Path(); path.move(to: CGPoint(x: rect.minX, y: rect.midY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)); return path }
}

private struct WavyLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(); path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        var x = rect.minX
        while x < rect.maxX { path.addCurve(to: CGPoint(x: min(x + 8, rect.maxX), y: rect.midY), control1: CGPoint(x: x + 2, y: rect.minY), control2: CGPoint(x: x + 6, y: rect.maxY)); x += 8 }
        return path
    }
}

private struct DotPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points: [CGPoint] = [.init(x: 0.08, y: 0.12), .init(x: 0.24, y: 0.24), .init(x: 0.76, y: 0.15), .init(x: 0.9, y: 0.36), .init(x: 0.14, y: 0.76), .init(x: 0.82, y: 0.82)]
        for point in points { path.addEllipse(in: CGRect(x: rect.width * point.x, y: rect.height * point.y, width: 3, height: 3)) }
        return path
    }
}

private struct TicketStubShape: Shape {
    let notchRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: rect, cornerRadius: 7)
        path.addEllipse(
            in: CGRect(
                x: rect.minX - notchRadius,
                y: rect.midY - notchRadius,
                width: notchRadius * 2,
                height: notchRadius * 2
            )
        )
        path.addEllipse(
            in: CGRect(
                x: rect.maxX - notchRadius,
                y: rect.midY - notchRadius,
                width: notchRadius * 2,
                height: notchRadius * 2
            )
        )
        return path
    }
}

private struct SpeechBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let tailHeight: CGFloat = 4
        let bubble = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tailHeight)
        var path = Path(roundedRect: bubble, cornerRadius: 14)
        path.move(to: CGPoint(x: bubble.minX + 18, y: bubble.maxY - 1))
        path.addLine(to: CGPoint(x: bubble.minX + 25, y: rect.maxY))
        path.addLine(to: CGPoint(x: bubble.minX + 31, y: bubble.maxY - 1))
        path.closeSubpath()
        return path
    }
}


/// Illustrative wallpaper for in-app previews; never rendered by the Live Activity.
struct LockThemeGlassPreviewBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.26, green: 0.46, blue: 0.54),
                     Color(red: 0.58, green: 0.48, blue: 0.31),
                     Color(red: 0.3, green: 0.35, blue: 0.49)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

/// System-hosted Live Activities already own their outer mask and rim.
/// Only app previews need us to supply an explicit continuous rounded shape.
private struct LockThemeOuterSurface: ViewModifier {
    let surfaceShape: LockThemeSurfaceShape
    let enabled: Bool
    let showsPreviewRim: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled, case .fixed(let radius) = surfaceShape {
            content
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay {
                    if showsPreviewRim {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                    }
                }
        } else {
            content
        }
    }
}

/// Generic eight-legged spider, drawn independently of any character emblem.
struct LockThemeSpiderMarker: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var result = Path()
        result.addEllipse(in: CGRect(x: rect.minX + rect.width * 0.36, y: rect.minY + rect.height * 0.38, width: rect.width * 0.28, height: rect.height * 0.36))
        result.addEllipse(in: CGRect(x: rect.minX + rect.width * 0.4, y: rect.minY + rect.height * 0.24, width: rect.width * 0.2, height: rect.height * 0.2))
        var legs = Path()
        let bends: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.37, 0.29, 0.25, 0.25, 0.08),
            (0.43, 0.18, 0.35, 0.09, 0.24),
            (0.51, 0.17, 0.56, 0.07, 0.7),
            (0.6, 0.28, 0.72, 0.2, 0.92)
        ]
        for (bodyY, bendX, bendY, endX, endY) in bends {
            for mirror in [false, true] {
                func x(_ value: CGFloat) -> CGFloat { mirror ? 1 - value : value }
                legs.move(to: point(x(0.42), bodyY))
                legs.addQuadCurve(to: point(x(bendX), bendY), control: point(x(0.28), bodyY))
                legs.addLine(to: point(x(endX), endY))
            }
        }
        result.addPath(legs.strokedPath(StrokeStyle(lineWidth: rect.width * 0.085, lineCap: .round, lineJoin: .round)))
        return result
    }
}

private struct LockThemeWebPattern: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.width * 0.97, y: rect.height * 0.27)
        let reach = hypot(rect.width, rect.height) * 1.25
        let angles = (0...15).map { CGFloat.pi * (0.38 + CGFloat($0) * 0.084) }
        func point(radius: CGFloat, angle: CGFloat) -> CGPoint {
            CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
        var path = Path()
        for angle in angles {
            path.move(to: center)
            path.addLine(to: point(radius: reach, angle: angle))
        }
        for radius in stride(from: CGFloat(18), through: reach, by: 27) {
            for index in 0..<(angles.count - 1) {
                let a = angles[index]
                let b = angles[index + 1]
                path.move(to: point(radius: radius, angle: a))
                path.addQuadCurve(to: point(radius: radius, angle: b), control: point(radius: radius * 0.88, angle: (a + b) / 2))
            }
        }
        return path
    }
}
