import SwiftUI
import SwiftData
import WidgetKit

struct ContentView: View {
    @AppStorage(ModeStore.key, store: AppGroup.defaults) private var modeRaw = TaskMode.personal.rawValue
    @State private var showFocus = false

    private var mode: TaskMode { TaskMode(rawValue: modeRaw) ?? .personal }

    var body: some View {
        NavigationStack {
            TaskListView(mode: mode, modeRaw: $modeRaw, showFocus: $showFocus)
                .navigationTitle(Text(mode.title))
        }
        .tint(Theme.accent)
        .fontDesign(.rounded)
        .fullScreenCover(isPresented: $showFocus) {
            FocusView(mode: mode)
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
    @Query private var items: [TaskItem]

    let mode: TaskMode
    @Binding var modeRaw: String
    @Binding var showFocus: Bool

    @State private var newTitle = ""
    @State private var newIsThought = false
    @State private var selected: TaskItem?

    init(mode: TaskMode, modeRaw: Binding<String>, showFocus: Binding<Bool>) {
        self.mode = mode
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
    private var doneToday: [TaskItem] { items.filter { !$0.isThought && $0.completedToday } }

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

            if let next = openTasks.first {
                Section {
                    UpNextCard(task: next) { showFocus = true }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            Section {
                if openTasks.isEmpty {
                    Text("Nothing to do. Nice!")
                        .foregroundStyle(Theme.inkSoft)
                        .listRowBackground(Theme.paper)
                }
                ForEach(openTasks) { task in
                    TaskRow(task: task, onChange: save, onOpen: { selected = task })
                        .listRowBackground(Theme.paper)
                        .listRowSeparatorTint(Theme.separator)
                        .swipeActions { deleteButton(task) }
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
                SectionLabel("Tasks")
            }

            if !thoughts.isEmpty {
                Section {
                    ForEach(thoughts) { thought in
                        TaskRow(task: thought, onChange: save, onOpen: { selected = thought })
                            .listRowBackground(Theme.peach)
                            .listRowSeparatorTint(Theme.peachInk.opacity(0.2))
                            .swipeActions { deleteButton(thought) }
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

            if !doneToday.isEmpty {
                Section {
                    ForEach(doneToday) { task in
                        TaskRow(task: task, onChange: save, onOpen: { selected = task })
                            .listRowBackground(Theme.paper)
                            .listRowSeparatorTint(Theme.separator)
                            .swipeActions { deleteButton(task) }
                    }
                } header: {
                    SectionLabel(verbatim: Text("Done today · \(doneToday.count)"))
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(14)
        .scrollContentBackground(.hidden)
        .background(Theme.fog)
        .foregroundStyle(Theme.ink)
        .animation(.default, value: items.map(\.isDone))
        .sensoryFeedback(trigger: doneToday.count) { old, new in
            new > old ? .success : nil
        }
        .safeAreaInset(edge: .bottom) {
            QuickAddBar(text: $newTitle, isThought: $newIsThought, onSubmit: add)
        }
        .sheet(item: $selected) { task in
            TaskDetailView(task: task)
                .tint(Theme.accent)
                .fontDesign(.rounded)
        }
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
                    .font(.subheadline.weight(.bold))
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
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            if task.isPinned && !task.isDone {
                Image(systemName: "pin.fill")
                    .font(.caption)
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
        .modelContainer(for: [TaskItem.self, TaskStep.self], inMemory: true)
}
