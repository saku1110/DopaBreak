import ActivityKit
import DopaBreakCore
import SwiftUI
import WidgetKit

private extension Color {
    init(lockThemeColor color: LockThemeColor) {
        self.init(
            red: Double(color.red) / 255,
            green: Double(color.green) / 255,
            blue: Double(color.blue) / 255
        )
    }
}

struct DopaBreakHomeEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct DopaBreakHomeProvider: TimelineProvider {
    func placeholder(in context: Context) -> DopaBreakHomeEntry {
        DopaBreakHomeEntry(date: Date(), snapshot: Self.placeholderSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (DopaBreakHomeEntry) -> Void) {
        completion(DopaBreakHomeEntry(date: Date(), snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DopaBreakHomeEntry>) -> Void) {
        let now = Date()
        let snapshot = loadSnapshot()
        let nextMidnight = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: now)
        ) ?? now.addingTimeInterval(86_400)
        var nextMidnightSnapshot = snapshot
        nextMidnightSnapshot.todayCancelledCount = 0
        nextMidnightSnapshot.todayAttemptCount = 0
        let entries = [
            DopaBreakHomeEntry(date: now, snapshot: snapshot),
            DopaBreakHomeEntry(date: nextMidnight, snapshot: nextMidnightSnapshot)
        ]
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func loadSnapshot() -> WidgetSnapshot {
        (try? JSONSnapshotStore().read(WidgetSnapshot.self, from: .widgetSnapshot))
            ?? Self.placeholderSnapshot
    }

    private static let placeholderSnapshot = WidgetSnapshot(
        primaryGoalTitle: String(localized: "widget.placeholder.goal", defaultValue: "あなたの目標"),
        displayTitle: String(localized: "widget.placeholder.goal", defaultValue: "あなたの目標"),
        todayCancelledCount: 0,
        todayAttemptCount: 0,
        theme: .e1,
        updatedAt: Date(),
        goalTitles: [String(localized: "widget.placeholder.goal", defaultValue: "あなたの目標")],
        displayTitles: [String(localized: "widget.placeholder.goal", defaultValue: "あなたの目標")]
    )
}

struct DopaBreakHomeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DopaBreakHomeEntry

    private var palette: LockThemePalette { entry.snapshot.theme.palette }
    private var displayTitles: [String] {
        let titles = entry.snapshot.displayTitles.filter { !$0.isEmpty }
        return titles.isEmpty ? [entry.snapshot.displayTitle].filter { !$0.isEmpty } : titles
    }

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumContent
            default:
                smallContent
            }
        }
        .containerBackground(Color(lockThemeColor: palette.background), for: .widget)
    }

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Circle()
                .fill(Color(lockThemeColor: palette.accent))
                .frame(width: 7, height: 7)

            Text(
                String(
                    localized: "widget.count.value",
                    defaultValue: "\(entry.snapshot.todayCancelledCount)"
                )
            )
                .font(.system(size: 42, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color(lockThemeColor: palette.accent))

            Text(String(localized: "widget.summary.today_cancelled", defaultValue: "今日 開かなかった回数"))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(lockThemeColor: palette.secondaryText))

            Spacer(minLength: 4)

            Text(
                displayTitles.first
                    ?? String(localized: "widget.goal.fallback", defaultValue: "目標を設定")
            )
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(lockThemeColor: palette.primaryText))
                .lineLimit(2)
        }
    }

    private var mediumContent: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "widget.goal.eyebrow", defaultValue: "YOUR GOAL"))
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Color(lockThemeColor: palette.secondaryText))

                ForEach(Array(displayTitles.prefix(2).enumerated()), id: \.offset) { _, title in
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(lockThemeColor: palette.primaryText))
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color(lockThemeColor: palette.secondaryText).opacity(0.25))
                .frame(width: 1)

            VStack(alignment: .leading, spacing: 5) {
                Text(
                    String(
                        localized: "widget.count.value",
                        defaultValue: "\(entry.snapshot.todayCancelledCount)"
                    )
                )
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(lockThemeColor: palette.accent))
                Text(String(localized: "widget.summary.today_cancelled", defaultValue: "今日 開かなかった回数"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(lockThemeColor: palette.secondaryText))
                Spacer(minLength: 0)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(lockThemeColor: palette.secondaryText).opacity(0.22))
                        Capsule()
                            .fill(Color(lockThemeColor: palette.accent))
                            .frame(width: proxy.size.width * successRate)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var successRate: CGFloat {
        guard entry.snapshot.todayAttemptCount > 0 else { return 0 }
        return min(1, CGFloat(entry.snapshot.todayCancelledCount) / CGFloat(entry.snapshot.todayAttemptCount))
    }
}

