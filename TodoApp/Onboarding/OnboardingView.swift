import SwiftUI
import SwiftData
import WidgetKit

enum OnboardingStore {
    static let doneKey = "onboardingDone"
}

/// First launch: empty your head, pick one thing, put it on the lock screen. About a minute.
/// Skippable at every step. Mockups: OnbWelcome … OnbReadyEmpty on the design canvas.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    let mode: TaskMode
    /// Called when onboarding ends. `true` means "open focus mode now".
    let onFinish: (_ openFocus: Bool) -> Void

    private enum Step: Int, Comparable {
        case welcome, dump, pick, widget, ready
        static func < (a: Step, b: Step) -> Bool { a.rawValue < b.rawValue }
    }

    @State private var step: Step = .welcome
    @State private var added: [TaskItem] = []
    @State private var text = ""
    @State private var isThought = false
    @State private var pickedID: UUID?
    @State private var widgetFound = false
    @FocusState private var fieldFocused: Bool

    private var addedTasks: [TaskItem] { added.filter { !$0.isThought } }
    private var picked: TaskItem? { addedTasks.first { $0.id == pickedID } ?? addedTasks.first }

    var body: some View {
        ZStack {
            Theme.focusGround.ignoresSafeArea()
            Group {
                switch step {
                case .welcome: welcome
                case .dump: dump
                case .pick: pick
                case .widget: widget
                case .ready: ready
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
        .foregroundStyle(Theme.ink)
        .animation(.spring(duration: 0.4), value: step)
        .sensoryFeedback(.selection, trigger: step)
        .onChange(of: scenePhase) {
            // Coming back from the lock screen editor: did they add the widget?
            if scenePhase == .active && step == .widget { checkWidget() }
        }
    }

    // MARK: - 1 · Welcome

    private var welcome: some View {
        VStack(spacing: 24) {
            HStack { Spacer(); skipButton }

            Spacer(minLength: 0)
            LockScreenPreview(title: "Put 5 things in the dishwasher", subtitle: "Clean the kitchen · 1/4")
            Spacer(minLength: 0)

            VStack(spacing: 10) {
                EyebrowText("Built for ADHD brains")
                Text("Out of sight,\nout of mind?")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("Same. So we put your next step where you look 100 times a day: your lock screen.")
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                PrimaryButton(title: "Let's set it up") { go(.dump) }
                Text("Takes about a minute.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    // MARK: - 2 · Brain dump

    private var dump: some View {
        VStack(alignment: .leading, spacing: 20) {
            header(step: 1, back: .welcome)

            VStack(alignment: .leading, spacing: 8) {
                Text("What's buzzing in your head?")
                    .font(.title3.weight(.bold))
                Text("Dump a few things. Big, small, messy. You can sort it later, or never.")
                    .foregroundStyle(Theme.inkSoft)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(added) { item in
                        DumpRow(item: item) { remove(item) }
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: added.isEmpty ? 0 : 260)

            HStack(spacing: 10) {
                Button {
                    isThought.toggle()
                } label: {
                    Image(systemName: isThought ? "lightbulb.fill" : "checklist")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isThought ? Theme.peachInk : Theme.accent)
                        .frame(width: 48, height: 48)
                        .background(isThought ? Theme.peach : Theme.paper,
                                    in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isThought ? Text("Adding a thought") : Text("Adding a task"))

                TextField(isThought ? "A thought, no pressure…" : "Get it out of your head…", text: $text)
                    .focused($fieldFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        add(text)
                        fieldFocused = true
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            }

            if added.count < 6 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Stuck? Tap one")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.inkSoft)
                    FlowChips(titles: suggestions) { add($0) }
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                if !added.isEmpty {
                    Text("^[\(added.count) thing](inflect: true) out of your head. Lighter already.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                        .frame(maxWidth: .infinity)
                }
                PrimaryButton(title: "Next") {
                    fieldFocused = false
                    if !text.trimmingCharacters(in: .whitespaces).isEmpty { add(text) }
                    // Nothing to choose between? Skip the pick step.
                    if addedTasks.count > 1 {
                        go(.pick)
                    } else {
                        pin(addedTasks.first)
                        go(.widget)
                    }
                }
                .disabled(added.isEmpty && text.isEmpty)
                .opacity(added.isEmpty && text.isEmpty ? 0.5 : 1)
            }
        }
        .onAppear { fieldFocused = added.isEmpty }
    }

    private var suggestions: [String] {
        let all = [
            String(localized: "Laundry"),
            String(localized: "Pay a bill"),
            String(localized: "Reply to that email"),
            String(localized: "Groceries"),
        ]
        let titles = Set(added.map(\.title))
        return all.filter { !titles.contains($0) }
    }

    // MARK: - 3 · Pick the one

    private var pick: some View {
        VStack(alignment: .leading, spacing: 20) {
            header(step: 2, back: .dump)

            VStack(alignment: .leading, spacing: 8) {
                Text("Which one first?")
                    .font(.title3.weight(.bold))
                Text("Just one. The rest will wait quietly until it's their turn.")
                    .foregroundStyle(Theme.inkSoft)
            }

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(addedTasks) { task in
                        PickRow(title: task.title, isSelected: task.id == picked?.id) {
                            pickedID = task.id
                        }
                    }
                    if let thought = added.first(where: \.isThought) {
                        Text("Your thought \u{201C}\(thought.title)\u{201D} stays in Thoughts. No pressure.")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                }
            }
            .scrollIndicators(.hidden)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "list.bullet.indent")
                    .foregroundStyle(Theme.gotIt)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Feels too big?")
                        .font(.body.weight(.bold))
                    Text("Break it into tiny steps later. \u{201C}Clean the kitchen\u{201D} becomes \u{201C}Put 5 things in the dishwasher\u{201D}.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.sage, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))

            PrimaryButton(title: "Make it my next step") {
                pin(picked)
                go(.widget)
            }
        }
    }

    // MARK: - 4 · Lock screen widget

    private var widget: some View {
        VStack(alignment: .leading, spacing: 18) {
            header(step: 3, back: addedTasks.count > 1 ? .pick : .dump)

            VStack(alignment: .leading, spacing: 6) {
                Text(widgetFound ? "Found it" : "Put it where you'll see it")
                    .font(.title3.weight(.bold))
                Text(widgetFound
                     ? "Your next step is on your lock screen now. Check it off right there, no need to open the app."
                     : "Add the widget to your lock screen. You can check things off right there.")
                    .foregroundStyle(Theme.inkSoft)
            }

            LockScreenPreview(title: picked?.title ?? String(localized: "Your next step"),
                              subtitle: String(localized: "Up next"),
                              compact: true,
                              dashed: !widgetFound)

            if widgetFound {
                HStack(spacing: 14) {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.bold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(width: 44, height: 44)
                        .background(Theme.accent, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Widget is on")
                            .font(.body.weight(.bold))
                        Text("If it ever goes missing, you'll find this guide in Settings.")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.sage, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            } else {
                WidgetSteps()
            }

            Spacer(minLength: 0)

            if widgetFound {
                PrimaryButton(title: "Next") { go(.ready) }
            } else {
                VStack(spacing: 6) {
                    PrimaryButton(title: "It's on my lock screen") {
                        checkWidget()
                        go(.ready)
                    }
                    Button("I'll do it later") { go(.ready) }
                        .font(.body.weight(.bold))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(height: 44)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .animation(.spring(duration: 0.4), value: widgetFound)
        .onAppear(perform: checkWidget)
    }

    // MARK: - 5 · Ready

    private var ready: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 52))
                    .foregroundStyle(Theme.peachInk)
                Text("You're set")
                    .font(.largeTitle.weight(.bold))
                Text(picked == nil
                     ? "Whenever something pops into your head, drop it here. We'll keep it to one thing at a time."
                     : "One thing at a time. That's the whole trick.")
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)

            if let picked {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        EyebrowText("Up next")
                        Text(picked.title)
                            .font(.title3.weight(.bold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        finish(openFocus: true)
                    } label: {
                        Label("Focus", systemImage: "scope")
                            .font(.body.weight(.bold))
                            .padding(.horizontal, 18)
                            .frame(height: 44)
                            .background(Theme.accent, in: Capsule())
                            .foregroundStyle(Theme.onAccent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .shadow(color: Theme.ink.opacity(0.06), radius: 12, y: 6)
            }

            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("Good to know")
                VStack(spacing: 0) {
                    TipRow(symbol: "moon.zzz", tint: Theme.accent,
                           text: "Swipe left on a task to **park it in Later**. Out of sight, on purpose.")
                    Divider().overlay(Theme.separator)
                    TipRow(symbol: "lightbulb", tint: Theme.peachInk,
                           text: "Not a task? Tap the bulb and save it as a **thought**.")
                    Divider().overlay(Theme.separator)
                    TipRow(symbol: "leaf", tint: Theme.gotIt,
                           text: "Rough day? **Fresh start** in the menu clears the deck. Nothing gets deleted.")
                }
                .padding(.horizontal, 16)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            }

            Spacer(minLength: 0)

            PrimaryButton(title: picked == nil ? "Add your first thing" : "Go to my list") {
                finish(openFocus: false)
            }
        }
    }

    // MARK: - Pieces

    private func header(step number: Int, back: Step) -> some View {
        HStack {
            Button {
                go(back)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 44, height: 44)
                    .background(Theme.paper, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Back"))

            Spacer()
            StepDots(total: 3, done: number - 1)
                .accessibilityLabel(Text("Step \(number) of 3"))
            Spacer()

            skipButton
        }
    }

    private var skipButton: some View {
        Button("Skip") { go(.ready) }
            .font(.body.weight(.bold))
            .foregroundStyle(Theme.inkSoft)
            .frame(height: 44)
            .padding(.horizontal, 6)
    }

    // MARK: - Actions

    private func go(_ next: Step) {
        fieldFocused = false
        step = next
    }

    private func add(_ raw: String) {
        let title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let item = TaskItem(title: title, mode: mode, isThought: isThought)
        context.insert(item)
        withAnimation(.spring(duration: 0.3)) { added.append(item) }
        text = ""
        context.saveAndRefresh()
    }

    private func remove(_ item: TaskItem) {
        withAnimation { added.removeAll { $0.id == item.id } }
        if pickedID == item.id { pickedID = nil }
        context.delete(item)
        context.saveAndRefresh()
    }

    /// Pins the chosen task so it's "next" everywhere, widget included.
    private func pin(_ task: TaskItem?) {
        guard let task else { return }
        for other in addedTasks { other.isPinned = other.id == task.id }
        pickedID = task.id
        context.saveAndRefresh()
    }

    private func checkWidget() {
        WidgetCenter.shared.getCurrentConfigurations { result in
            let found = (try? result.get())?.contains { info in
                info.kind == TasksWidgetKind.kind && TasksWidgetKind.lockScreenFamilies.contains(info.family)
            } ?? false
            DispatchQueue.main.async { widgetFound = found }
        }
    }

    private func finish(openFocus: Bool) {
        onFinish(openFocus)
    }
}

/// Shared with the widget extension's `TasksWidget.kind`.
enum TasksWidgetKind {
    static let kind = "TasksWidget"
    static let lockScreenFamilies: [WidgetFamily] = [.accessoryRectangular, .accessoryInline, .accessoryCircular]
}

// MARK: - Components

private struct PrimaryButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.primaryButton, style: .continuous))
                .foregroundStyle(Theme.onAccent)
                .shadow(color: Theme.accent.opacity(0.25), radius: 10, y: 8)
        }
        .buttonStyle(.plain)
    }
}

/// A small picture of a lock screen with the widget on it.
private struct LockScreenPreview: View {
    let title: String
    let subtitle: String
    var compact = false
    var dashed = false

    var body: some View {
        VStack(spacing: 4) {
            if !compact {
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.Live.label)
            }
            Text(Date.now, format: .dateTime.hour().minute())
                .font(.system(size: compact ? 44 : 64, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 3) {
                Text(subtitle)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.Live.label)
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "circle")
                    Text(title).lineLimit(2)
                }
                .font(.body.weight(.bold))
                .foregroundStyle(.white)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(dashed ? 0 : 0.14), in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .overlay {
                if dashed {
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .strokeBorder(Theme.Live.accent, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                }
            }
            .padding(.top, compact ? 8 : 16)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, compact ? 16 : 32)
        .frame(maxWidth: compact ? .infinity : 240)
        .background(
            LinearGradient(colors: Theme.Live.wallpaper, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: compact ? Theme.Radius.card : 40, style: .continuous)
        )
        .shadow(color: Theme.ink.opacity(compact ? 0 : 0.22), radius: 24, y: 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Lock screen preview: \(title)"))
    }
}

struct WidgetSteps: View {
    var body: some View {
        VStack(spacing: 0) {
            row(1, "**Lock your phone**, then touch and hold the lock screen")
            Divider().overlay(Theme.separator)
            row(2, "Tap **Customize**, then **Lock Screen**")
            Divider().overlay(Theme.separator)
            row(3, "Tap the **widget area** under the time")
            Divider().overlay(Theme.separator)
            row(4, "Find **Onestep** and pick the wide **Up Next** widget")
        }
        .padding(.horizontal, 16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private func row(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.body.weight(.bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 28, height: 28)
                .background(Theme.currentRow, in: Circle())
            Text(text)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 11)
    }
}

private struct DumpRow: View {
    let item: TaskItem
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if item.isThought {
                Image(systemName: "lightbulb")
                    .foregroundStyle(Theme.peachInk)
                    .frame(width: 24)
            } else {
                CheckCircle(isDone: false, size: 22)
            }
            Text(item.title)
                .font(.body.weight(.bold))
                .foregroundStyle(item.isThought ? Theme.thoughtInk : Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Remove \(item.title)"))
        }
        .padding(.leading, 16)
        .padding(.vertical, 2)
        .background(item.isThought ? Theme.peach : Theme.paper,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
    }
}

private struct PickRow: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                CheckCircle(isDone: isSelected, isCurrent: isSelected)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(isSelected ? .heavy : .bold))
                    if isSelected {
                        Text("Your next step")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isSelected {
                    Image(systemName: "pin.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.pin)
                }
            }
            .padding(16)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : .clear, lineWidth: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.spring(duration: 0.25), value: isSelected)
    }
}

private struct TipRow: View {
    let symbol: String
    let tint: Color
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 24)
            Text(text)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
    }
}

/// Wrapping row of tappable suggestion chips.
private struct FlowChips: View {
    let titles: [String]
    let onTap: (String) -> Void

    var body: some View {
        ChipLayout(spacing: 8) {
            ForEach(titles, id: \.self) { title in
                Button {
                    onTap(title)
                } label: {
                    Text(title)
                        .font(.body.weight(.bold))
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(Theme.paper, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ChipLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
