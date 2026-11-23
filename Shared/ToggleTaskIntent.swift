import AppIntents
import SwiftData
import WidgetKit

/// Checks off a task or one of its steps. Used by the interactive lock screen widget.
struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Off"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Task ID")
    var taskID: String

    @Parameter(title: "Step ID", default: "")
    var stepID: String

    init() {}

    init(taskID: UUID, stepID: UUID? = nil) {
        self.taskID = taskID.uuidString
        self.stepID = stepID?.uuidString ?? ""
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = SharedStore.container.mainContext

        if let stepUUID = UUID(uuidString: stepID) {
            let descriptor = FetchDescriptor<TaskStep>(predicate: #Predicate { $0.id == stepUUID })
            if let step = try context.fetch(descriptor).first {
                step.task?.toggleStep(step)
            }
        } else if let taskUUID = UUID(uuidString: taskID) {
            let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskUUID })
            if let task = try context.fetch(descriptor).first {
                task.toggleDone()
            }
        }

        context.saveAndRefresh()
        return .result()
    }
}
