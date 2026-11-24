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
                if SharingStore.isEnabled, task.fromReminderID != nil {
                    ReminderFromSection(task: task)
                }

                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Title")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Theme.inkSoft)
                        TextField("Title", text: $task.title, axis: .vertical)
                            .font(.title3.weight(.bold))
                    }
                    .listRowBackground(Theme.paper)

                    Toggle("Thought (not a task)", isOn: $task.isThought)
                        .listRowBackground(Theme.paper)
                    if !task.isThought && !task.isDone {
                        Toggle("Pin as next", isOn: Binding(
                            get: { task.isPinned },
                            set: { pinned in
                                task.isPinned = pinned
                                if pinned { task.isLater = false }
                            }
                        ))
                        .listRowBackground(Theme.paper)

                        Toggle(isOn: Binding(
                            get: { task.isLater },
                            set: { later in later ? task.moveToLater() : task.bringBack() }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Later")
                                Text("Out of sight until you bring it back")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.inkSoft)
                            }
                        }
                        .listRowBackground(Theme.paper)
                    }
                }

                if !task.isThought {
                    Section {
                        ForEach(task.sortedSteps) { step in
                            let isCurrent = step.id == task.currentStep?.id
                            StepRow(step: step, isCurrent: isCurrent) {
                                withAnimation { task.toggleStep(step) }
                                context.saveAndRefresh()
                            }
                            .listRowBackground(isCurrent ? Theme.currentRow : Theme.paper)
                            .listRowSeparatorTint(Theme.separator)
                        }
                        .onDelete(perform: deleteSteps)

                        HStack(spacing: 12) {
                            Image(systemName: "plus")
                                .font(.body.weight(.bold))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 24)
                            TextField("Add a tiny step…", text: $newStep)
                                .focused($stepFieldFocused)
                                .submitLabel(.next)
                                .onSubmit(addStep)
                        }
                        .listRowBackground(Theme.paper)
                    } header: {
                        if task.stepCount > 0 {
                            SectionLabel(verbatim: Text("Steps · \(task.doneStepCount) of \(task.stepCount) done"))
                        } else {
                            SectionLabel("Steps")
                        }
                    } footer: {
                        Text("Make each step so small it feels almost silly. That's the trick.")
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.fog)
            .foregroundStyle(Theme.ink)
            .navigationTitle(task.isThought ? Text("Thought") : Text("Task"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        context.saveAndRefresh()
                        dismiss()
                    }
                    .fontWeight(.heavy)
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
    var isCurrent: Bool = false
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                CheckCircle(isDone: step.isDone, isCurrent: isCurrent, size: 24)
                Text(step.title)
                    .font(.body.weight(isCurrent ? .bold : (step.isDone ? .regular : .semibold)))
                    .strikethrough(step.isDone)
                    .foregroundStyle(step.isDone ? Theme.inkSoft : Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isCurrent {
                    Text("Now")
                        .font(.footnote.weight(.heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
