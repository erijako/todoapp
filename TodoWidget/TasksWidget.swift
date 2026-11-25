import SwiftUI
import SwiftData
import WidgetKit

@main
struct TodoWidgetBundle: WidgetBundle {
    var body: some Widget {
        TasksWidget()
        FocusLiveActivity()
    }
}

struct TasksWidget: Widget {
    let kind = "TasksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TasksProvider()) { entry in
            TasksWidgetView(entry: entry)
                .fontDesign(.rounded)
                .containerBackground(Theme.paper, for: .widget)
                .widgetURL(AppLink.focus)
        }
        .configurationDisplayName("Up Next")
        .description("Your one next step, right on your lock screen.")
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

/// What the widget shows: the next task, and its current step if it has one.
struct NextSnapshot {
    let taskID: UUID
    let taskTitle: String
    let stepID: UUID?
    let stepTitle: String?
    let stepNumber: Int
    let stepCount: Int

    /// The thing to do right now: the step if there is one, else the task.
    var headline: String { stepTitle ?? taskTitle }
}

struct TasksEntry: TimelineEntry {
    let date: Date
    let mode: TaskMode
    let next: NextSnapshot?
    let remaining: Int
    let doneToday: Int

    static let sample = TasksEntry(
        date: .now,
        mode: .personal,
        next: NextSnapshot(
            taskID: UUID(),
            taskTitle: "Clean the kitchen",
            stepID: UUID(),
            stepTitle: "Put 5 things in the dishwasher",
            stepNumber: 1,
            stepCount: 4
        ),
        remaining: 3,
        doneToday: 2
    )
}

struct TasksProvider: TimelineProvider {
    func placeholder(in context: Context) -> TasksEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (TasksEntry) -> Void) {
        completion(context.isPreview ? .sample : loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TasksEntry>) -> Void) {
        let entry = loadEntry()
        // Refresh at least every 30 minutes, and right after midnight so "done today" resets.
        let midnight = Calendar.current.startOfDay(for: Date.now.addingTimeInterval(86_400))
        let refresh = min(Date.now.addingTimeInterval(30 * 60), midnight)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func loadEntry() -> TasksEntry {
        let mode = ModeStore.current
        let raw = mode.rawValue
        let context = ModelContext(SharedStore.container)
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.modeRaw == raw && !$0.isThought }
        )
        let items = (try? context.fetch(descriptor)) ?? []
        let open = FocusEngine.openTasks(items)

        let next = open.first.map { task in
            NextSnapshot(
                taskID: task.id,
                taskTitle: task.title,
                stepID: task.currentStep?.id,
                stepTitle: task.currentStep?.title,
                stepNumber: task.currentStepNumber ?? 0,
                stepCount: task.stepCount
            )
        }

        return TasksEntry(
            date: .now,
            mode: mode,
            next: next,
            remaining: open.count,
            doneToday: items.filter(\.completedToday).count
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
            if let next = entry.next {
                Label(next.headline, systemImage: "circle")
            } else {
                Label("All clear", systemImage: "sparkles")
            }

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                if let next = entry.next, next.stepCount > 0 {
                    Gauge(value: Double(max(next.stepNumber - 1, 0)), in: 0...Double(next.stepCount)) {
                        Image(systemName: entry.mode.symbol)
                    } currentValueLabel: {
                        Text("\(next.stepNumber)/\(next.stepCount)")
                    }
                    .gaugeStyle(.accessoryCircularCapacity)
                } else {
                    VStack(spacing: 0) {
                        Image(systemName: entry.next == nil ? "sparkles" : entry.mode.symbol)
                            .font(.caption2)
                        Text("\(entry.remaining)")
                            .font(.title3.bold())
                    }
                }
            }

        case .accessoryRectangular:
            RectangularView(entry: entry)

        default:
            HomeScreenView(entry: entry, isMedium: family == .systemMedium)
        }
    }
}

/// Lock screen: one next thing, check it off right there.
struct RectangularView: View {
    let entry: TasksEntry

    var body: some View {
        if let next = entry.next {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    Image(systemName: entry.mode.symbol)
                    if next.stepTitle != nil {
                        Text("\(next.taskTitle) · \(next.stepNumber)/\(next.stepCount)")
                    } else {
                        Text("Up next")
                    }
                }
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(.secondary)

                // Only the circle checks it off; tapping anywhere else opens the app.
                HStack(alignment: .center, spacing: 2) {
                    Button(intent: ToggleTaskIntent(taskID: next.taskID, stepID: next.stepID)) {
                        Image(systemName: "circle")
                            .font(.headline)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Check off \(next.headline)"))
                    Text(next.headline)
                        .font(.headline)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 1) {
                Label("All clear", systemImage: "sparkles")
                    .font(.headline)
                if entry.doneToday > 0 {
                    Text("\(entry.doneToday) done today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Home screen: bigger version of the same idea.
struct HomeScreenView: View {
    let entry: TasksEntry
    let isMedium: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label { Text(entry.mode.title) } icon: { Image(systemName: entry.mode.symbol) }
                Spacer()
                if entry.doneToday > 0 {
                    Label("\(entry.doneToday)", systemImage: "checkmark.circle.fill")
                }
            }
            .font(.caption.bold())
            .foregroundStyle(Theme.inkSoft)

            Spacer(minLength: 0)

            if let next = entry.next {
                if next.stepTitle != nil {
                    Text("\(next.taskTitle) · \(next.stepNumber)/\(next.stepCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(next.headline)
                    .font(isMedium ? .title3.weight(.heavy) : .headline.weight(.heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(3)

                Spacer(minLength: 0)

                HStack {
                    Button(intent: ToggleTaskIntent(taskID: next.taskID, stepID: next.stepID)) {
                        Label("Done", systemImage: "checkmark.circle")
                            .font(.subheadline.bold())
                    }
                    .tint(Theme.accent)
                    Spacer()
                    if entry.remaining > 1 {
                        Text("+\(entry.remaining - 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Label("All clear", systemImage: "sparkles")
                    .font(.headline)
                Text("Go do something fun.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
