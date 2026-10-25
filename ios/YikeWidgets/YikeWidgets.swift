import SwiftUI
import WidgetKit
import ActivityKit

struct SurfaceEntry: TimelineEntry {
    let date: Date
    let snapshot: SurfaceSnapshot?
}
struct SurfaceProvider: TimelineProvider {
    func placeholder(in context: Context) -> SurfaceEntry { SurfaceEntry(date: Date(), snapshot: nil) }
    func getSnapshot(in context: Context, completion: @escaping (SurfaceEntry) -> Void) {
        completion(SurfaceEntry(date: Date(), snapshot: SurfaceSnapshot.read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SurfaceEntry>) -> Void) {
        let now = Date(), snapshot = SurfaceSnapshot.read()
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(36 * 3600)
        let nextDay = Calendar.current.startOfDay(for: midnight)
        var dates = [now, nextDay]
        for timer in snapshot?.timers ?? [] where timer.status == "running" {
            if let anchor = timer.anchorMs {
                let deadline = Date(timeIntervalSince1970: Double(anchor + timer.limitMs) / 1000)
                if deadline > now { dates.append(deadline) }
            }
        }
        let entries = Array(Set(dates)).sorted().map { SurfaceEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .after(min(nextDay, now.addingTimeInterval(30 * 60)))))
    }
}

