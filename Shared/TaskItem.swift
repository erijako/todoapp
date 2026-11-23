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
/// All properties have defaults so the model stays compatible with CloudKit sync later.
@Model
final class TaskItem {
    var id: UUID = UUID()
    var title: String = ""
    var isDone: Bool = false
    var isThought: Bool = false
    var modeRaw: String = TaskMode.personal.rawValue
    var createdAt: Date = Date()
    var completedAt: Date?
    var dueDate: Date?
    var sortOrder: Double = 0

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

    func toggleDone() {
        isDone.toggle()
        completedAt = isDone ? .now : nil
    }
}
