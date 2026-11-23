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
        VStack(spacing: 20) {
            header

            Spacer(minLength: 0)

            if let task = next {
                focusContent(task)
            } else {
                allClear
            }

            Spacer(minLength: 0)

            if let task = next {
                timerSection
                actions(task)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.focusGround.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
        .sensoryFeedback(.success, trigger: celebrateTrigger)
        .task { await FocusTimerController.cleanUpIfExpired() }
        .sheet(item: $breakdownTask) { task in
            TaskDetailView(task: task)
                .tint(Theme.accent)
                .fontDesign(.rounded)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Label { Text(mode.title) } icon: { Image(systemName: mode.symbol) }
                .font(.footnote.weight(.bold))
                .foregroundStyle(Theme.inkSoft)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.paper, in: Capsule())

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 44, height: 44)
                    .background(Theme.paper, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Close"))
        }
    }

    // MARK: The one thing

    private func focusContent(_ task: TaskItem) -> some View {
        VStack(spacing: 10) {
            if let step = task.currentStep, let number = task.currentStepNumber {
                EyebrowText(verbatim: Text("Step \(number) of \(task.stepCount)"))
                Text(step.title)
                    .font(.largeTitle.weight(.heavy))
                    .multilineTextAlignment(.center)
                Text(task.title)
                    .font(.title3)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                StepDots(total: task.stepCount, done: task.doneStepCount)
                    .padding(.top, 6)
            } else {
                EyebrowText("Just this one thing")
                Text(task.title)
                    .font(.largeTitle.weight(.heavy))
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
        VStack(spacing: 12) {
            Button {
                complete(task)
            } label: {
                Label(task.currentStep == nil ? "Done" : "Step done", systemImage: "checkmark")
                    .font(.title3.weight(.heavy))
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.primaryButton, style: .continuous))
                    .foregroundStyle(Theme.onAccent)
                    .shadow(color: Theme.accent.opacity(0.25), radius: 10, y: 8)
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                SoftButton(title: "Not now") { skip(task) }
                SoftButton(title: "Break it down") { breakdownTask = task }
            }

            if remaining > 1 {
                Text("\(remaining - 1) more waiting. Not your problem right now.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
    }

    private var allClear: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(Theme.peachInk)
            Text("All clear")
                .font(.largeTitle.weight(.heavy))
            Text("Nothing left here. Go do something fun.")
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            SoftButton(title: "Close") { dismiss() }
                .frame(width: 160)
                .padding(.top)
        }
    }

    // MARK: Timer

    @ViewBuilder
    private var timerSection: some View {
        if let timer {
            VStack(spacing: 12) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let total = max(timer.end.timeIntervalSince(timer.start), 1)
                    let left = max(timer.end.timeIntervalSince(context.date), 0)
                    TimerRing(fraction: left / total, secondsLeft: left, totalMinutes: Int(total / 60))
                }
                HStack(spacing: 12) {
                    Button {
                        Task { await FocusTimerController.extend(minutes: 5) }
                    } label: {
                        Text("+5 min")
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .background(Theme.paper, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await FocusTimerController.stop() }
                    } label: {
                        Text("Stop timer")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.inkSoft)
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            VStack(spacing: 8) {
                Text("Make time visible")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
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
                .font(.subheadline.weight(.bold))
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Theme.paper, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions

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

/// White, rounded secondary button.
struct SoftButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                .foregroundStyle(Theme.ink)
        }
        .buttonStyle(.plain)
    }
}

/// Progress through a task's steps: done, current, and upcoming.
struct StepDots: View {
    let total: Int
    let done: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(total, 0), id: \.self) { index in
                Capsule()
                    .fill(index < done ? Theme.accent : (index == done ? Theme.accent.opacity(0.45) : Theme.track))
                    .frame(width: 28, height: 6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("\(done) of \(total) steps done"))
    }
}

/// A ring that empties as time runs out. Seeing time pass helps with time blindness.
struct TimerRing: View {
    let fraction: Double
    let secondsLeft: TimeInterval
    let totalMinutes: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.paper)
            Circle()
                .stroke(Theme.track, lineWidth: 12)
                .padding(6)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(6)
                .animation(.linear(duration: 1), value: fraction)
            if secondsLeft > 0 {
                VStack(spacing: 2) {
                    Text(Duration.seconds(secondsLeft).formatted(.time(pattern: .minuteSecond)))
                        .font(.largeTitle.weight(.heavy).monospacedDigit())
                        .contentTransition(.numericText(countsDown: true))
                    Text("of \(totalMinutes) min")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }
            } else {
                VStack(spacing: 2) {
                    Text("Time's up")
                        .font(.headline)
                    Text("Done, or 5 more?")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .frame(width: 168, height: 168)
        .accessibilityElement(children: .combine)
    }
}
