import ActivityKit
import Foundation
import SwiftData
import UserNotifications
import WidgetKit

/// A running focus timer. Stored in the shared App Group defaults so every part of the app agrees.
struct FocusTimerState: Codable, Equatable {
    var start: Date
    var end: Date
    var modeRaw: String

    var mode: TaskMode { TaskMode(rawValue: modeRaw) ?? .personal }
}

enum FocusTimerStore {
    static let key = "focusTimer"

    static var current: FocusTimerState? {
        get {
            guard let data = AppGroup.defaults.data(forKey: key) else { return nil }
            return try? JSONDecoder().decode(FocusTimerState.self, from: data)
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                AppGroup.defaults.set(data, forKey: key)
            } else {
                AppGroup.defaults.removeObject(forKey: key)
            }
        }
    }

    static func decode(_ data: Data?) -> FocusTimerState? {
        data.flatMap { try? JSONDecoder().decode(FocusTimerState.self, from: $0) }
    }
}

/// Starts, extends and stops the focus timer, and keeps the Live Activity and
/// the "time's up" notification in sync with it.
@MainActor
enum FocusTimerController {
    private static let notificationID = "focus-timer-end"

    static func start(minutes: Int, mode: TaskMode) async {
        let start = Date.now
        let end = start.addingTimeInterval(TimeInterval(minutes * 60))
        FocusTimerStore.current = FocusTimerState(start: start, end: end, modeRaw: mode.rawValue)

        await endActivities()
        if ActivityAuthorizationInfo().areActivitiesEnabled,
           let state = contentState(start: start, end: end, mode: mode) {
            _ = try? Activity.request(
                attributes: FocusActivityAttributes(modeSymbol: mode.symbol),
                content: ActivityContent(state: state, staleDate: end),
                pushType: nil
            )
        }
        await scheduleTimesUpNotification(at: end)
    }

    static func extend(minutes: Int) async {
        guard var timer = FocusTimerStore.current else { return }
        timer.end = max(timer.end, .now).addingTimeInterval(TimeInterval(minutes * 60))
        FocusTimerStore.current = timer
        await refreshActivity()
        await scheduleTimesUpNotification(at: timer.end)
    }

    static func stop() async {
        FocusTimerStore.current = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
        await endActivities()
    }

    /// Completes the current step/task of the running session, then shows the next one.
    static func completeCurrent() async {
        guard let timer = FocusTimerStore.current else { return }
        let context = SharedStore.container.mainContext
        if let next = FocusEngine.next(fetchItems(mode: timer.mode, context: context)) {
            next.completeNext()
            context.saveAndRefresh()
        }
        await refreshActivity()
    }

    /// Updates the Live Activity to show the current next thing. Stops when nothing is left.
    static func refreshActivity() async {
        guard let timer = FocusTimerStore.current else {
            await endActivities()
            return
        }
        guard let state = contentState(start: timer.start, end: timer.end, mode: timer.mode) else {
            // All clear: nothing left to focus on.
            await stop()
            return
        }
        let content = ActivityContent(state: state, staleDate: timer.end)
        for activity in Activity<FocusActivityAttributes>.activities {
            await activity.update(content)
        }
    }

    /// Cleans up a timer that ended long ago (e.g. the app was closed).
    static func cleanUpIfExpired() async {
        if let timer = FocusTimerStore.current, timer.end < .now.addingTimeInterval(-60 * 60) {
            await stop()
        }
    }

    // MARK: - Helpers

    private static func endActivities() async {
        for activity in Activity<FocusActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private static func fetchItems(mode: TaskMode, context: ModelContext) -> [TaskItem] {
        let raw = mode.rawValue
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.modeRaw == raw })
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func contentState(start: Date, end: Date, mode: TaskMode) -> FocusActivityAttributes.ContentState? {
        let context = SharedStore.container.mainContext
        guard let next = FocusEngine.next(fetchItems(mode: mode, context: context)) else { return nil }
        let step = next.currentStep
        return FocusActivityAttributes.ContentState(
            start: start,
            end: end,
            title: step?.title ?? next.title,
            subtitle: step == nil ? nil : next.title
        )
    }

    private static func scheduleTimesUpNotification(at end: Date) async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }

        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Time's up")
        content.body = String(localized: "Nice focus! Done, or a few more minutes?")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, end.timeIntervalSinceNow), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger))
    }
}