struct DopaBreakHomeWidget: Widget {
    let kind = "DopaBreakHome"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DopaBreakHomeProvider()) { entry in
            DopaBreakHomeWidgetView(entry: entry)
        }
        .configurationDisplayName(
            String(localized: "widget.configuration.name", defaultValue: "DopaBreak")
        )
        .description(
            String(localized: "widget.configuration.description", defaultValue: "目標と、今日開かなかった回数を表示します")
        )
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DopaBreakLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DopaBreakActivityAttributes.self) { context in
            let resolvedTheme = theme(for: context.state)
            if resolvedTheme == .liquidGlass {
                liveActivityView(state: context.state)
                    .activitySystemActionForegroundColor(.white)
            } else {
                liveActivityView(state: context.state)
                    .activityBackgroundTint(
                        Color(lockThemeColor: activityBackgroundColor(for: resolvedTheme))
                    )
                    .activitySystemActionForegroundColor(
                        Color(lockThemeColor: resolvedTheme.palette.primaryText)
                    )
            }
        } dynamicIsland: { context in
            let palette = theme(for: context.state).palette
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(String(localized: "live_activity.today", defaultValue: "今日"))
                        .font(.caption2.bold())
                        .foregroundStyle(Color(lockThemeColor: palette.secondaryText))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(
                        String(
                            localized: "widget.count.with_unit",
                            defaultValue: "\(context.state.todayCancelledCount)回"
                        )
                    )
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(Color(lockThemeColor: palette.accent))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(context.state.goalTitles.enumerated()), id: \.offset) { _, title in
                            Text(title)
                                .font(.caption.bold())
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "checkmark.shield.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(lockThemeColor: palette.accent))
                    .accessibilityHidden(true)
            } compactTrailing: {
                Text(
                    String(
                        localized: "widget.count.value",
                        defaultValue: "\(context.state.todayCancelledCount)"
                    )
                )
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(Color(lockThemeColor: palette.accent))
                    .accessibilityLabel(
                        Text(
                            String(
                                localized: "live_activity.summary.cancelled",
                                defaultValue: "今日は\(context.state.todayCancelledCount)回 開かなかった"
                            )
                        )
                    )
            } minimal: {
                Text(
                    String(
                        localized: "widget.count.value",
                        defaultValue: "\(context.state.todayCancelledCount)"
                    )
                )
                    .font(.caption2.bold().monospacedDigit())
                    .foregroundStyle(Color(lockThemeColor: palette.accent))
                    .accessibilityLabel(
                        Text(
                            String(
                                localized: "live_activity.summary.cancelled",
                                defaultValue: "今日は\(context.state.todayCancelledCount)回 開かなかった"
                            )
                        )
                    )
            }
            .keylineTint(Color(lockThemeColor: palette.accent))
        }
    }

    private func liveActivityView(
        state: DopaBreakActivityAttributes.ContentState
    ) -> LockThemeLiveActivityView {
        LockThemeLiveActivityView(
            theme: theme(for: state),
            goalTitles: state.goalTitles,
            cancelledCount: state.todayCancelledCount,
            attemptCount: state.todayAttemptCount
        )
    }

    private func theme(for state: DopaBreakActivityAttributes.ContentState) -> LockTheme {
        LockTheme(migratingRawValue: state.themeRawValue)
    }

    private func activityBackgroundColor(for theme: LockTheme) -> LockThemeColor {
        switch theme {
        case .e1, .kpop, .kawaiiPink:
            return theme.palette.card
        case .asagiri:
            return .init(237, 241, 245)
        default:
            return theme.palette.background
        }
    }
}

@main
struct DopaBreakWidgetsBundle: WidgetBundle {
    init() {
        DopaBreakFontRegistrar.registerBundledFonts()
    }

    var body: some Widget {
        DopaBreakHomeWidget()
        DopaBreakLiveActivity()
    }
}
