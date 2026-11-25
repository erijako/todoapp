import SwiftUI
import SwiftData

/// "Just one thing": shows only the next task (or step), big and calm.
struct FocusView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ProStore.self) private var pro
    @Query private var items: [TaskItem]

    let mode: TaskMode

    @AppStorage(FocusTimerStore.key, store: AppGroup.defaults) private var timerData: Data?
    @State private var celebrateTrigger = 0
    @State private var breakdownTask: TaskItem?
    @State private var showPaywall = false

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
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environment(pro)
                .tint(Theme.accent)
        }
    }

    // MARK: Header

    private var header: some View {
        ZStack {
            Text("Focus")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 44, height: 44)
                        .background(Theme.segment, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Close"))

                Spacer()

                Label { Text(mode.title) } icon: { Image(systemName: mode.symbol) }
                    .labelStyle(.iconOnly)
                    .font(.body)
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 44, height: 44)
            }
        }
    }

    // MARK: The one thing

    private func focusContent(_ task: TaskItem) -> some View {
        VStack(spacing: 10) {
            if let step = task.currentStep, let number = task.currentStepNumber {
                Text("\(task.title) · Step \(number) of \(task.stepCount)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                Text(step.title)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                StepDots(total: task.stepCount, done: task.doneStepCount)
                    .padding(.top, 6)
            } else {
                Text("Just this one thing")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                Text(task.title)
                    .font(.title.weight(.bold))
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
            if remaining > 1 {
                Text("\(remaining - 1) more waiting. Not your problem right now.")
                    .font(.body)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }

            // Clock-app style: round Not Now (left) and Done (right).
            HStack(alignment: .center) {
                RoundActionButton(title: "Not now", fill: Theme.track, ink: Theme.ink) { skip(task) }

                Spacer(minLength: 8)

                Button("Break it down") { breakdownTask = task }
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.accent)
                    .frame(minHeight: 44)
                    .multilineTextAlignment(.center)

                Spacer(minLength: 8)

                RoundActionButton(title: "Done", fill: Theme.accent, ink: Theme.onAccent) { complete(task) }
                    .accessibilityLabel(Text(task.currentStep == nil ? "Done" : "Step done"))
            }
            .padding(.horizontal, 4)
        }
    }

    private var allClear: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(Theme.peachInk)
            Text("All clear")
                .font(.largeTitle.weight(.bold))
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
                            .font(.body.weight(.bold))
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .background(Theme.segment, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await FocusTimerController.stop() }
                    } label: {
                        Text("Stop timer")
                            .font(.body.weight(.bold))
                            .foregroundStyle(Theme.inkSoft)
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text("Make time visible")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                    if !pro.isPro {
                        Text("Pro")
                            .font(.footnote.weight(.bold))
                            .textCase(.uppercase)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Theme.peach, in: Capsule())
                            .foregroundStyle(Theme.peachInk)
                    }
                }
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
            guard pro.isPro else {
                showPaywall = true
                return
            }
            Task { await FocusTimerController.start(minutes: minutes, mode: mode) }
        } label: {
            HStack(spacing: 5) {
                if !pro.isPro {
                    Image(systemName: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                        .accessibilityLabel(Text("Pro"))
                }
                label()
            }
                .font(.body.weight(.bold))
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Theme.segment, in: Capsule())
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

/// Big round button with a thin outer ring, like the Clock app's Start / Cancel.
struct RoundActionButton: View {
    let title: LocalizedStringKey
    let fill: Color
    let ink: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(.center)
                .padding(8)
                .frame(width: 84, height: 84)
                .background(fill, in: Circle())
                .padding(3)
                .overlay(Circle().strokeBorder(fill, lineWidth: 2))
                .foregroundStyle(ink)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

/// Secondary button on a card-colored pill.
struct SoftButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Theme.segment, in: Capsule())
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let fraction: Double
    let secondsLeft: TimeInterval
    let totalMinutes: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.track, lineWidth: 9)
                .padding(5)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(5)
                .animation(reduceMotion ? nil : .linear(duration: 1), value: fraction)
            if secondsLeft > 0 {
                VStack(spacing: 2) {
                    Text(Duration.seconds(secondsLeft).formatted(.time(pattern: .minuteSecond)))
                        .font(.system(size: 64, weight: .light).monospacedDigit())
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .contentTransition(.numericText(countsDown: true))
                    Text("of \(totalMinutes) min")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }
            } else {
                VStack(spacing: 2) {
                    Text("Time's up")
                        .font(.body.weight(.bold))
                    Text("Done, or 5 more?")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .frame(width: 240, height: 240)
        .accessibilityElement(children: .combine)
    }
}
