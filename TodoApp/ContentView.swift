import SwiftUI
import SwiftData
import WidgetKit

struct ContentView: View {
    @AppStorage(ModeStore.key, store: AppGroup.defaults) private var modeRaw = TaskMode.personal.rawValue
    @State private var showFocus = false

    private var mode: TaskMode { TaskMode(rawValue: modeRaw) ?? .personal }

    var body: some View {
        NavigationStack {
            TaskListView(mode: mode, showFocus: $showFocus)
                .navigationTitle(Text(mode.title))
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Picker("Mode", selection: $modeRaw) {
                            ForEach(TaskMode.allCases) { mode in
                                Label { Text(mode.title) } icon: { Image(systemName: mode.symbol) }
                                    .tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }
                }
        }
        .fullScreenCover(isPresented: $showFocus) {
            FocusView(mode: mode)
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
    @Binding var showFocus: Bool

    @State private var newTitle = ""
    @State private var newIsThought = false
    @State private var showDone = true
    @State private var selected: TaskItem?

    init(mode: TaskMode, showFocus: Binding<Bool>) {
        self.mode = mode
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
            if let next = openTasks.first {
                Section {
                    UpNextCard(task: next) { showFocus = true }
                }
            }

            Section("Tasks") {
                if openTasks.isEmpty {
                    Text("Nothing to do. Nice!")
                        .foregroundStyle(.secondary)
                }
                ForEach(openTasks) { task in
                    TaskRow(task: task, onChange: save, onOpen: { selected = task })
                        .swipeActions { deleteButton(task) }
                        .swipeActions(edge: .leading) {
                            Button {
                                task.isPinned.toggle()
                                save()
                            } label: {
                                Label(task.isPinned ? "Unpin" : "Pin", systemImage: task.isPinned ? "pin.slash" : "pin")
                            }
                            .tint(.orange)
                        }
                }
            }

            if !thoughts.isEmpty {
                Section("Thoughts") {
                    ForEach(thoughts) { thought in
                        TaskRow(task: thought, onChange: save, onOpen: { selected = thought })
                            .swipeActions { deleteButton(thought) }
                            .swipeActions(edge: .leading) {
                                Button {
                                    thought.isThought = false
                                    thought.sortOrder = Date.now.timeIntervalSince1970
                                    save()
                                } label: {
                                    Label("Make task", systemImage: "checklist")
                                }
                                .tint(.accentColor)
                            }
                    }
                }
            }

            if !doneToday.isEmpty {
                Section(isExpanded: $showDone) {
                    ForEach(doneToday) { task in
                        TaskRow(task: task, onChange: save, onOpen: { selected = task })
                            .swipeActions { deleteButton(task) }
                    }
                } header: {
                    Text("Done today (\(doneToday.count))")
                }
            }
        }
        .listStyle(.sidebar)
        .animation(.default, value: items.map(\.isDone))
        .sensoryFeedback(trigger: doneToday.count) { old, new in
            new > old ? .success : nil
        }
        .safeAreaInset(edge: .bottom) {
            QuickAddBar(text: $newTitle, isThought: $newIsThought, onSubmit: add)
        }
        .sheet(item: $selected) { task in
            TaskDetailView(task: task)
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
        Button(action: onFocus) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Up next")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(task.currentStep?.title ?? task.title)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    if task.currentStep != nil {
                        Text(task.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Label("Focus", systemImage: "scope")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(Color.white)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
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
                    .foregroundStyle(.yellow)
            } else {
                Button {
                    withAnimation(.spring) { task.toggleDone() }
                    onChange()
                } label: {
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(task.isDone ? Color.accentColor : Color.secondary)
                        .symbolEffect(.bounce, value: task.isDone)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(task.isDone ? Text("Mark as not done") : Text("Mark as done"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? Color.secondary : Color.primary)
                if task.stepCount > 0 && !task.isDone {
                    Text("\(task.doneStepCount)/\(task.stepCount) steps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            if task.isPinned && !task.isDone {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}

struct QuickAddBar: View {
    @Binding var text: String
    @Binding var isThought: Bool
    let onSubmit: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button {
                isThought.toggle()
            } label: {
                Image(systemName: isThought ? "lightbulb.fill" : "checklist")
                    .font(.title3)
                    .foregroundStyle(isThought ? Color.yellow : Color.accentColor)
                    .frame(width: 32)
            }
            .accessibilityLabel(isThought ? Text("Adding a thought") : Text("Adding a task"))

            TextField(isThought ? "New thought…" : "New task…", text: $text)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit {
                    onSubmit()
                    focused = true
                }

            if !text.isEmpty {
                Button(action: onSubmit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .accessibilityLabel(Text("Add"))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [TaskItem.self, TaskStep.self], inMemory: true)
}
