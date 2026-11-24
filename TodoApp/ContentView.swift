import SwiftUI
import SwiftData
import WidgetKit
import Combine

struct ContentView: View {
    @Environment(ProStore.self) private var pro
    @AppStorage(ModeStore.key, store: AppGroup.defaults) private var modeRaw = TaskMode.personal.rawValue
    @State private var showFocus = false
    @Namespace private var focusZoom
    @AppStorage(OnboardingStore.doneKey, store: AppGroup.defaults) private var onboardingDone = false

    private var mode: TaskMode { TaskMode(rawValue: modeRaw) ?? .personal }

    var body: some View {
        NavigationStack {
            TaskListView(mode: mode, modeRaw: $modeRaw, showFocus: $showFocus, focusZoom: focusZoom)
                .navigationTitle(Text(mode.title))
        }
        .fullScreenCover(isPresented: Binding(
            get: { !onboardingDone },
            set: { if !$0 { onboardingDone = true } }
        )) {
            OnboardingView(mode: mode) { openFocus in
                onboardingDone = true
                if openFocus {
                    // Let the onboarding cover close before focus mode opens.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showFocus = true }
                }
            }
            .tint(Theme.accent)
            .fontDesign(.rounded)
        }
        .tint(Theme.accent)
        .fontDesign(.rounded)
        .fullScreenCover(isPresented: $showFocus) {
            FocusView(mode: mode)
                .environment(pro)
                .focusZoomTransition(focusZoom)
                .tint(Theme.accent)
                .fontDesign(.rounded)
        }
        .onChange(of: modeRaw) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onOpenURL { url in
            if url.scheme == AppLink.scheme, url.host == "focus" {
                showFocus = true
            }
        }
    }
}