struct SurfaceColors {
    let palette: [String: String]
    let appearance: String
    func dark(_ scheme: ColorScheme) -> Bool { appearance == "dark" || (appearance != "light" && scheme == .dark) }
    func color(_ key: String, scheme: ColorScheme, fallback: Color) -> Color {
        let prefix = dark(scheme) ? "dark" : "light"
        guard let value = palette[prefix + key], let hex = UInt64(value, radix: 16) else { return fallback }
        return Color(.sRGB, red: Double((hex >> 16) & 255) / 255,
            green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

struct SurfaceTime: View {
    let timer: SurfaceTimer
    let date: Date
    var body: some View {
        Group {
            if #available(iOS 16.0, *), timer.status == "running", timer.remaining(at: date) > 0,
               let anchor = timer.anchorMs {
                let start = Date(timeIntervalSince1970: Double(anchor) / 1000)
                let end = start.addingTimeInterval(Double(timer.limitMs) / 1000)
                Text(timerInterval: start...end, countsDown: timer.mode != "stopwatch", showsHours: false)
            } else { Text(timer.digits(at: date)) }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .accessibilityLabel("\(timer.label)，\(timer.digits(at: date))，\(timer.displayStatus(at: date))")
    }
}

struct SurfaceProgress: View {
    let timer: SurfaceTimer
    let date: Date
    let accent: Color
    var body: some View {
        Group {
            if #available(iOS 16.0, *), timer.status == "running", timer.remaining(at: date) > 0, let anchor = timer.anchorMs {
                let start = Date(timeIntervalSince1970: Double(anchor) / 1000)
                ProgressView(timerInterval: start...start.addingTimeInterval(Double(timer.limitMs) / 1000), countsDown: timer.mode != "stopwatch") {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
            } else { ProgressView(value: timer.progress(at: date)) }
        }
        .progressViewStyle(.linear)
        .tint(accent)
        .frame(height: 4)
    }
}

struct SurfaceEmpty: View {
    let title: String
    let message: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("一刻", systemImage: "circle.lefthalf.filled").font(.caption).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct SurfaceTimerRow: View {
    let timer: SurfaceTimer
    let snapshot: SurfaceSnapshot
    let date: Date
    let large: Bool
    let accent: Color
    var body: some View {
        HStack(spacing: 8) {
            Link(destination: snapshot.url(timer: timer)) {
                HStack(spacing: 8) {
                    Image(systemName: timer.symbol).foregroundStyle(accent).frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(timer.label).font(.caption).fontWeight(.medium)
                        if large { Text(timer.detail).font(.caption2).foregroundStyle(.secondary) }
                    }
                    Spacer(minLength: 4)
                    if timer.status == "paused" { Image(systemName: "pause.fill").font(.caption2).foregroundStyle(.secondary) }
                    SurfaceTime(timer: timer, date: date).font(.system(large ? .title3 : .body, design: .rounded).weight(.semibold))
                        .frame(width: large ? 88 : 72, alignment: .trailing)
                }.frame(maxWidth: .infinity, minHeight: large ? 44 : 25)
            }.buttonStyle(.plain)
            if large, timer.active, timer.status == "paused" || timer.remaining(at: date) > 0 {
                Link(destination: snapshot.url(timer: timer, action: timer.status == "paused" ? "resume" : "pause")) {
                    Image(systemName: timer.status == "paused" ? "play.fill" : "pause.fill")
                        .font(.body).foregroundStyle(accent).frame(width: 44, height: 44)
                        .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                }.accessibilityLabel("打开一刻\(timer.status == "paused" ? "继续" : "暂停")\(timer.label)")
            }
        }
    }
}

struct FocusSurfaceView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    let entry: SurfaceEntry
    var snapshot: SurfaceSnapshot? { entry.snapshot }
    var colors: SurfaceColors { SurfaceColors(palette: snapshot?.palette ?? [:], appearance: snapshot?.appearance ?? "system") }
    var foreground: Color {
        if #available(iOS 16.0, *), family == .accessoryInline || family == .accessoryRectangular { return .primary }
        return colors.color("Foreground", scheme: scheme, fallback: .primary)
    }
    var body: some View {
        let accent = colors.color("Accent", scheme: scheme, fallback: .orange)
        Group {
            if #available(iOS 16.0, *), family == .accessoryInline {
                if let timer = snapshot?.priority(at: entry.date) {
                    HStack { Text(timer.label); if timer.status == "paused" { Text("已暂停") } else { SurfaceTime(timer: timer, date: entry.date) } }
                } else { Text(snapshot == nil ? "打开一刻更新" : "暂无进行中的专注") }
            } else if #available(iOS 16.0, *), family == .accessoryRectangular {
                if let timer = snapshot?.priority(at: entry.date) {
                    VStack(alignment: .leading, spacing: 3) {
                        Label(timer.label, systemImage: timer.symbol).font(.caption)
                        HStack { SurfaceTime(timer: timer, date: entry.date).font(.title3.bold()); if timer.status == "paused" { Text("已暂停").font(.caption2) } }
                    }
                } else { Text(snapshot == nil ? "打开一刻更新" : "暂无进行中的专注").font(.caption) }
            } else if let snapshot = snapshot {
                if family == .systemSmall {
                    VStack(alignment: .leading, spacing: 9) {
                        Label("一刻 · 专注", systemImage: "circle.lefthalf.filled").font(.caption).foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        if let timer = snapshot.priority(at: entry.date) {
                            Label(timer.label, systemImage: timer.symbol).font(.subheadline).foregroundStyle(accent)
                            SurfaceTime(timer: timer, date: entry.date).font(.system(size: 32, weight: .semibold, design: .rounded)).minimumScaleFactor(0.65).lineLimit(1)
                            Text(timer.displayStatus(at: entry.date)).font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text(snapshot.timers.isEmpty ? "留一刻，专注此刻" : "本次计时已到点").font(.headline)
                            Text("打开一刻查看").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    let rows = snapshot.timers.filter { $0.status == "paused" || ($0.status == "running" && $0.remaining(at: entry.date) > 0) }
                    VStack(alignment: .leading, spacing: family == .systemLarge ? 14 : 4) {
                        HStack {
                            Label("一刻 · 专注", systemImage: "circle.lefthalf.filled").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            if snapshot.unsaved { Text("尚未保存").font(.caption2).foregroundStyle(.secondary) }
                        }
                        if rows.isEmpty {
                            Spacer(minLength: 0)
                            Text(snapshot.timers.isEmpty ? "留一刻，专注此刻" : "本次计时已到点").font(.headline)
                            Text("打开一刻查看").font(.caption).foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        } else {
                            ForEach(rows) { timer in
                                VStack(spacing: 3) {
                                    SurfaceTimerRow(timer: timer, snapshot: snapshot, date: entry.date, large: family == .systemLarge, accent: accent)
                                    if family == .systemLarge { SurfaceProgress(timer: timer, date: entry.date, accent: accent) }
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        HStack {
                            Text("今日已记录 \(snapshot.todaySeconds / 60) 分钟")
                            Spacer(minLength: 2)
                            if #unavailable(iOS 16.0) { Text(snapshot.generated, style: .time) }
                        }.font(.caption2).foregroundStyle(.secondary)
                    }
                }
            } else { SurfaceEmpty(title: "专注此刻", message: "打开一刻更新小部件") }
        }
        .foregroundStyle(foreground)
        .widgetURL(snapshot?.url(timer: snapshot?.priority(at: entry.date)) ?? SurfaceSnapshot.url(epoch: "", revision: 0))
        .surfaceBackground(colors.color("Background", scheme: scheme, fallback: Color(.systemBackground)))
    }
}

struct HabitSurfaceView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    let entry: SurfaceEntry
    var foreground: Color {
        if #available(iOS 16.0, *), family == .accessoryCircular { return .primary }
        let colors = SurfaceColors(palette: entry.snapshot?.palette ?? [:], appearance: entry.snapshot?.appearance ?? "system")
        return colors.color("Foreground", scheme: scheme, fallback: .primary)
    }
    var body: some View {
        let snapshot = entry.snapshot
        let valid = snapshot?.sameDay(entry.date) == true
        let colors = SurfaceColors(palette: snapshot?.palette ?? [:], appearance: snapshot?.appearance ?? "system")
        let accent = colors.color("Accent", scheme: scheme, fallback: .orange)
        Group {
            if #available(iOS 16.0, *), family == .accessoryCircular {
                if let s = snapshot, valid {
                    Gauge(value: Double(s.habitDone), in: 0...Double(max(1, s.habitTotal))) {
                        Image(systemName: "checkmark")
                    } currentValueLabel: { Text("\(s.habitDone)") }
                        .gaugeStyle(.accessoryCircular).tint(accent)
                        .accessibilityLabel("今日已完成 \(s.habitDone) / \(s.habitTotal) 项习惯")
                } else { Image(systemName: "arrow.clockwise").accessibilityLabel("打开一刻更新今日进度") }
            } else if let s = snapshot, valid {
                VStack(alignment: .leading, spacing: family == .systemSmall ? 10 : 5) {
                    HStack {
                        Text("今日打卡").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if s.unsaved { Text("尚未保存").font(.caption2).foregroundStyle(.secondary) }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(s.habitDone)").font(.system(size: family == .systemSmall ? 30 : 23, weight: .semibold, design: .rounded)).foregroundStyle(accent)
                        Text("/ \(s.habitTotal)").font(.subheadline).foregroundStyle(.secondary)
                        if family != .systemSmall { Spacer(); Text(s.habitTotal == 0 ? "还没有进行中的习惯" : s.habitDone == s.habitTotal ? "今天都完成了" : "慢慢积累，每天一刻").font(.caption2).foregroundStyle(.secondary) }
                    }
                    if s.habitTotal > 0 { ProgressView(value: Double(s.habitDone) / Double(s.habitTotal)).tint(accent) }
                    ForEach(Array(s.habits.prefix(family == .systemSmall ? 1 : 3))) { habit in
                        Link(destination: s.url(target: "habits", habit: habit.id)) {
                            HStack(spacing: 7) {
                                Image(systemName: habit.symbol).frame(width: 15).foregroundStyle(accent)
                                Text(habit.name).lineLimit(1)
                                Spacer(minLength: 1)
                                Image(systemName: habit.done ? "checkmark.circle.fill" : "circle").foregroundStyle(habit.done ? accent : .secondary)
                            }.font(.caption).frame(maxWidth: .infinity, minHeight: family == .systemSmall ? 20 : 17)
                        }.accessibilityLabel("\(habit.name)，\(habit.done ? "今日已完成" : "今日未完成")")
                    }
                    if s.habitTotal == 0 { Text("打开一刻创建习惯").font(.caption).foregroundStyle(.secondary) }
                    Spacer(minLength: 0)
                }.frame(maxWidth: .infinity, alignment: .leading)
            } else { SurfaceEmpty(title: "每天积累一点", message: "打开一刻更新今日打卡") }
        }
        .foregroundStyle(foreground)
        .widgetURL(snapshot?.url(target: "habits", habit: family == .systemSmall ? snapshot?.habits.first?.id : nil) ?? SurfaceSnapshot.url(epoch: "", revision: 0, target: "habits"))
        .surfaceBackground(colors.color("Background", scheme: scheme, fallback: Color(.systemBackground)))
    }
}

extension View {
    @ViewBuilder func surfaceBackground(_ color: Color) -> some View {
        if #available(iOS 17.0, *) { self.containerBackground(color.gradient, for: .widget) }
        else { self.padding(12).background(color) }
    }
}

struct FocusWidget: Widget {
    var families: [WidgetFamily] {
        if #available(iOS 16.0, *) { return [.systemSmall, .systemMedium, .systemLarge, .accessoryInline, .accessoryRectangular] }
        return [.systemSmall, .systemMedium, .systemLarge]
    }
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "YikeFocus", provider: SurfaceProvider()) { FocusSurfaceView(entry: $0) }
            .configurationDisplayName("专注进度").description("查看三种计时的进度与暂停状态")
            .supportedFamilies(families)
    }
}
struct HabitWidget: Widget {
    var families: [WidgetFamily] {
        if #available(iOS 16.0, *) { return [.systemSmall, .systemMedium, .accessoryCircular] }
        return [.systemSmall, .systemMedium]
    }
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "YikeHabits", provider: SurfaceProvider()) { HabitSurfaceView(entry: $0) }
            .configurationDisplayName("今日打卡").description("查看今日完成进度和进行中的习惯")
            .supportedFamilies(families)
    }
}

