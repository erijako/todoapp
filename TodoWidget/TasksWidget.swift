import SwiftUI
import SwiftData
import WidgetKit

@main
struct TodoWidgetBundle: WidgetBundle {
    var body: some Widget {
        TasksWidget()
    }
}

struct TasksWidget: Widget {
    let kind = "TasksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TasksProvider()) { entry in
            TasksWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tasks")
        .description("Your top tasks, right on your lock screen.")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCircular,
            .systemSmall,
            .systemMedium,
        ])
    }
}

// MARK: - Timeline

struct TaskSnapshot: Identifiable {
    let id: UUID
    let title: String
}

struct TasksEntry: TimelineEntry {
    let date: Date
    let mode: TaskMode
    let tasks: [TaskSnapshot]
    let remaining: Int

    static let sample = TasksEntry(
        date: .now,
        mode: .personal,
        tasks: [
            TaskSnapshot(id: UUID(), title: "Buy milk"),
            TaskSnapshot(id: UUID(), title: "Call the dentist"),
            TaskSnapshot(id: UUID(), title: "Plan the weekend"),
        ],
        remaining: 3
    )
}

struct TasksProvider: TimelineProvider {
    func placeholder(in context: Context) -> TasksEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (TasksEntry) -> Void) {
        completion(context.isPreview ? .sample : loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TasksEntry>) -> Void) {
        let entry = loadEntry()
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60))))
    }

    private func loadEntry() -> TasksEntry {
        let mode = ModeStore.current
        let raw = mode.rawValue
        let context = ModelContext(SharedStore.container)
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { !$0.isDone && !$0.isThought && $0.modeRaw == raw },
            sortBy: [SortDescriptor(\TaskItem.sortOrder)]
        )
        let items = (try? context.fetch(descriptor)) ?? []
        return TasksEntry(
            date: .now,
            mode: mode,
            tasks: items.prefix(5).map { TaskSnapshot(id: $0.id, title: $0.title) },
            remaining: items.count
        )
    }
}

// MARK: - Views

struct TasksWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TasksEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            if let first = entry.tasks.first {
                Label(first.title, systemImage: "circle")
            } else {
                Label("All done", systemImage: "checkmark.circle")
            }

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: entry.mode.symbol)
                        .font(.caption2)
                    Text("\(entry.remaining)")
                        .font(.title3.bold())
                }
            }

        case .accessoryRectangular:
            TaskListContent(entry: entry, maxCount: 3, compact: true)

        case .systemMedium:
            TaskListContent(entry: entry, maxCount: 5, compact: false)

        default:
            TaskListContent(entry: entry, maxCount: 4, compact: false)
        }
    }
}

struct TaskListContent: View {
    let entry: TasksEntry
    let maxCount: Int
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 1 : 6) {
            if !compact {
                Label { Text(entry.mode.title) } icon: { Image(systemName: entry.mode.symbol) }
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            if entry.tasks.isEmpty {
                Label("All done", systemImage: "checkmark.circle")
                    .font(compact ? .caption : .body)
            } else {
                ForEach(entry.tasks.prefix(maxCount)) { task in
                    Button(intent: ToggleTaskIntent(taskID: task.id)) {
                        HStack(spacing: 4) {
                            Image(systemName: "circle")
                            Text(task.title)
                                .lineLimit(1)
                        }
                        .font(compact ? .caption : .subheadline)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !compact { Spacer(minLength: 0) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
