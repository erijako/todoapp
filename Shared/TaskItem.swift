import Foundation
import SwiftData

/// Which part of life a task belongs to.
enum TaskMode: String, Codable, CaseIterable, Identifiable {
    case personal
    case work

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .personal: "Personal"
        case .work: "Work"
        }
    }

    var symbol: String {
        switch self {
        case .personal: "house"
        case .work: "briefcase"
        }
    }
}

/// A task or a loose thought. Thoughts are captured fast and can be turned into tasks later.
///
/// All properties have defaults and relationships are optional so the model stays
/// compatible with CloudKit sync (and sharing) later.
@Model
final class TaskItem {
    var id: UUID = UUID()
    var title: String = ""
    var isDone: Bool = false
    var isThought: Bool = false
    var isPinned: Bool = false
    var modeRaw: String = TaskMode.personal.rawValue
    var createdAt: Date = Date()
    var completedAt: Date?
    var dueDate: Date?
    var sortOrder: Double = 0

    @Relationship(deleteRule: .cascade, inverse: \TaskStep.task)
    var steps: [TaskStep]? = []

    var mode: TaskMode {
        get { TaskMode(rawValue: modeRaw) ?? .personal }
        set { modeRaw = newValue.rawValue }
    }

    init(title: String, mode: TaskMode, isThought: Bool = false, dueDate: Date? = nil) {
        self.id = UUID()
        self.title = title
        self.modeRaw = mode.rawValue
        self.isThought = isThought
        self.dueDate = dueDate
        self.createdAt = .now
        self.sortOrder = Date.now.timeIntervalSince1970
    }

    // MARK: Steps

    var sortedSteps: [TaskStep] {
        (steps ?? []).sorted { $0.order < $1.order }
    }

    var stepCount: Int { steps?.count ?? 0 }

    var doneStepCount: Int { (steps ?? []).filter(\.isDone).count }

    /// The first step that is not done yet.
    var currentStep: TaskStep? {
        sortedSteps.first { !$0.isDone }
    }

    /// 1-based position of the current step.
    var currentStepNumber: Int? {
        guard let current = currentStep else { return nil }
        return sortedSteps.firstIndex { $0.id == current.id }.map { $0 + 1 }
    }

    var completedToday: Bool {
        guard isDone, let completedAt else { return false }
        return Calendar.current.isDateInToday(completedAt)
    }

    func addStep(_ title: String, in context: ModelContext) {
        let step = TaskStep(title: title, order: (sortedSteps.last?.order ?? -1) + 1)
        context.insert(step)
        step.task = self
    }

    // MARK: Completing

    func toggleDone() {
        isDone.toggle()
        completedAt = isDone ? .now : nil
    }

    /// Toggles a step. Finishing the last step finishes the task; reopening a step reopens it.
    func toggleStep(_ step: TaskStep) {
        step.isDone.toggle()
        if (steps ?? []).allSatisfy(\.isDone) {
            isDone = true
            completedAt = .now
        } else if isDone {
            isDone = false
            completedAt = nil
        }
    }

    /// Completes the current step, or the whole task if it has no open steps.
    func completeNext() {
        guard !isDone else { return }
        if let step = currentStep {
            toggleStep(step)
        } else {
            toggleDone()
        }
    }
}

/// A tiny step of a task. Small enough that starting feels easy.
@Model
final class TaskStep {
    var id: UUID = UUID()
    var title: String = ""
    var isDone: Bool = false
    var order: Int = 0
    var task: TaskItem?

    init(title: String, order: Int) {
        self.id = UUID()
        self.title = title
        self.order = order
    }
}

/// Decides what "the next thing" is. Shared by the app and the widget so they always agree.
enum FocusEngine {
    /// Open tasks in focus order: pinned first, then in the order they were added.
    static func openTasks(_ items: [TaskItem]) -> [TaskItem] {
        items
            .filter { !$0.isDone && !$0.isThought }
            .sorted { a, b in
                if a.isPinned != b.isPinned { return a.isPinned }
                return a.sortOrder < b.sortOrder
            }
    }

    static func next(_ items: [TaskItem]) -> TaskItem? {
        openTasks(items).first
    }
}
