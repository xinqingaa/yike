import Foundation
import ActivityKit

let yikeAppGroup = "group.com.protobridge.yike"
let yikeSurfaceFile = "surfaces-v1.json"

struct SurfaceTimer: Codable, Hashable, Identifiable {
    let mode, session, stage, status, token: String
    let elapsedMs, limitMs, scaleSeconds, round, laps: Int
    let anchorMs: Int?
    var id: String { session }
    var active: Bool { status == "running" || status == "paused" }
    var label: String {
        if mode == "pomodoro" { return stage == "focus" ? "番茄钟" : (stage == "longBreak" ? "长休息" : "短休息") }
        return mode == "stopwatch" ? "正计时" : "倒计时"
    }
    var symbol: String { mode == "pomodoro" ? (stage == "focus" ? "timer" : "cup.and.saucer") : mode == "stopwatch" ? "stopwatch" : "hourglass" }
    var detail: String { mode == "pomodoro" ? "第 \(round) 轮" : mode == "stopwatch" ? "\(laps) 圈" : "" }
    var stateToken: String { token }
    func elapsed(at date: Date) -> Int {
        let value = status == "running" ? Int(date.timeIntervalSince1970 * 1000) - (anchorMs ?? Int(date.timeIntervalSince1970 * 1000)) : elapsedMs
        return max(0, min(limitMs, value))
    }
    func remaining(at date: Date) -> Int { max(0, limitMs - elapsed(at: date)) }
    func seconds(at date: Date) -> Int { mode == "stopwatch" ? elapsed(at: date) / 1000 : Int(ceil(Double(remaining(at: date)) / 1000)) }
    func digits(at date: Date) -> String {
        let value = seconds(at: date)
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
    func displayStatus(at date: Date) -> String {
        status == "paused" ? "已暂停" : (status == "finished" || remaining(at: date) == 0 ? "已到点" : "进行中")
    }
    func progress(at date: Date) -> Double {
        let value = mode == "stopwatch" ? elapsed(at: date) : remaining(at: date)
        return min(1, max(0, Double(value) / Double(max(1, scaleSeconds * 1000))))
    }
}

struct SurfaceHabit: Codable, Hashable, Identifiable {
    let id, name, icon: String
    let done: Bool
    var symbol: String {
        switch icon {
        case "water": return "drop"
        case "book": return "book"
        case "running": return "figure.run"
        case "moon": return "moon"
        case "stretch": return "figure.flexibility"
        default: return "leaf"
        }
    }
}

struct SurfaceSnapshot: Codable {
    let version: Int
    let epoch: String
    let revision, generatedMs: Int
    let date, timezone: String
    let readable, unsaved, liveEnabled: Bool
    let theme, appearance: String
    let timers: [SurfaceTimer]
    let todaySeconds, habitTotal, habitDone: Int
    let habits: [SurfaceHabit]
    let palette: [String: String]
    var generated: Date { Date(timeIntervalSince1970: Double(generatedMs) / 1000) }
    func sameDay(_ now: Date) -> Bool { date == Self.day(now) }
    static func day(_ now: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: now)
    }
    func priority(at now: Date) -> SurfaceTimer? { Self.priority(timers, at: now) }
    static func priority(_ timers: [SurfaceTimer], at now: Date) -> SurfaceTimer? {
        let order = ["pomodoro", "stopwatch", "countdown"]
        let running = timers.filter { $0.status == "running" && $0.remaining(at: now) > 0 }.sorted {
            let a = $0.remaining(at: now), b = $1.remaining(at: now)
            return a != b ? a < b : (order.firstIndex(of: $0.mode) ?? 3) < (order.firstIndex(of: $1.mode) ?? 3)
        }
        return running.first ?? order.compactMap { mode in timers.first { $0.mode == mode && $0.status == "paused" } }.first
    }
    func url(target: String = "focus", timer: SurfaceTimer? = nil, action: String = "view", habit: String? = nil) -> URL {
        Self.url(epoch: epoch, revision: revision, target: target, timer: timer, action: action, habit: habit)
    }
    static func url(epoch: String, revision: Int, target: String = "focus", timer: SurfaceTimer? = nil, action: String = "view", habit: String? = nil) -> URL {
        var components = URLComponents(); components.scheme = "yike"; components.host = "surface"
        var items = ["v": "1", "target": target, "action": action]
        if let timer = timer {
            items["mode"] = timer.mode
            if action != "view" {
                items["session"] = timer.session; items["stage"] = timer.stage
                items["expected"] = timer.status; items["epoch"] = epoch
                items["revision"] = String(revision); items["token"] = timer.stateToken
            }
        }
        if let habit = habit { items["habit"] = habit }
        components.queryItems = items.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        return components.url!
    }
    static var fileURL: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: yikeAppGroup)?.appendingPathComponent(yikeSurfaceFile) }
    static func read() -> SurfaceSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode(Self.self, from: data),
              value.version == 1, value.readable, !value.epoch.isEmpty,
              value.timers.count <= 3, value.habits.count <= 3 else { return nil }
        return value
    }
}

@available(iOS 16.1, *)
struct YikeFocusAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let epoch: String
        let revision, generatedMs: Int
        let timers: [SurfaceTimer]
        let priorityMode: String?
        let theme, appearance: String
        let palette: [String: String]
        let unsaved: Bool
        let ended: Bool
        var priority: SurfaceTimer? { timers.first { $0.mode == priorityMode } }
        func url(timer: SurfaceTimer? = nil, action: String = "view") -> URL {
            SurfaceSnapshot.url(epoch: epoch, revision: revision, timer: timer, action: action)
        }
    }
    let identity: String
}
