import ActivityKit
import AppIntents
import Foundation

/// Live Activity shown on the lock screen and in the Dynamic Island while a focus timer runs.
struct FocusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var start: Date
        var end: Date
        /// The thing to do right now (step or task).
        var title: String
        /// The parent task when `title` is a step.
        var subtitle: String?
    }

    var modeSymbol: String
}

// The intents below run in the app's process (LiveActivityIntent), so the controller,
// which lives in the app target, is only referenced when not compiling the widget.

/// Completes the current step/task from the Live Activity and moves on to the next one.
struct CompleteFocusTaskIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Complete Focus Task"
    static var isDiscoverable: Bool = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await FocusTimerController.completeCurrent()
        #endif
        return .result()
    }
}

/// Stops the focus timer and ends the Live Activity.
struct StopFocusIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Focus"
    static var isDiscoverable: Bool = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await FocusTimerController.stop()
        #endif
        return .result()
    }
}
