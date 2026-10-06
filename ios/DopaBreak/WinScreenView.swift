import DopaBreakCore
import SwiftUI

enum WinScreenPresentationPolicy {
    static func displayedGoals(_ goals: [Goal]) -> [Goal] {
        goals
    }

    static func showsConfetti(
        milestone: ReclaimedTimeMilestone?,
        reduceMotion: Bool
    ) -> Bool {
        milestone != nil && !reduceMotion
    }

    static func showsProgress(milestone: ReclaimedTimeMilestone?) -> Bool {
        milestone == nil
    }

    static func streakText(
        days: Int,
        bundle: Bundle = .main,
        locale: Locale = .autoupdatingCurrent
    ) -> String? {
        guard days > 0 else { return nil }
        let format = bundle.localizedString(
            forKey: "intervention.success.streak",
            value: "%lld日連続",
            table: nil
        )
        return String(format: format, locale: locale, arguments: [days])
    }
}

struct WinScreenContent: View {
    let reclaimedSeconds: Int
    let lifetimeReclaimedSeconds: Int
    let todayCancelledCount: Int
    let consecutiveDays: Int
    let estimatedMinutesPerCancellation: Int
    let goals: [Goal]
    let milestone: ReclaimedTimeMilestone?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedReclaimedSeconds = 0

    private var goalFontSize: CGFloat {
        goals.count >= 5 ? 15 : goals.count >= 4 ? 16 : 17
    }

    private var goalSpacing: CGFloat {
        goals.count >= 4 ? 6 : 8
    }

    private var sectionSpacing: CGFloat {
        goals.count >= 5 ? 10 : goals.count >= 4 ? 12 : 18
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if let milestone {
                staticMilestone(milestone)
                sectionGap
            }

            CharacterView(.relief, size: DesignTokens.CharacterSize.support)
                .frame(
                    width: DesignTokens.CharacterSize.support * (96.0 / 86.0),
                    height: DesignTokens.CharacterSize.support
                )
                .background(DesignTokens.card)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(DesignTokens.hairline, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .characterPop(.celebrate)

            sectionGap

            VStack(spacing: 5) {
                Text(incrementText)
                    .dopaFont(48, weight: .black, design: .rounded, tracking: -1.2)
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.accent)
                    .contentTransition(.numericText(value: Double(displayedReclaimedSeconds)))
                    .dopaDisplayClamp()
                    .accessibilityIdentifier("win.reclaimed.increment")

                Text(
                    String(
                        localized: "intervention.success.reclaimed.label",
                        defaultValue: "取り戻した時間"
                    )
                )
                    .dopaFont(18, weight: .bold)
                    .foregroundStyle(DesignTokens.primaryText)
                    .accessibilityIdentifier("win.reclaimed.label")

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        lifetimeText
                        if let equivalent = ReclaimedTimeFormatter.equivalentString(
                            seconds: lifetimeReclaimedSeconds
                        ) {
                            Text(equivalent)
                                .accessibilityIdentifier("win.reclaimed.equivalent")
                        }
                    }
                    VStack(spacing: 2) {
                        lifetimeText
                        if let equivalent = ReclaimedTimeFormatter.equivalentString(
                            seconds: lifetimeReclaimedSeconds
                        ) {
                            Text(equivalent)
                                .accessibilityIdentifier("win.reclaimed.equivalent")
                        }
                    }
                }
                .dopaFont(16, weight: .bold, design: .rounded)
                .monospacedDigit()
                .foregroundStyle(DesignTokens.secondaryText)

                Text(basisText)
                    .dopaFont(12, weight: .semibold)
                    .foregroundStyle(DesignTokens.tertiaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("win.reclaimed.basis")
            }

            sectionGap

            if WinScreenPresentationPolicy.showsProgress(milestone: milestone),
               let progress = ReclaimedTimeMilestoneProgress(seconds: lifetimeReclaimedSeconds) {
                milestoneProgress(progress)
                sectionGap
            }

