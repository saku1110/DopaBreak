import DopaBreakCore
import SwiftUI

enum LockThemeLayoutElement: Hashable {
    case contentBounds
    case cardBounds
    case eyebrow
    case goal(Int)
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

/// The canonical lock-screen card used by both the Widget Extension and the in-app preview.
/// A full-height 160pt canvas and shrinking goal rows keep every theme within WidgetKit's limit.
struct LockThemeLiveActivityView: View {
    static let maximumHeight: CGFloat = 160
    static let maximumGoals = 3
    static let cardInset: CGFloat = 16

    let theme: LockTheme
    let goalTitles: [String]
    let cancelledCount: Int
    let attemptCount: Int
    var isMeasuring = false
    var localizationBundle: Bundle = .main
    var locale: Locale = .autoupdatingCurrent
    var layoutObserver: (([LockThemeLayoutElement: CGRect]) -> Void)? = nil

    private var titles: [String] { Array(goalTitles.prefix(Self.maximumGoals)) }
    private var usesDenseE1Layout: Bool { titles.count == Self.maximumGoals }
    private var eyebrow: String {
        localizationBundle.localizedString(
            forKey: "live_activity.goal.eyebrow",
            value: "あなたの目標",
            table: nil
        )
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
            case .retroPop: retroPop
            }
        }
    }

    private var blackLime: some View {
        VStack(alignment: .leading, spacing: usesDenseE1Layout ? 6 : 10) {
            eyebrowText(color: rgb(139, 146, 158), tracking: 1.5)
                .textCase(.uppercase)
            VStack(alignment: .leading, spacing: usesDenseE1Layout ? 3 : 5) {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Rectangle().fill(rgb(184, 255, 61)).frame(width: 10, height: 2)
                        Text(title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(rgb(244, 242, 236))
                            .lineLimit(2)
                            .lineSpacing(1)
                            .minimumScaleFactor(0.6)
                            .allowsTightening(true)
                            .accessibilityLabel(title)
                            .layoutAnchor(.goal(index))
                    }
                    .frame(height: usesDenseE1Layout ? 25 : nil)
                    .layoutAnchor(.e1Goal(index))
                }
            }
            Rectangle().fill(rgb(139, 146, 158).opacity(0.25)).frame(height: 1)
                .layoutAnchor(.e1Divider)
            HStack(spacing: 14) {
                Text(cancelled).foregroundStyle(rgb(184, 255, 61)).layoutAnchor(.cancelledSummary)
                Text(attempted).foregroundStyle(rgb(139, 146, 158)).layoutAnchor(.attemptedSummary)
            }
            .font(.system(size: 12, weight: .semibold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.62)
            .layoutAnchor(.e1Summary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .layoutAnchor(.contentBounds)
        .padding(.horizontal, Self.cardInset)
        .padding(.vertical, usesDenseE1Layout ? 10 : Self.cardInset)
        .frame(minHeight: Self.maximumHeight)
        .background(rgb(20, 23, 27))
        .overlay(alignment: .leading) { Rectangle().fill(rgb(184, 255, 61)).frame(width: 3) }
    }

    private var gaming: some View {
        let font = LockThemeFontPolicy.bundledFont(for: .gaming, locale: locale) ?? .dotGothic16
        return ZStack {
            rgb(10, 10, 20)
            RepeatingLines(spacing: 4).stroke(.white.opacity(0.035), lineWidth: 1)
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow)
                    .font(customFont(font, size: 11, fallbackWeight: .regular))
                    .tracking(1.2)
                    .foregroundStyle(rgb(0, 229, 255))
                    .shadow(color: rgb(0, 229, 255).opacity(0.65), radius: 3)
                    .layoutAnchor(.eyebrow)
                VStack(spacing: 2) {
                    ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                        HStack(spacing: 8) {
                            Rectangle()
                                .stroke(rgb(0, 229, 255), lineWidth: 1.5)
                                .frame(width: 12, height: 12)
                                .shadow(color: rgb(0, 229, 255).opacity(0.8), radius: 2)
                            goalText(
                                title,
                                font: customFont(font, size: 15.5, fallbackWeight: .regular),
                                color: rgb(234, 234, 242)
                            )
                            .layoutAnchor(.goal(index))
                        }
                        .frame(height: 21)
                    }
                }
                RepeatingDashes().stroke(rgb(0, 229, 255).opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [5, 5])).frame(height: 1)
                HStack(spacing: 12) {
                    Text(cancelled).foregroundStyle(rgb(0, 229, 255)).layoutAnchor(.cancelledSummary)
                    Spacer(minLength: 4)
                    Text(attempted).foregroundStyle(rgb(138, 143, 168)).layoutAnchor(.attemptedSummary)
                }
                .font(customFont(font, size: 10.5, fallbackWeight: .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutAnchor(.contentBounds)
            .padding(.horizontal, Self.cardInset)
        }
        .frame(minHeight: Self.maximumHeight)
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [rgb(0, 229, 255), rgb(124, 77, 255), rgb(255, 46, 138)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2
                )
                .shadow(color: rgb(124, 77, 255).opacity(0.55), radius: 5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private var asagiri: some View {
        VStack(spacing: 5) {
            eyebrowText(color: rgb(91, 105, 119), tracking: 3.2)
            VStack(spacing: 2) {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    centeredGoalText(title, size: 15, weight: .light, color: rgb(31, 37, 47))
                        .tracking(0.45)
                        .frame(height: 20)
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
                .font(.system(size: 10.5, weight: .regular))
                .foregroundStyle(rgb(91, 105, 119))
                .lineLimit(1)
                .layoutAnchor(.attemptedSummary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .layoutAnchor(.contentBounds)
        .padding(.vertical, 9)
        .padding(.horizontal, Self.cardInset)
        .frame(minHeight: Self.maximumHeight)
        .background {
            ZStack {
                rgb(237, 241, 245)
                VStack { LinearGradient(colors: [.white.opacity(0.9), .clear], startPoint: .top, endPoint: .bottom).frame(height: 44); Spacer() }
                LinearGradient(colors: [.clear, .white.opacity(0.82), .clear], startPoint: .top, endPoint: .bottom)
            }
        }
    }

    private var monochrome: some View {
        VStack(alignment: .leading, spacing: 4) {
            eyebrowText(color: rgb(118, 118, 118), tracking: 1.8)
            VStack(spacing: 0) {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    goalText(title, size: 19, weight: .black, color: rgb(18, 18, 18))
                        .frame(height: 26)
                        .layoutAnchor(.goal(index))
                    if index < titles.count - 1 {
                        Rectangle().fill(rgb(230, 230, 230)).frame(height: 1)
                    }
                }
            }
            Rectangle().fill(rgb(18, 18, 18)).frame(height: 2)
            summaryRow(primary: rgb(18, 18, 18), secondary: rgb(118, 118, 118), size: 10.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .layoutAnchor(.contentBounds)
        .padding(.vertical, 9)
        .padding(.horizontal, Self.cardInset)
        .frame(minHeight: Self.maximumHeight)
        .background(rgb(250, 250, 250))
    }

    @ViewBuilder
    private var liquidGlass: some View {
        let content = VStack(alignment: .leading, spacing: 5) {
            eyebrowText(color: .white.opacity(0.8), tracking: 2)
            VStack(spacing: 0) {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    goalText(title, size: 15, weight: .bold, color: .white)
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                        .frame(height: 23)
                        .layoutAnchor(.goal(index))
                    if index < titles.count - 1 {
                        Rectangle().fill(.white.opacity(0.26)).frame(height: 1)
                    }
                }
            }
            HStack(spacing: 7) {
                glassCapsule(cancelled).layoutAnchor(.cancelledSummary)
                glassCapsule(attempted).layoutAnchor(.attemptedSummary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .layoutAnchor(.contentBounds)
        .padding(.vertical, 10)
        .padding(.horizontal, Self.cardInset)
        .frame(minHeight: Self.maximumHeight)
        .overlay(alignment: .top) {
            LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.12), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(height: 1.5)
                .padding(.horizontal, 10)
        }

        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.42), lineWidth: 1) }
        }
    }

    private var kpop: some View {
        VStack(spacing: 5) {
            Text(eyebrow)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 15).frame(height: 22)
                .background(rgb(238, 52, 137)).clipShape(Capsule())
                .layoutAnchor(.eyebrow)
            VStack(spacing: 3) {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    HStack(spacing: 7) {
                        Rectangle().fill(rgb(238, 52, 137)).frame(width: 5)
                        Text("★").font(.system(size: 9, weight: .bold)).foregroundStyle(rgb(238, 52, 137))
                        goalText(title, size: 15, weight: .black, color: rgb(35, 31, 38))
                            .layoutAnchor(.goal(index))
                    }
                    .padding(.trailing, 8)
                    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                    .background {
                        TicketStubShape(notchRadius: 4)
                            .fill(.white, style: FillStyle(eoFill: true))
                            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                    }
                }
            }
            HStack(spacing: 8) {
                Text(cancelled).layoutAnchor(.cancelledSummary)
                Text("★").foregroundStyle(rgb(238, 52, 137))
                Text(attempted).layoutAnchor(.attemptedSummary)
            }
            .font(.system(size: 9.5, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(.white)
            .lineLimit(1).minimumScaleFactor(0.65)
            .frame(maxWidth: .infinity, minHeight: 21)
            .background(rgb(35, 31, 38))
            .padding(.horizontal, -Self.cardInset)
        }
        .padding(.top, 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .layoutAnchor(.contentBounds)
        .padding(.horizontal, Self.cardInset)
        .frame(minHeight: Self.maximumHeight)
        .background {
            ZStack {
                rgb(249, 246, 251)
                LinearGradient(colors: [.clear, rgb(53, 195, 232).opacity(0.12), rgb(238, 52, 137).opacity(0.12)], startPoint: .bottomLeading, endPoint: .topTrailing)
            }
        }
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(LinearGradient(colors: [rgb(238, 52, 137), rgb(138, 77, 232), rgb(53, 195, 232)], startPoint: .leading, endPoint: .trailing), lineWidth: 2.5) }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var kawaiiPink: some View {
        VStack(spacing: 5) {
            Text(eyebrow)
                .font(roundFont(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14).frame(height: 22)
                .background(rgb(242, 94, 137)).clipShape(Capsule())
                .layoutAnchor(.eyebrow)
            VStack(spacing: 3) {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    HStack(spacing: 7) {
                        Text("♥").font(.system(size: 10, weight: .bold)).foregroundStyle(rgb(242, 94, 137))
                        goalText(title, font: roundFont(size: 13, weight: .bold), color: rgb(68, 43, 49))
                            .layoutAnchor(.goal(index))
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                    .background(rgb(255, 240, 244))
                    .overlay { Capsule().stroke(rgb(242, 94, 137).opacity(0.25), lineWidth: 1.5) }
                    .clipShape(Capsule())
                }
            }
            HStack(spacing: 8) {
                Text(cancelled)
                    .font(roundFont(size: 11, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.bottom, 3).frame(height: 25)
                    .background { SpeechBubbleShape().fill(rgb(242, 94, 137)) }
                    .layoutAnchor(.cancelledSummary)
                Text(attempted)
                    .font(roundFont(size: 10.5, weight: .bold)).foregroundStyle(rgb(139, 91, 102))
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .layoutAnchor(.attemptedSummary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .layoutAnchor(.contentBounds)
        .padding(.vertical, 5).padding(.horizontal, Self.cardInset)
        .frame(minHeight: Self.maximumHeight)
        .background { ZStack { rgb(255, 253, 253); DotPattern().fill(rgb(242, 94, 137).opacity(0.16)) } }
    }

    private var note: some View {
        let font = LockThemeFontPolicy.bundledFont(for: .note, locale: locale) ?? .zenKurenaido
        return ZStack(alignment: .leading) {
            rgb(251, 247, 239)
            RepeatingLines(spacing: 28).stroke(rgb(108, 130, 153).opacity(0.16), lineWidth: 1)
            Rectangle().fill(rgb(199, 80, 80).opacity(0.4)).frame(width: 1).padding(.leading, 34)
            VStack(alignment: .leading, spacing: 5) {
                Text(eyebrow)
                    .font(customFont(font, size: 11, fallbackWeight: .semibold))
                    .foregroundStyle(rgb(59, 52, 40))
                    .overlay(alignment: .bottom) { WavyLine().stroke(rgb(199, 80, 80), lineWidth: 1).frame(height: 3).offset(y: 3) }
                    .layoutAnchor(.eyebrow)
                VStack(spacing: 2) {
                    ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                        HStack(spacing: 9) {
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(rgb(90, 81, 66), lineWidth: 1.6)
                                .frame(width: 12, height: 12)
                                .rotationEffect(.degrees([-1.5, 1.2, -0.8][index % 3]))
                            goalText(title, font: customFont(font, size: 15.5, fallbackWeight: .semibold), color: rgb(59, 52, 40))
                                .layoutAnchor(.goal(index))
                        }.frame(height: 22)
                    }
                }
                HStack(spacing: 12) {
                    Text(cancelled)
                        .font(customFont(font, size: 11.5, fallbackWeight: .regular))
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
            .padding(.vertical, 11).padding(.leading, 46).padding(.trailing, Self.cardInset)
        }
        .frame(minHeight: Self.maximumHeight)
        .overlay(alignment: .top) {
            Rectangle().fill(rgb(232, 214, 160).opacity(0.78)).frame(width: 76, height: 17).rotationEffect(.degrees(-2)).offset(y: 1)
        }
    }

    private var blueprint: some View {
        ZStack {
            rgb(22, 65, 138)
            GridPattern(spacing: 22).stroke(.white.opacity(0.08), lineWidth: 1)
            VStack(alignment: .leading, spacing: 4) {
                eyebrowText(color: .white.opacity(0.85), tracking: 3)
                VStack(spacing: 1) {
                    ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                        HStack(spacing: 0) {
                            Circle().stroke(.white, lineWidth: 1.5).frame(width: 8, height: 8)
                            Rectangle().fill(.white).frame(width: 18, height: 1)
                            goalText(title, size: 14.5, weight: .bold, color: .white).tracking(0.45).padding(.leading, 7)
                                .layoutAnchor(.goal(index))
                        }.frame(height: 22)
                    }
                }
                HStack(spacing: 0) {
                    Text(cancelled)
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
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.55)
                .frame(height: 22)
                .overlay { Rectangle().stroke(.white, lineWidth: 1) }
                .frame(maxWidth: 285, alignment: .trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutAnchor(.contentBounds)
            .padding(.vertical, 12).padding(.horizontal, Self.cardInset)
        }
        .frame(minHeight: Self.maximumHeight)
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(.white, lineWidth: 1.5).padding(1) }
        .overlay { RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5, 4])).padding(7) }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var retroPop: some View {
        ZStack(alignment: .topTrailing) {
            rgb(245, 233, 214)
            RetroRings().frame(width: 115, height: 90).offset(x: 20, y: -20)
            VStack(alignment: .leading, spacing: 5) {
            Text(eyebrow)
                    .font(roundFont(size: 10, weight: .bold)).foregroundStyle(rgb(74, 51, 32))
                .padding(.horizontal, 13).frame(height: 22)
                .background(rgb(232, 163, 61)).clipShape(Capsule())
                .layoutAnchor(.eyebrow)
                VStack(spacing: 1) {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                        HStack(spacing: 7) {
                            Text("✽").font(.system(size: 16, weight: .bold)).foregroundStyle(rgb(232, 99, 43))
                        goalText(title, font: roundFont(size: 15, weight: .bold), color: rgb(74, 51, 32))
                            .layoutAnchor(.goal(index))
                        }.frame(height: 22)
                        if index < titles.count - 1 {
                            RepeatingDashes().stroke(rgb(201, 168, 124), style: StrokeStyle(lineWidth: 1, dash: [2, 4])).frame(height: 1)
                        }
                    }
                }
                HStack(spacing: 8) {
                    Text(cancelled)
                        .font(roundFont(size: 10.5, weight: .bold)).foregroundStyle(rgb(245, 233, 214))
                        .padding(.horizontal, 9).frame(height: 21).background(rgb(232, 99, 43)).clipShape(Capsule())
                        .layoutAnchor(.cancelledSummary)
                    Text(attempted).font(roundFont(size: 10.5, weight: .regular)).foregroundStyle(rgb(107, 74, 50))
                        .layoutAnchor(.attemptedSummary)
                }.lineLimit(1).minimumScaleFactor(0.62)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutAnchor(.contentBounds)
            .padding(.vertical, 9).padding(.horizontal, Self.cardInset)
            VStack(spacing: 0) {
                Spacer()
                rgb(232, 99, 43).frame(height: 3)
                rgb(232, 163, 61).frame(height: 3)
                rgb(107, 74, 50).frame(height: 3)
            }
        }
        .frame(minHeight: Self.maximumHeight)
    }

    private func eyebrowText(color: Color, tracking: CGFloat) -> some View {
        Text(eyebrow).font(.system(size: 10, weight: .bold)).tracking(tracking).foregroundStyle(color).lineLimit(1)
            .layoutAnchor(.eyebrow)
    }

    private func asagiriCancelledText() -> Text {
        let count = String(cancelledCount)
        guard let range = cancelled.range(of: count) else {
            return Text(cancelled)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(rgb(91, 105, 119))
        }
        let leading = String(cancelled[..<range.lowerBound])
        let trailing = String(cancelled[range.upperBound...])
        return Text(leading)
            .font(.system(size: 11, weight: .regular))
            .foregroundColor(rgb(91, 105, 119))
            + Text(count)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(rgb(91, 126, 153))
            + Text(trailing)
                .font(.system(size: 11, weight: .regular))
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
            .minimumScaleFactor(0.5)
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
            .minimumScaleFactor(0.5)
            .allowsTightening(true)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityLabel(title)
    }

    private func summaryRow(primary: Color, secondary: Color, size: CGFloat) -> some View {
        HStack(spacing: 10) {
            Text(cancelled).foregroundStyle(primary).layoutAnchor(.cancelledSummary)
            Spacer(minLength: 3)
            Text(attempted).foregroundStyle(secondary).layoutAnchor(.attemptedSummary)
        }
        .font(.system(size: size, weight: .semibold))
        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.62)
    }

    private func glassCapsule(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(1).minimumScaleFactor(0.58)
            .padding(.horizontal, 9).frame(minHeight: 24)
            .background(.white.opacity(0.2)).overlay { Capsule().stroke(.white.opacity(0.4), lineWidth: 1) }.clipShape(Capsule())
    }

    private func noteAttemptedText() -> Text {
        let bundledFont = LockThemeFontPolicy.bundledFont(for: .note, locale: locale) ?? .zenKurenaido
        let handwriting = customFont(bundledFont, size: 11.5, fallbackWeight: .regular)
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
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .baselineOffset(0.4)
            + Text(trailing).font(handwriting)
    }

    private func customFont(_ font: DopaBreakBundledFont, size: CGFloat, fallbackWeight: Font.Weight) -> Font {
        guard let name = DopaBreakFontRegistrar.registeredName(for: font) else {
            return .system(size: size, weight: fallbackWeight)
        }
        return .custom(name, fixedSize: size).weight(fallbackWeight)
    }

    private func roundFont(size: CGFloat, weight: Font.Weight) -> Font {
        .custom("HiraMaruProN-W4", fixedSize: size).weight(weight)
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

private struct RetroRings: View {
    var body: some View {
        ZStack {
            Circle().stroke(Color(red: 232 / 255, green: 99 / 255, blue: 43 / 255), lineWidth: 18)
            Circle().stroke(Color(red: 232 / 255, green: 163 / 255, blue: 61 / 255), lineWidth: 12).padding(18)
            Circle().stroke(Color(red: 107 / 255, green: 74 / 255, blue: 50 / 255), lineWidth: 7).padding(33)
        }.opacity(0.85)
    }
}
