import SwiftUI
import SwiftData

/// S5: a reminder someone sent you, at the top of the list. Take it / Later / Pass.
struct IncomingReminderCard: View {
    @Environment(SharingStore.self) private var sharing
    @Environment(\.modelContext) private var context

    let reminder: SharedReminder
    /// How many more are waiting behind this one.
    var moreCount: Int = 0

    @State private var choosingLater = false

    private var isHandedBack: Bool { reminder.state == .handedBack }
    private var fromID: String { isHandedBack ? reminder.recipientID : reminder.senderID }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                MemberAvatar(member: sharing.member(fromID), size: 36)
                HStack(spacing: 5) {
                    if isHandedBack {
                        Text("\(sharing.name(of: fromID)) handed this back")
                    } else {
                        Text("\(sharing.name(of: fromID)) added a reminder")
                    }
                    Image(systemName: "heart.fill")
                        .foregroundStyle(Theme.heart)
                        .accessibilityHidden(true)
                }
                .font(.footnote.weight(.bold))
                .foregroundStyle(Theme.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(reminder.createdAt, format: .relative(presentation: .named))
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(reminder.title)
                    .font(.title3.weight(.heavy))
                if !reminder.note.isEmpty {
                    Text(verbatim: "“\(reminder.note)”")
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.fog, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .accessibilityElement(children: .combine)

            if choosingLater {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bring it back…")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.inkSoft)
                    HStack(spacing: 8) {
                        laterButton("In an hour", date: ReminderTiming.inAnHour())
                        laterButton("Tonight", date: ReminderTiming.tonight())
                        laterButton("Tomorrow", date: ReminderTiming.tomorrowMorning())
                    }
                    Button("Never mind") {
                        withAnimation { choosingLater = false }
                    }
                    .font(.body.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
            } else {
                HStack(spacing: 8) {
                    Button {
                        withAnimation { sharing.take(reminder, in: context) }
                    } label: {
                        Label("Take it", systemImage: "plus")
                            .font(.body.weight(.heavy))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .foregroundStyle(Theme.onAccent)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                    .layoutPriority(1)

                    if !isHandedBack {
                        secondaryButton("Later") {
                            withAnimation { choosingLater = true }
                        }
                    }
                    secondaryButton(isHandedBack ? "Let it go" : "Pass") {
                        withAnimation { sharing.pass(reminder) }
                    }
                }
                .buttonStyle(.plain)
            }

            if moreCount > 0 {
                Text("+\(moreCount) more waiting")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(18)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.track, lineWidth: 1.5))
        .shadow(color: Theme.ink.opacity(0.06), radius: 12, y: 6)
    }

    private func secondaryButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
        .background(Theme.segment, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
    }

    private func laterButton(_ title: LocalizedStringKey, date: Date) -> some View {
        Button {
            withAnimation {
                choosingLater = false
                sharing.snooze(reminder, until: date)
            }
        } label: {
            Text(title)
                .font(.body.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
        .background(Theme.currentRow, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
    }
}

/// The kind message after answering, with Undo. Goes away by itself after a few seconds.
struct SharingToastRow: View {
    @Environment(SharingStore.self) private var sharing
    @Environment(\.modelContext) private var context
    let toast: SharingToast

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart")
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text(toast.message)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Undo") {
                withAnimation { sharing.undo(in: context) }
            }
            .font(.body.weight(.bold))
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
        .task(id: toast.id) {
            try? await Task.sleep(for: .seconds(6))
            if sharing.toast?.id == toast.id {
                withAnimation { sharing.dismissToast() }
            }
        }
    }
}

/// S6: "From Alex" on a task that came from a reminder.
struct ReminderFromSection: View {
    @Environment(SharingStore.self) private var sharing
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let task: TaskItem

    var body: some View {
        let name = task.fromName ?? String(localized: "Someone")
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    MemberAvatar(member: sharing.members.first { $0.displayName == name }
                                 ?? SpaceMember(id: "", displayName: name, colorIndex: 0), size: 44)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 5) {
                            Text("From \(name)").font(.body.weight(.heavy))
                            Image(systemName: "heart.fill")
                                .font(.footnote)
                                .foregroundStyle(Theme.heart)
                                .accessibilityHidden(true)
                        }
                        if let sent = task.fromSentAt {
                            Text("\(sharing.space?.name ?? "") · sent \(sent, format: .relative(presentation: .named))")
                                .font(.footnote)
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                }
                if let note = task.fromNote {
                    Text(verbatim: "“\(note)”")
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.fog, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.vertical, 4)
            .listRowBackground(Theme.paper)

            if sharing.canHandBack(task) {
                Button {
                    sharing.handBack(task, in: context)
                    dismiss()
                } label: {
                    Label("Hand it back to \(name)", systemImage: "arrow.uturn.left")
                }
                .listRowBackground(Theme.paper)
            }
        } footer: {
            Text("\(name) only sees that you've got it. Nothing about when or if it's done.")
                .foregroundStyle(Theme.inkSoft)
        }
    }
}
