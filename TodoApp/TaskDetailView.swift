import SwiftUI
import SwiftData

/// Edit a task and break it into tiny steps.
struct TaskDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: TaskItem

    @State private var newStep = ""
    @FocusState private var stepFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $task.title, axis: .vertical)
                    Toggle("Thought (not a task)", isOn: $task.isThought)
                    if !task.isThought {
                        Toggle("Pin as next", isOn: $task.isPinned)
                    }
                }

                if !task.isThought {
                    Section {
                        ForEach(task.sortedSteps) { step in
                            StepRow(step: step) {
                                withAnimation { task.toggleStep(step) }
                                context.saveAndRefresh()
                            }
                        }
                        .onDelete(perform: deleteSteps)

                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentColor)
                            TextField("Add a tiny step…", text: $newStep)
                                .focused($stepFieldFocused)
                                .submitLabel(.next)
                                .onSubmit(addStep)
                        }
                    } header: {
                        Text("Steps")
                    } footer: {
                        Text("Make each step so small it feels almost silly. That's the trick.")
                    }
                }
            }
            .navigationTitle(task.isThought ? Text("Thought") : Text("Task"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        context.saveAndRefresh()
                        dismiss()
                    }
                }
            }
        }
    }

    private func addStep() {
        let title = newStep.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        withAnimation { task.addStep(title, in: context) }
        newStep = ""
        stepFieldFocused = true
        context.saveAndRefresh()
    }

    private func deleteSteps(at offsets: IndexSet) {
        let steps = task.sortedSteps
        for index in offsets {
            context.delete(steps[index])
        }
        context.saveAndRefresh()
    }
}

struct StepRow: View {
    let step: TaskStep
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: step.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(step.isDone ? Color.accentColor : Color.secondary)
                    .symbolEffect(.bounce, value: step.isDone)
                Text(step.title)
                    .strikethrough(step.isDone)
                    .foregroundStyle(step.isDone ? Color.secondary : Color.primary)
            }
        }
        .buttonStyle(.plain)
    }
}