            HStack(spacing: 14) {
                Text(todayCancelledText)
                    .contentTransition(.numericText(value: Double(todayCancelledCount)))
                    .accessibilityIdentifier("win.cancelled.today")

                if let streak = WinScreenPresentationPolicy.streakText(days: consecutiveDays) {
                    Text(streak)
                        .foregroundStyle(DesignTokens.accent)
                        .accessibilityIdentifier("win.streak")
                }
            }
            .dopaFont(14, weight: .semibold)
            .foregroundStyle(DesignTokens.secondaryText)
            .frame(maxWidth: .infinity, alignment: .center)

            if !goals.isEmpty {
                sectionGap

                CardContainer {
                    VStack(alignment: .leading, spacing: goalSpacing) {
                        Text(
                            String(
                                localized: "intervention.success.goals.title",
                                defaultValue: "この時間の使いみち"
                            )
                        )
                            .dopaFont(14, weight: .bold)
                            .foregroundStyle(DesignTokens.secondaryText)

                        ForEach(
                            Array(WinScreenPresentationPolicy.displayedGoals(goals).enumerated()),
                            id: \.element.id
                        ) { index, goal in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Circle()
                                    .fill(DesignTokens.accent)
                                    .frame(width: 5, height: 5)
                                Text(goal.title)
                                    .dopaFont(goalFontSize, weight: .bold)
                                    .foregroundStyle(DesignTokens.primaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                    .accessibilityIdentifier("win.goal.\(index)")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityIdentifier("win.goals")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay {
            if WinScreenPresentationPolicy.showsConfetti(
                milestone: milestone,
                reduceMotion: reduceMotion
            ) {
                ReclaimedTimeConfettiView()
                    .transition(.opacity)
            }
        }
        .task(id: reclaimedSeconds) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                displayedReclaimedSeconds = reduceMotion ? reclaimedSeconds : 0
            }
            guard !reduceMotion else { return }
            await Task.yield()
            withAnimation(.timingCurve(0.23, 1, 0.32, 1, duration: 0.8)) {
                displayedReclaimedSeconds = reclaimedSeconds
            }
        }
    }

    private var incrementText: String {
        String(
            localized: "intervention.success.reclaimed.increment",
            defaultValue: "＋\(ReclaimedTimeFormatter.detailedString(seconds: displayedReclaimedSeconds))"
        )
    }

    private var lifetimeText: some View {
        Text(
            String(
                localized: "intervention.success.reclaimed.total",
                defaultValue: "累計 \(ReclaimedTimeFormatter.detailedString(seconds: lifetimeReclaimedSeconds))"
            )
        )
            .accessibilityIdentifier("win.reclaimed.total")
    }

    private var basisText: String {
        String(
            localized: "home.hero.basis",
            defaultValue: "開かなかった\(todayCancelledCount)回 × 1回約\(estimatedMinutesPerCancellation)分"
        )
    }

    private var todayCancelledText: String {
        String(
            localized: "intervention.success.daily_cancelled",
            defaultValue: "今日 \(todayCancelledCount)回 開かなかった"
        )
    }

    private var sectionGap: some View {
        Spacer(minLength: sectionSpacing)
    }

    private func milestoneProgress(_ progress: ReclaimedTimeMilestoneProgress) -> some View {
        let percentage = Int((progress.fraction * 100).rounded())
        return VStack(alignment: .leading, spacing: 7) {
            Text(progressLine(progress))
                .dopaFont(13, weight: .semibold)
                .foregroundStyle(DesignTokens.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: 10) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(DesignTokens.hairline)
                        Capsule()
                            .fill(DesignTokens.accent)
                            .frame(width: proxy.size.width * progress.fraction)
                    }
                }
                    .frame(height: 8)
                    .accessibilityLabel(progressTargetText(progress.nextMilestone))
                    .accessibilityValue("\(percentage)%")

                Text("\(percentage)%")
                    .dopaFont(12, weight: .bold, design: .rounded)
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("win.progress")
    }

    private func progressLine(_ progress: ReclaimedTimeMilestoneProgress) -> String {
        let format = Bundle.main.localizedString(
            forKey: "intervention.success.progress.remaining",
            value: "%1$@ あと%2$@",
            table: nil
        )
        return String(
            format: format,
            locale: Locale.autoupdatingCurrent,
            arguments: [
                progressTargetText(progress.nextMilestone),
                ReclaimedTimeFormatter.detailedString(seconds: progress.remainingSeconds)
            ]
        )
    }

    private func progressTargetText(_ milestone: ReclaimedTimeMilestone) -> String {
        if let dayCount = milestone.dayCount {
            let format = Bundle.main.localizedString(
                forKey: "intervention.success.progress.days",
                value: "まる%lld日ぶんまで",
                table: nil
            )
            return String(format: format, locale: Locale.autoupdatingCurrent, arguments: [dayCount])
        }
        let format = Bundle.main.localizedString(
            forKey: "intervention.success.progress.hours",
            value: "%lld時間ぶんまで",
            table: nil
        )
        return String(
            format: format,
            locale: Locale.autoupdatingCurrent,
            arguments: [milestone.hourCount ?? 0]
        )
    }

    private func staticMilestone(_ milestone: ReclaimedTimeMilestone) -> some View {
        Text(milestone.celebrationText())
            .dopaFont(17, weight: .black)
            .foregroundStyle(DesignTokens.accent)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(DesignTokens.card)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DesignTokens.accent.opacity(0.45), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityIdentifier("win.milestone.static")
    }
}

private struct ReclaimedTimeConfettiView: View {
    private static let duration: TimeInterval = 2.4
    private static let frameInterval: TimeInterval = 1.0 / 60.0
    private static let particles = (0..<42).map(ConfettiParticle.init(index:))

