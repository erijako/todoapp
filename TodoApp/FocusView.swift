import SwiftUI
import SwiftData

/// "Just one thing": shows only the next task (or step), big and calm.
struct FocusView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var items: [TaskItem]

    let mode: TaskMode

    @AppStorage(FocusTimerStore.key, store: AppGroup.defaults) private var timerData: Data?
    @State private var celebrateTrigger = 0
    @State private var breakdownTask: TaskItem?

    init(mode: TaskMode) {
        self.mode = mode
        let raw = mode.rawValue
        _items = Query(
            filter: #Predicate<TaskItem> { $0.modeRaw == raw },
            sort: [SortDescriptor(\TaskItem.sortOrder)]
        )
    }

    private var next: TaskItem? { FocusEngine.next(items) }
    private var remaining: Int { FocusEngine.openTasks(items).count }
    private var timer: FocusTimerState? { FocusTimerStore.decode(timerData) }

    var body: some View {
        VStack(spacing: 24) {
            header

            Spacer()

            if let task = next {
                focusContent(task)
            } else {
                allClear
            }

            Spacer()

            if next != nil {
                timerSection
            }

            if let task = next {
                actions(task)
            }
        }
        .padding(24)
        .sensoryFeedback(.success, trigger: celebrateTrigger)
        .task { await FocusTimerController.cleanUpIfExpired() }
        .sheet(item: $breakdownTask) { task in
            TaskDetailView(task: task)
        }
    }

    private var header: some View {
        HStack {
            Label { Text(mode.title) } icon: { Image(systemName: mode.symbol) }
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel(Text("Close"))
        }
    }

    private func focusContent(_ task: TaskItem) -> some View {
        VStack(spacing: 12) {
            if let step = task.currentStep, let number = task.currentStepNumber {
                Text("Step \(number) of \(task.stepCount)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(step.title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text(task.title)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                ProgressView(value: Double(task.doneStepCount), total: Double(max(task.stepCount, 1)))
                    .frame(maxWidth: 200)
                    .padding(.top, 8)
            } else {
                Text("Just this one thing")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(task.title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
            }
        }
        .id(task.currentStep?.id ?? task.id)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    private func actions(_ task: TaskItem) -> some View {
        VStack(spacing: 16) {
            Button {
                complete(task)
            } label: {
                Label(task.currentStep == nil ? "Done" : "Step done", systemImage: "checkmark")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            HStack {
                Button {
                    skip(task)
                } label: {
                    Label("Not now", systemImage: "arrow.uturn.right")
                }
                Spacer()
                Button {
                    breakdownTask = task
                } label: {
                    Label("Break it down", systemImage: "list.bullet.indent")
                }
            }
            .font(.subheadline)

            if remaining > 1 {
                Text("\(remaining - 1) more waiting. Not your problem right now.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: Timer

    @ViewBuilder
    private var timerSection: some View {
        if let timer {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let total = max(timer.end.timeIntervalSince(timer.start), 1)
                let left = max(timer.end.timeIntervalSince(context.date), 0)
                TimerRing(fraction: left / total, secondsLeft: left)
            }
            HStack(spacing: 24) {
                Button {
                    Task { await FocusTimerController.extend(minutes: 5) }
                } label: {
                    Label("5 min", systemImage: "plus")
                }
                Button(role: .destructive) {
                    Task { await FocusTimerController.stop() }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
            }
            .font(.subheadline)
        } else {
            VStack(spacing: 8) {
                Text("Make time visible")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    timerButton(minutes: 2) { Text("2-min start") }
                    timerButton(minutes: 10) { Text("10 min") }
                    timerButton(minutes: 25) { Text("25 min") }
                }
            }
        }
    }

    private func timerButton(minutes: Int, @ViewBuilder label: () -> Text) -> some View {
        Button {
            Task { await FocusTimerController.start(minutes: minutes, mode: mode) }
        } label: {
            label()
                .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.bordered)
    }

    private var allClear: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(.yellow)
            Text("All clear")
                .font(.largeTitle.bold())
            Text("Nothing left here. Go do something fun.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Close") { dismiss() }
                .buttonStyle(.bordered)
                .padding(.top)
        }
    }

    private func complete(_ task: TaskItem) {
        withAnimation(.spring) {
            task.completeNext()
        }
        celebrateTrigger += 1
        context.saveAndRefresh()
        Task { await FocusTimerController.refreshActivity() }
    }

    /// Moves the task to the back of the line. No guilt.
    private func skip(_ task: TaskItem) {
        withAnimation(.spring) {
            task.isPinned = false
            task.sortOrder = Date.now.timeIntervalSince1970
        }
        context.saveAndRefresh()
        Task { await FocusTimerController.refreshActivity() }
    }
}

/// A ring that empties as time runs out. Seeing time pass helps with time blindness.
struct TimerRing: View {
    let fraction: Double
    let secondsLeft: TimeInterval

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.15), lineWidth: 12)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: fraction)
            if secondsLeft > 0 {
                Text(Duration.seconds(secondsLeft).formatted(.time(pattern: .minuteSecond)))
                    .font(.title.monospacedDigit().bold())
                    .contentTransition(.numericText(countsDown: true))
            } else {
                VStack(spacing: 2) {
                    Text("Time's up")
                        .font(.headline)
                    Text("Done, or 5 more?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 150, height: 150)
        .accessibilityElement(children: .combine)
    }
}
