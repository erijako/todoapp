import AppIntents
import SwiftData
import WidgetKit

/// Checks a task off (or back on). Used by the interactive lock screen widget.
struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Task"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Task ID")
    var taskID: String

    init() {}

    init(taskID: UUID) {
        self.taskID = taskID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: taskID) else { return .result() }

        let context = SharedStore.container.mainContext
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == uuid })
        if let task = try context.fetch(descriptor).first {
            task.toggleDone()
            try context.save()
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