    @State private var startedAt = Date()
    @State private var isActive = true

    var body: some View {
        Group {
            if isActive {
                TimelineView(.animation(minimumInterval: Self.frameInterval)) { timeline in
                    Canvas { context, size in
                        let elapsed = timeline.date.timeIntervalSince(startedAt)
                        for particle in Self.particles {
                            particle.draw(in: &context, size: size, elapsed: elapsed)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            startedAt = Date()
            isActive = true
            try? await Task.sleep(for: .milliseconds(2_400))
            withAnimation(.easeOut(duration: 0.15)) {
                isActive = false
            }
        }
    }

    private struct ConfettiParticle {
        let horizontalOrigin: CGFloat
        let delay: TimeInterval
        let drift: CGFloat
        let fallDistance: CGFloat
        let rotation: CGFloat
        let size: CGSize
        let color: Color

        init(index: Int) {
            let unit = CGFloat((index * 37) % 101) / 100
            horizontalOrigin = 0.04 + unit * 0.92
            delay = TimeInterval(index % 8) * 0.035
            drift = CGFloat((index * 29) % 61 - 30)
            fallDistance = 0.58 + CGFloat((index * 17) % 28) / 100
            rotation = CGFloat((index * 47) % 360) * .pi / 180
            size = CGSize(width: index.isMultiple(of: 3) ? 8 : 5, height: 11)
            color = [
                DesignTokens.accent,
                DesignTokens.primaryText,
                Color(red: 0.35, green: 0.72, blue: 1),
                Color(red: 1, green: 0.48, blue: 0.38)
            ][index % 4]
        }

        func draw(
            in context: inout GraphicsContext,
            size canvasSize: CGSize,
            elapsed: TimeInterval
        ) {
            let rawProgress = (elapsed - delay) / (ReclaimedTimeConfettiView.duration - delay)
            guard rawProgress >= 0, rawProgress <= 1 else { return }
            let progress = CGFloat(rawProgress)
            let easedFall = progress * progress
            let x = horizontalOrigin * canvasSize.width
                + drift * sin(progress * .pi)
            let y = -self.size.height
                + easedFall * canvasSize.height * fallDistance
            let fade = min(1, max(0, (1 - progress) / 0.24))

            var particleContext = context
            particleContext.opacity = Double(fade)
            particleContext.translateBy(x: x, y: y)
            particleContext.rotate(by: .radians(rotation + progress * .pi * 5))
            let rect = CGRect(
                x: -self.size.width / 2,
                y: -self.size.height / 2,
                width: self.size.width,
                height: self.size.height
            )
            particleContext.fill(
                Path(roundedRect: rect, cornerRadius: 1),
                with: .color(color)
            )
        }
    }
}
