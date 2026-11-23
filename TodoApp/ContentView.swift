import SwiftUI
import SwiftData
import WidgetKit

struct ContentView: View {
    @AppStorage(ModeStore.key, store: AppGroup.defaults) private var modeRaw = TaskMode.personal.rawValue

    private var mode: TaskMode { TaskMode(rawValue: modeRaw) ?? .personal }

    var body: some View {
        NavigationStack {
            TaskListView(mode: mode)
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
        .onChange(of: modeRaw) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

struct TaskListView: View {
    @Environment(\.modelContext) private var context
    @Query private var items: [TaskItem]

    let mode: TaskMode

    @State private var newTitle = ""
    @State private var newIsThought = false
    @State private var showDone = false

    init(mode: TaskMode) {
        self.mode = mode
        let raw = mode.rawValue
        _items = Query(
            filter: #Predicate<TaskItem> { $0.modeRaw == raw },
            sort: [SortDescriptor(\TaskItem.sortOrder)]
        )
    }

    private var openTasks: [TaskItem] { items.filter { !$0.isThought && !$0.isDone } }
    private var thoughts: [TaskItem] { items.filter { $0.isThought } }
    private var doneTasks: [TaskItem] { items.filter { !$0.isThought && $0.isDone } }

    var body: some View {
        List {
            Section("Tasks") {
                if openTasks.isEmpty {
                    Text("Nothing to do. Nice!")
                        .foregroundStyle(.secondary)
                }
                ForEach(openTasks) { task in
                    TaskRow(task: task, onChange: save)
                        .swipeActions { deleteButton(task) }
                }
            }

            if !thoughts.isEmpty {
                Section("Thoughts") {
                    ForEach(thoughts) { thought in
                        TaskRow(task: thought, onChange: save)
                            .swipeActions { deleteButton(thought) }
                            .swipeActions(edge: .leading) {
                                Button {
                                    thought.isThought = false
                                    save()
                                } label: {
                                    Label("Make task", systemImage: "checklist")
                                }
                                .tint(.accentColor)
                            }
                    }
                }
            }

            if !doneTasks.isEmpty {
                Section(isExpanded: $showDone) {
                    ForEach(doneTasks) { task in
                        TaskRow(task: task, onChange: save)
                            .swipeActions { deleteButton(task) }
                    }
                } header: {
                    Text("Done (\(doneTasks.count))")
                }
            }
        }
        .listStyle(.sidebar)
        .animation(.default, value: items.map(\.isDone))
        .safeAreaInset(edge: .bottom) {
            QuickAddBar(text: $newTitle, isThought: $newIsThought, onSubmit: add)
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
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct TaskRow: View {
    let task: TaskItem
    let onChange: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if task.isThought {
                Image(systemName: "lightbulb")
                    .foregroundStyle(.yellow)
            } else {
                Button {
                    task.toggleDone()
                    onChange()
                } label: {
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(task.isDone ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(task.isDone ? Text("Mark as not done") : Text("Mark as done"))
            }

            Text(task.title)
                .strikethrough(task.isDone)
                .foregroundStyle(task.isDone ? Color.secondary : Color.primary)
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
        .modelContainer(for: TaskItem.self, inMemory: true)
}