@available(iOS 16.1, *)
struct ActivitySurfaceView: View {
    let state: YikeFocusAttributes.ContentState
    let stale: Bool
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let colors = SurfaceColors(palette: state.palette, appearance: state.appearance)
        let accent = colors.color("Accent", scheme: scheme, fallback: .orange)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(state.ended ? "本次计时完成" : "一刻 · 专注", systemImage: "circle.lefthalf.filled").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if state.unsaved { Text("尚未保存").font(.caption2).foregroundStyle(.secondary) }
                if stale && !state.ended { Text("打开一刻更新").font(.caption2).foregroundStyle(.secondary) }
            }
            ForEach(state.timers) { timer in
                VStack(spacing: 2) {
                    HStack(spacing: 8) {
                        Link(destination: state.url(timer: timer)) {
                            HStack(spacing: 8) {
                                Image(systemName: timer.symbol).foregroundStyle(accent).frame(width: 20)
                                Text(timer.label).font(.subheadline).lineLimit(1)
                                if timer.status == "paused" { Image(systemName: "pause.fill").font(.caption2).foregroundStyle(.secondary) }
                                Spacer(minLength: 3)
                                // System timer text has no finite ideal width during
                                // WidgetKit archiving. fixedSize() makes the row (and
                                // its progress bar) acquire a NaN horizontal origin.
                                SurfaceTime(timer: timer, date: Date()).font(.system(.title3, design: .rounded).weight(.semibold))
                                    .frame(width: 88, alignment: .trailing)
                            }.frame(minHeight: 28)
                        }.buttonStyle(.plain)
                        if !state.ended, !stale, timer.active {
                            Link(destination: state.url(timer: timer, action: timer.status == "paused" ? "resume" : "pause")) {
                                Image(systemName: timer.status == "paused" ? "play.fill" : "pause.fill")
                                    .font(.body).frame(width: 40, height: 32).foregroundStyle(accent)
                            }.accessibilityLabel("打开一刻\(timer.status == "paused" ? "继续" : "暂停")\(timer.label)")
                        }
                    }
                    if !state.ended { SurfaceProgress(timer: timer, date: Date(), accent: accent) }
                }
            }
        }.padding(12)
    }
}

