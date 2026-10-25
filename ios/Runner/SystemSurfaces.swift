import Flutter
import UIKit
import WidgetKit
import ActivityKit

/// The bridge owns display caches and URL delivery, never business storage.
final class YikeSystemSurfaces {
    static let shared = YikeSystemSurfaces()
    private var channel: FlutterMethodChannel?
    private var waiting: [String] = []
    private var ready = false
    private var lastRequested: String?
    private var pendingUpdate: Task<Void, Never>?
    private func enqueue(_ work: @escaping @MainActor () async -> Void) {
        let previous = pendingUpdate
        pendingUpdate = Task { @MainActor in
            await previous?.value
            await work()
        }
    }

    func receive(_ url: URL) -> Bool {
        guard url.scheme == "yike", url.host == "surface" else { return false }
        if ready, let channel = channel { channel.invokeMethod("open", arguments: url.absoluteString) }
        else { waiting.append(url.absoluteString) }
        return true
    }
    func install(_ registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "yike/system_surfaces", binaryMessenger: registrar.messenger())
        self.channel = channel
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            switch call.method {
            case "launch":
                self.ready = true; let pending = self.waiting; self.waiting.removeAll(); result(pending)
            case "access":
                var activities = false, allowed = false
                if #available(iOS 16.1, *) { activities = true; allowed = ActivityAuthorizationInfo().areActivitiesEnabled }
                result(["widgets": true, "activities": activities, "allowed": allowed, "shared": SurfaceSnapshot.fileURL != nil])
            case "settings":
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                result(nil)
            case "publish":
                guard let raw = call.arguments as? String, let data = raw.data(using: .utf8),
                      let snapshot = try? JSONDecoder().decode(SurfaceSnapshot.self, from: data), snapshot.version == 1 else {
                    result(FlutterError(code: "invalid_projection", message: "Invalid display projection", details: nil)); return
                }
                self.enqueue {
                    do {
                        // Even when sharing is unavailable, revoke an old activity.
                        if !snapshot.readable || !snapshot.liveEnabled { await self.endAll(); self.lastRequested = nil }
                        guard let url = SurfaceSnapshot.fileURL else {
                            throw NSError(domain: "YikeSurfaces", code: 1)
                        }
                        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                        WidgetCenter.shared.reloadAllTimelines()
                        if #available(iOS 16.1, *) { try await self.reconcile(snapshot) }
                        result(nil)
                    } catch { result(FlutterError(code: "surface_update_failed", message: "System surface update failed", details: nil)) }
                }
            case "clear":
                self.waiting.removeAll()
                self.enqueue {
                    var removalError: Error?
                    if let url = SurfaceSnapshot.fileURL, FileManager.default.fileExists(atPath: url.path) {
                        do { try FileManager.default.removeItem(at: url) }
                        catch { removalError = error }
                    }
                    WidgetCenter.shared.reloadAllTimelines()
                    await self.endAll(); self.lastRequested = nil
                    if removalError != nil {
                        result(FlutterError(code: "surface_clear_failed", message: "Display cache removal failed", details: nil))
                    } else { result(nil) }
                }
            default: result(FlutterMethodNotImplemented)
            }
        }
    }
    @MainActor private func endAll() async {
        if #available(iOS 16.1, *) {
            for activity in Activity<YikeFocusAttributes>.activities { await activity.end(using: nil, dismissalPolicy: .immediate) }
        }
    }
    @available(iOS 16.1, *)
    @MainActor private func reconcile(_ snapshot: SurfaceSnapshot) async throws {
        guard snapshot.readable, snapshot.liveEnabled else { await endAll(); lastRequested = nil; return }
        let now = Date()
        let active = snapshot.timers.filter { $0.active }
        let completed = !snapshot.timers.isEmpty && snapshot.timers.allSatisfy { $0.status == "finished" }
        let state = YikeFocusAttributes.ContentState(epoch: snapshot.epoch, revision: snapshot.revision,
            generatedMs: snapshot.generatedMs, timers: active.isEmpty ? snapshot.timers : active,
            priorityMode: snapshot.priority(at: now)?.mode, theme: snapshot.theme, appearance: snapshot.appearance,
            palette: snapshot.palette, unsaved: snapshot.unsaved, ended: active.isEmpty)
        let deadline = active.filter { $0.status == "running" }.compactMap { t -> Date? in
            guard let anchor = t.anchorMs else { return nil }
            return Date(timeIntervalSince1970: Double(anchor + t.limitMs) / 1000)
        }.min()
        let all = Activity<YikeFocusAttributes>.activities
        let current = all.filter { activity in
            if #available(iOS 16.2, *) { return activity.activityState == .active || activity.activityState == .stale }
            return activity.activityState == .active
        }
        if active.isEmpty {
            if !completed { await endAll(); lastRequested = nil; return }
            for activity in current {
                let natural = activity.contentState.timers.allSatisfy { previous in
                    snapshot.timers.contains { $0.session == previous.session && $0.status == "finished" }
                }
                await activity.end(using: state, dismissalPolicy: natural ? .after(now.addingTimeInterval(300)) : .immediate)
            }
            return
        }
        for old in all where old.activityState == .ended { await old.end(using: nil, dismissalPolicy: .immediate) }
        let signature = snapshot.epoch + "/" + active.map { $0.session }.joined(separator: "/")
        if let existing = current.first {
            for duplicate in current.dropFirst() { await duplicate.end(using: nil, dismissalPolicy: .immediate) }
            if existing.attributes.identity != snapshot.epoch { await endAll(); lastRequested = nil }
            else {
                lastRequested = signature
                if #available(iOS 16.2, *) {
                    await existing.update(ActivityContent(state: state, staleDate: deadline))
                } else { await existing.update(using: state) }
                return
            }
        }
        guard UIApplication.shared.applicationState == .active,
              ActivityAuthorizationInfo().areActivitiesEnabled, lastRequested != signature else { return }
        if #available(iOS 16.2, *) {
            _ = try Activity.request(attributes: YikeFocusAttributes(identity: snapshot.epoch), content: ActivityContent(state: state, staleDate: deadline), pushType: nil)
        } else {
            _ = try Activity.request(attributes: YikeFocusAttributes(identity: snapshot.epoch), contentState: state, pushType: nil)
        }
        lastRequested = signature
    }
}