struct TaskListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ProStore.self) private var pro
    @Environment(SharingStore.self) private var sharing
    @Query private var items: [TaskItem]

    let mode: TaskMode
    @Binding var modeRaw: String
    @Binding var showFocus: Bool
    let focusZoom: Namespace.ID

    @State private var newTitle = ""
    @State private var newIsThought = false
    @State private var selected: TaskItem?

    // No-shame rollover
    @AppStorage(NewDayStore.acknowledgedKey, store: AppGroup.defaults) private var acknowledgedDay = ""
    @AppStorage(NewDayStore.laterExpandedKey, store: AppGroup.defaults) private var laterExpanded = false
    @State private var today = Calendar.current.startOfDay(for: .now)
    @State private var showCarryOver = false
    @State private var confirmFreshStart = false
    @State private var showSettings = false

    // v1.1 Sharing
    @State private var showShareStart = false
    @State private var showSharedSpace = false

    init(mode: TaskMode, modeRaw: Binding<String>, showFocus: Binding<Bool>, focusZoom: Namespace.ID) {
        self.mode = mode
        self.focusZoom = focusZoom
        self._modeRaw = modeRaw
        self._showFocus = showFocus
        let raw = mode.rawValue
        _items = Query(
            filter: #Predicate<TaskItem> { $0.modeRaw == raw },
            sort: [SortDescriptor(\TaskItem.sortOrder)]
        )
    }

    private var openTasks: [TaskItem] { FocusEngine.openTasks(items) }
    private var thoughts: [TaskItem] { items.filter { $0.isThought } }
    private var laterTasks: [TaskItem] { FocusEngine.laterTasks(items) }
    private var doneToday: [TaskItem] {
        items.filter { !$0.isThought && $0.isDone && ($0.completedAt ?? .distantPast) >= today }
    }

    /// Open tasks added before today: they came along from an earlier day.
    private var carriedOver: [TaskItem] { openTasks.filter { $0.createdAt < today } }

    private var doneYesterday: Int {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        return items.filter {
            guard !$0.isThought, $0.isDone, let done = $0.completedAt else { return false }
            return done >= yesterday && done < today
        }.count
    }

    private var showNewDay: Bool {
        acknowledgedDay != NewDayStore.dayKey(today) && !carriedOver.isEmpty
    }

    var body: some View {
        List {
            Section {
                Picker("Mode", selection: $modeRaw) {
                    ForEach(TaskMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if sharing.isEnabled {
                let incoming = sharing.incoming()
                if let reminder = incoming.first {
                    Section {
                        IncomingReminderCard(reminder: reminder, moreCount: incoming.count - 1)
                            .id(reminder.id)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                if let toast = sharing.toast {
                    Section {
                        SharingToastRow(toast: toast)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .transition(.opacity)
                    }
                }
            }

            if showNewDay {
                Section {
                    NewDayCard(
                        carriedOver: carriedOver.count,
                        doneYesterday: doneYesterday,
                        onKeep: acknowledgeNewDay,
                        onChoose: { showCarryOver = true }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            if let next = openTasks.first {
                Section {
                    UpNextCard(task: next) { showFocus = true }
                        .focusZoomSource(focusZoom)
                        .onTapGesture { selected = next }
                        .contextMenu {
                            Button {
                                withAnimation { next.toggleDone() }
                                save()
                            } label: {
                                Label("Done", systemImage: "checkmark.circle")
                            }
                            Button {
                                withAnimation { next.moveToLater() }
                                save()
                            } label: {
                                Label("Later", systemImage: "moon.zzz")
                            }
                            Button(role: .destructive) {
                                context.delete(next)
                                save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            if openTasks.isEmpty || openTasks.count > 1 {
            Section {
                if openTasks.isEmpty {
                    Text(items.isEmpty ? "Nothing here yet. What's on your mind?" : "Nothing left to do. Nice!")
                        .foregroundStyle(Theme.inkSoft)
                        .listRowBackground(Theme.paper)
                }
                // The first one is already in the Up next card.
                ForEach(openTasks.dropFirst()) { task in
                    TaskRow(task: task, onChange: save, onOpen: { selected = task })
                        .listRowBackground(Theme.paper)
                        .listRowSeparatorTint(Theme.separator)
                        .swipeActions {
                            // First action = full swipe, so a long swipe parks instead of deleting.
                            Button {
                                withAnimation { task.moveToLater() }
                                save()
                            } label: {
                                Label("Later", systemImage: "moon.zzz")
                            }
                            .tint(Theme.accent)
                            deleteButton(task)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                task.isPinned.toggle()
                                save()
                            } label: {
                                if task.isPinned {
                                    Label("Unpin", systemImage: "pin.slash")
                                } else {
                                    Label("Pin", systemImage: "pin")
                                }
                            }
                            .tint(Theme.pin)
                        }
                }
            } header: {
                SectionLabel(openTasks.isEmpty ? "Tasks" : "After that")
            }
            }

            if !thoughts.isEmpty {
                Section {
                    ForEach(thoughts) { thought in
                        TaskRow(task: thought, onChange: save, onOpen: { selected = thought })
                            .listRowBackground(Theme.peach)
                            .listRowSeparatorTint(Theme.peachInk.opacity(0.2))
                            .swipeActions(allowsFullSwipe: false) { deleteButton(thought) }
                            .swipeActions(edge: .leading) {
                                Button {
                                    thought.isThought = false
                                    thought.sortOrder = Date.now.timeIntervalSince1970
                                    save()
                                } label: {
                                    Label("Make task", systemImage: "checklist")
                                }
                                .tint(Theme.accent)
                            }
                    }
                } header: {
                    SectionLabel("Thoughts")
                }
            }

            if !laterTasks.isEmpty {
                Section {
                    if laterExpanded {
                        ForEach(laterTasks) { task in
                            TaskRow(task: task, onChange: save, onOpen: { selected = task })
                                .listRowBackground(Theme.paper)
                                .listRowSeparatorTint(Theme.separator)
                                // A long swipe must never delete: only the explicit button does.
                                .swipeActions(allowsFullSwipe: false) { deleteButton(task) }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        withAnimation { task.bringBack() }
                                        save()
                                    } label: {
                                        Label("Bring back", systemImage: "arrow.uturn.up")
                                    }
                                    .tint(Theme.accent)
                                }
                        }
                    }
                } header: {
                    Button {
                        withAnimation { laterExpanded.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            SectionLabel(verbatim: Text("Later · \(laterTasks.count)"))
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(Theme.inkSoft)
                                .rotationEffect(.degrees(laterExpanded ? 90 : 0))
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(laterExpanded ? Text("Hides parked tasks") : Text("Shows parked tasks"))
                } footer: {
                    if laterExpanded {
                        Text("Out of sight, on purpose. Swipe right to bring one back.")
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }

            if !doneToday.isEmpty {
                Section {
                    ForEach(doneToday) { task in
                        TaskRow(task: task, onChange: save, onOpen: { selected = task })
                            .listRowBackground(Theme.paper)
                            .listRowSeparatorTint(Theme.separator)
                            .swipeActions(allowsFullSwipe: false) { deleteButton(task) }
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                } header: {
                    HStack(spacing: 10) {
                        SectionLabel(verbatim: Text("Done today · \(doneToday.count)"))
                        DoneDots(count: doneToday.count)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(14)
        .scrollContentBackground(.hidden)
        .background(Theme.fog)
        .foregroundStyle(Theme.ink)
        .animation(.default, value: items.map(\.isDone))
        .animation(.default, value: showNewDay)
        .sensoryFeedback(trigger: doneToday.count) { old, new in
            new > old ? .success : nil
        }
        .safeAreaInset(edge: .bottom) {
            QuickAddBar(text: $newTitle, isThought: $newIsThought, onSubmit: add)
        }
        .sheet(item: $selected) { task in
            TaskDetailView(task: task)
                .environment(sharing)
                .tint(Theme.accent)
                .fontDesign(.rounded)
        }
        .sheet(isPresented: $showCarryOver) {
            CarryOverSheet(tasks: carriedOver) { parked in
                withAnimation {
                    parked.forEach { $0.moveToLater() }
                    acknowledgeNewDay()
                }
                save()
            }
            .tint(Theme.accent)
            .fontDesign(.rounded)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(pro)
                .environment(sharing)
                .tint(Theme.accent)
                .fontDesign(.rounded)
        }
        .sheet(isPresented: $showShareStart) {
            ShareStartView {
                // Let the start sheet close before the space opens.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showSharedSpace = true }
            }
            .environment(sharing)
            .tint(Theme.accent)
            .fontDesign(.rounded)
        }
        .sheet(isPresented: $showSharedSpace) {
            SharedSpaceView()
                .environment(sharing)
                .tint(Theme.accent)
                .fontDesign(.rounded)
        }
        .toolbar {
            if sharing.isEnabled {
                ToolbarItem(placement: .topBarTrailing) {
                    SharedHeaderButton {
                        if sharing.hasSpace { showSharedSpace = true } else { showShareStart = true }
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        confirmFreshStart = true
                    } label: {
                        Label("Fresh start", systemImage: "leaf")
                    }
                    .disabled(openTasks.isEmpty)

                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel(Text("More"))
                }
            }
        }
        .confirmationDialog(
            Text("Fresh start?"),
            isPresented: $confirmFreshStart,
            titleVisibility: .visible
        ) {
            Button("Park everything in Later") { freshStart() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All ^[\(openTasks.count) open task](inflect: true) move to Later. Nothing is deleted, and you can bring them back anytime.")
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                refreshToday()
                Task { await sharing.refresh() }
            }
        }
        .modifier(ShareInviteCover {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showSharedSpace = true }
        })
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
            refreshToday()
        }
    }

    // MARK: Rollover

    private func refreshToday() {
        let start = Calendar.current.startOfDay(for: .now)
        if start != today { today = start }
    }

    private func acknowledgeNewDay() {
        acknowledgedDay = NewDayStore.dayKey(today)
    }

    /// Parks every open task in Later. A clean slate, without losing anything.
    private func freshStart() {
        withAnimation {
            openTasks.forEach { $0.moveToLater() }
            acknowledgeNewDay()
        }
        save()
    }

    private func deleteButton(_ task: TaskItem) -> some View {
        Button(role: .destructive) {
            context.delete(task)
            save()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func add() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        context.insert(TaskItem(title: title, mode: mode, isThought: newIsThought))
        newTitle = ""
        save()
    }

    private func save() {
        context.saveAndRefresh()
    }
}

struct UpNextCard: View {
    let task: TaskItem
    let onFocus: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                EyebrowText("Up next")
                Text(task.currentStep?.title ?? task.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.ink)
                if let number = task.currentStepNumber {
                    Text("\(task.title) · step \(number) of \(task.stepCount)")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onFocus) {
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
}

/// A small row of dots that fills up through the day. Progress, not pressure.
struct DoneDots: View {
    let count: Int
    private let shown = 8

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<min(count, shown), id: \.self) { _ in
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 7, height: 7)
                    .transition(.scale.combined(with: .opacity))
            }
            if count > shown {
                Text("+\(count - shown)")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.5), value: count)
        .accessibilityHidden(true)
    }
}

extension View {
    /// The Up next card grows into focus mode (iOS 18+). Older systems use the normal slide.
    @ViewBuilder
    func focusZoomSource(_ namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: "focus", in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func focusZoomTransition(_ namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: "focus", in: namespace))
        } else {
            self
        }
    }
}

struct TaskRow: View {
    let task: TaskItem
    let onChange: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if task.isThought {
                Image(systemName: "lightbulb")
                    .font(.title3)
                    .foregroundStyle(Theme.peachInk)
                    .frame(width: 26)
            } else {
                Button {
                    withAnimation(.spring) { task.toggleDone() }
                    onChange()
                } label: {
                    CheckCircle(isDone: task.isDone)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(task.isDone ? Text("Mark as not done") : Text("Mark as done"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body.weight(task.isDone ? .regular : .semibold))
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? Theme.inkSoft : (task.isThought ? Theme.thoughtInk : Theme.ink))
                if task.stepCount > 0 && !task.isDone {
                    Text("\(task.doneStepCount) of \(task.stepCount) steps")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            if task.isPinned && !task.isDone {
                Image(systemName: "pin.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.pin)
                    .accessibilityLabel(Text("Pinned"))
            }
        }
        .padding(.vertical, 3)
    }
}

struct QuickAddBar: View {
    @Binding var text: String
    @Binding var isThought: Bool
    let onSubmit: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Button {
                isThought.toggle()
            } label: {
                Image(systemName: isThought ? "lightbulb.fill" : "checklist")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isThought ? Theme.peachInk : Theme.accent)
                    .frame(width: 44, height: 44)
                    .background(isThought ? Theme.peach : Theme.paper,
                                in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isThought ? Text("Adding a thought") : Text("Adding a task"))

            TextField(isThought ? "A thought, no pressure…" : "Get it out of your head…", text: $text)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit {
                    onSubmit()
                    focused = true
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))

            if !text.isEmpty {
                Button(action: onSubmit) {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.bold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(width: 44, height: 44)
                        .background(Theme.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Add"))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.25), value: text.isEmpty)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Theme.fog.opacity(0.95))
        .overlay(alignment: .top) {
            Theme.segment.frame(height: 1)
        }
    }
}

#Preview {
    ContentView()
        .environment(ProStore())
        .environment(SharingStore())
        .modelContainer(for: [TaskItem.self, TaskStep.self], inMemory: true)
}