@available(iOS 16.1, *)
struct YikeLiveActivity: Widget {
    private func isStale(_ context: ActivityViewContext<YikeFocusAttributes>) -> Bool {
        if #available(iOS 16.2, *) { return context.isStale }
        return false
    }
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: YikeFocusAttributes.self) { context in
            ActivitySurfaceView(state: context.state, stale: isStale(context))
                .activityBackgroundTint(Color(.secondarySystemBackground))
                .widgetURL(context.state.url(timer: context.state.priority))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    ActivitySurfaceView(state: context.state, stale: isStale(context))
                }
            } compactLeading: {
                Image(systemName: context.state.priority?.symbol ?? "checkmark")
            } compactTrailing: {
                if let timer = context.state.priority {
                    if timer.status == "paused" { Image(systemName: "pause.fill") }
                    else { SurfaceTime(timer: timer, date: Date()).font(.caption).frame(width: 58, alignment: .trailing) }
                } else { Image(systemName: "checkmark") }
            } minimal: {
                Image(systemName: context.state.priority?.status == "paused" ? "pause.fill" : context.state.priority?.symbol ?? "checkmark")
            }
            .widgetURL(context.state.url(timer: context.state.priority))
        }
    }
}

@main
struct YikeWidgets: WidgetBundle {
    var body: some Widget {
        FocusWidget()
        HabitWidget()
        if #available(iOS 16.1, *) { YikeLiveActivity() }
    }
}
