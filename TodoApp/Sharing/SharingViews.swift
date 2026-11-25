import SwiftUI

// v1.1 Sharing screens. Canvas: row "v1.1 Sharing" (S1, S3, S4). Spec: docs/SHARING_SPEC.md.

/// A round avatar with the member's initial.
struct MemberAvatar: View {
    let member: SpaceMember?
    var size: CGFloat = 40

    var body: some View {
        let pair = Theme.Avatar.pair(member?.colorIndex ?? 0)
        Circle()
            .fill(pair.fill)
            .frame(width: size, height: size)
            .overlay {
                Text(verbatim: member?.initial ?? "?")
                    .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
                    .foregroundStyle(pair.ink)
            }
            .accessibilityHidden(true)
    }
}

/// Header entry point: avatars of your people, with a dot when something new is waiting.
struct SharedHeaderButton: View {
    @Environment(SharingStore.self) private var sharing
    let action: () -> Void

    var body: some View {
        let waiting = sharing.incoming().count
        Button(action: action) {
            HStack(spacing: -10) {
                if sharing.hasSpace, !sharing.others.isEmpty {
                    ForEach(sharing.others.prefix(2)) { member in
                        MemberAvatar(member: member, size: 30)
                            .overlay(Circle().stroke(Theme.paper, lineWidth: 2))
                    }
                } else {
                    Image(systemName: "person.2")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 30, height: 30)
                }
            }
            .padding(.horizontal, 6)
            .frame(minWidth: 44, minHeight: 44)
            .overlay(alignment: .topTrailing) {
                if waiting > 0 {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Theme.paper, lineWidth: 2))
                        .offset(x: -2, y: 6)
                }
            }
        }
        .accessibilityLabel(label(waiting: waiting))
    }

    private func label(waiting: Int) -> Text {
        guard let space = sharing.space else { return Text("Share with your people") }
        if waiting > 0 {
            return Text("Shared space \(space.name), ^[\(waiting) new reminder](inflect: true)")
        }
        return Text("Shared space \(space.name)")
    }
}

// MARK: - S1 Start sharing

struct ShareStartView: View {
    @Environment(SharingStore.self) private var sharing
    @Environment(\.dismiss) private var dismiss
    /// Called after the space exists, so the caller can show it.
    let onCreated: () -> Void

    @State private var myName = ""
    @State private var spaceName = String(localized: "Home")
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        HStack(spacing: -12) {
                            MemberAvatar(member: SpaceMember(id: "", displayName: myName.isEmpty ? "?" : myName, colorIndex: 2), size: 52)
                                .overlay(Circle().stroke(Theme.fog, lineWidth: 3))
                            iconBubble("heart", pair: Theme.Avatar.pair(0))
                            iconBubble("plus", pair: Theme.Avatar.pair(1))
                        }
                        .accessibilityHidden(true)
                        Text("Bring your people in")
                            .font(.largeTitle.weight(.bold))
                            .multilineTextAlignment(.center)
                        Text("Partner, roommates, family. They can send you a gentle reminder, and you can send them one.")
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 0) {
                        LabeledField(label: "What should they call you?", text: $myName, prompt: "Your first name")
                        Divider().overlay(Theme.separator)
                        LabeledField(label: "Name your space", text: $spaceName, prompt: "Home")
                    }
                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.control))

                    VStack(alignment: .leading, spacing: 12) {
                        Promise(symbol: "lock", title: "Your lists stay yours.", detail: "Nobody sees your tasks.")
                        Promise(symbol: "hand.raised", title: "You're in charge.", detail: "Take it, save it for later, or pass. All fine.")
                        Promise(symbol: "heart", title: "No scorekeeping.", detail: "Nobody gets told when, or if, you finish.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        isWorking = true
                        Task {
                            defer { isWorking = false }
                            do {
                                try await sharing.createSpace(name: spaceName, myName: myName)
                                dismiss()
                                onCreated()
                            } catch {
                                errorMessage = SharingCloud.message(for: error)
                            }
                        }
                    } label: {
                        ZStack {
                            if isWorking {
                                ProgressView().tint(Theme.onAccent)
                            } else {
                                Label("Invite someone", systemImage: "square.and.arrow.up")
                            }
                        }
                        .font(.body.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.onAccent)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                    .disabled(myName.trimmingCharacters(in: .whitespaces).isEmpty || isWorking)
                    .opacity(myName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)

                    Text("Send the link any way you like. Works with iCloud, so no new account. Up to 5 people.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .background(Theme.fog)
            }
            .background(Theme.fog)
            .foregroundStyle(Theme.ink)
            .navigationTitle(Text("Shared"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert(Text("Not just yet"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func iconBubble(_ symbol: String, pair: Theme.Avatar.Pair) -> some View {
        Circle()
            .fill(pair.fill)
            .frame(width: 52, height: 52)
            .overlay(Image(systemName: symbol).font(.title3.weight(.bold)).foregroundStyle(pair.ink))
            .overlay(Circle().stroke(Theme.fog, lineWidth: 3))
    }
}

private struct Promise: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
                .accessibilityHidden(true)
            (Text(title).bold() + Text(verbatim: " ") + Text(detail))
        }
    }
}

/// A small label above a text field, inside a white card.
struct LabeledField: View {
    let label: LocalizedStringKey
    @Binding var text: String
    var prompt: LocalizedStringKey = ""
    var bold = true

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.footnote.weight(.bold))
                .foregroundStyle(Theme.inkSoft)
            TextField(label, text: $text, prompt: Text(prompt))
                .font(bold ? .title3.weight(.bold) : .body)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - S3 Shared space

struct SharedSpaceView: View {
    @Environment(SharingStore.self) private var sharing
    @Environment(\.dismiss) private var dismiss

    @State private var showSend = false
    @State private var showInviteInfo = false
    @State private var renaming = false
    @State private var editingName = false
    @State private var draft = ""
    @State private var confirmLeave = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let message = sharing.syncMessage {
                        Label(message, systemImage: "icloud")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Text("Your shared space · ^[\(sharing.members.count) person](inflect: true)")
                        .foregroundStyle(Theme.inkSoft)

                    VStack(alignment: .leading, spacing: 8) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 14) {
                            ForEach(sharing.members) { member in
                                VStack(spacing: 6) {
                                    MemberAvatar(member: member, size: 56)
                                    Text(member.id == sharing.myID ? String(localized: "You") : member.displayName)
                                        .font(.footnote.weight(.bold))
                                        .lineLimit(1)
                                }
                                .accessibilityElement(children: .combine)
                            }
                            if sharing.canInviteMore {
                                Button { invite() } label: {
                                    VStack(spacing: 6) {
                                        Circle()
                                            .strokeBorder(Theme.track, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                                            .frame(width: 56, height: 56)
                                            .overlay(Image(systemName: "plus").font(.title3.weight(.bold)))
                                        Text("Invite").font(.footnote.weight(.bold))
                                    }
                                    .foregroundStyle(Theme.accent)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 18)
                        .padding(.horizontal, 12)
                        .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.card))

                        Group {
                            if sharing.canInviteMore {
                                Text("Room for \(sharing.spotsLeft) more.")
                            } else {
                                Text("Your space is full. Five is a cozy crowd.")
                            }
                        }
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                            .padding(.leading, 4)
                    }

                    Button { showSend = true } label: {
                        Label("Send a reminder", systemImage: "heart")
                            .font(.body.weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.onAccent)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                    .disabled(sharing.others.isEmpty)
                    .opacity(sharing.others.isEmpty ? 0.5 : 1)

                    if sharing.others.isEmpty {
                        Text("Invite someone first, then you can send them reminders.")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                    }

                    let incoming = sharing.incoming()
                    if !incoming.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel("For you")
                                .padding(.leading, 4)
                            ReminderRows(reminders: incoming) { reminder in
                                (reminder.state == .handedBack
                                    ? Text("\(sharing.name(of: reminder.recipientID)) handed it back")
                                    : Text("From \(sharing.name(of: reminder.senderID)) · \(reminder.createdAt, format: .relative(presentation: .named))"),
                                 Text("New"), Theme.accent,
                                 sharing.member(reminder.state == .handedBack ? reminder.recipientID : reminder.senderID))
                            }
                        }
                    }

                    if !sharing.sent.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel("You sent")
                                .padding(.leading, 4)
                            ReminderRows(reminders: sharing.sent) { reminder in
                                (Text("To \(sharing.name(of: reminder.recipientID)) · \(reminder.createdAt, format: .relative(presentation: .named))"),
                                 Text(sharing.senderStatus(reminder)),
                                 reminder.state == .taken ? Theme.gotIt : Theme.inkSoft,
                                 sharing.member(reminder.recipientID))
                            }
                            Text("You'll see when someone takes a reminder. Whether they've done it is their business.")
                                .font(.footnote)
                                .foregroundStyle(Theme.inkSoft)
                                .padding(.horizontal, 4)
                        }
                    }
                }
                .padding(20)
            }
            .refreshable { await sharing.refresh() }
            .task {
                if sharing.wantsInvite {
                    sharing.wantsInvite = false
                    // Let this sheet finish appearing before the share sheet goes on top.
                    try? await Task.sleep(for: .milliseconds(600))
                    invite()
                } else {
                    await sharing.refresh()
                }
            }
            .background(Theme.fog)
            .foregroundStyle(Theme.ink)
            .navigationTitle(Text(sharing.space?.name ?? ""))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if sharing.isOwner {
                            Button {
                                draft = sharing.space?.name ?? ""
                                renaming = true
                            } label: {
                                Label("Rename space", systemImage: "pencil")
                            }
                        }
                        Button {
                            draft = sharing.me?.displayName ?? ""
                            editingName = true
                        } label: {
                            Label("Change my name", systemImage: "person.crop.circle")
                        }
                        Button {
                            confirmLeave = true
                        } label: {
                            if sharing.isOwner {
                                Label("Stop sharing", systemImage: "person.2.slash")
                            } else {
                                Label("Leave \(sharing.space?.name ?? "")", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .accessibilityLabel(Text("Shared space settings"))
                    }
                }
            }
            .sheet(isPresented: $showSend) {
                SendReminderView()
                    .tint(Theme.accent)
            }
            .alert(Text("Rename space"), isPresented: $renaming) {
                TextField("Name", text: $draft)
                Button("Save") { sharing.renameSpace(draft) }
                Button("Cancel", role: .cancel) {}
            }
            .alert(Text("What should they call you?"), isPresented: $editingName) {
                TextField("Name", text: $draft)
                Button("Save") { sharing.setMyName(draft) }
                Button("Cancel", role: .cancel) {}
            }
            .alert(Text("This is demo data"), isPresented: $showInviteInfo) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Invites need a real space. Leave the demo space, then start sharing from the button at the top of your list.")
            }
            .alert(Text("Not just yet"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .confirmationDialog(
                sharing.isOwner ? Text("Stop sharing \(sharing.space?.name ?? "")?") : Text("Leave \(sharing.space?.name ?? "")?"),
                isPresented: $confirmLeave,
                titleVisibility: .visible
            ) {
                Button(sharing.isOwner ? LocalizedStringKey("Stop sharing") : LocalizedStringKey("Leave")) {
                    Task {
                        await sharing.leaveSpace()
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if sharing.isOwner {
                    Text("The space closes for everyone. Tasks people already took stay on their lists.")
                } else {
                    Text("You can come back anytime with a new invite. Your tasks stay right where they are.")
                }
            }
        }
    }
}

extension SharedSpaceView {
    /// Opens Apple's share sheet with the space's iCloud invite link.
    func invite() {
        guard sharing.isCloud else {
            showInviteInfo = true
            return
        }
        guard sharing.isOwner else {
            errorMessage = String(localized: "Only the person who started this space can invite people for now.")
            return
        }
        Task {
            do {
                let (share, container) = try await sharing.shareForInvite()
                InvitePresenter.present(share: share, container: container, title: sharing.space?.name ?? "") {
                    Task { await sharing.refresh() }
                }
            } catch {
                errorMessage = SharingCloud.message(for: error)
            }
        }
    }
}

/// A white card of reminder rows: avatar, title, subtitle and a status on the right.
private struct ReminderRows: View {
    let reminders: [SharedReminder]
    let details: (SharedReminder) -> (subtitle: Text, status: Text, statusColor: Color, member: SpaceMember?)

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(reminders.enumerated()), id: \.element.id) { index, reminder in
                let info = details(reminder)
                HStack(spacing: 12) {
                    MemberAvatar(member: info.member, size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(reminder.title)
                            .font(.body.weight(.bold))
                        info.subtitle
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    info.status
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(info.statusColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .accessibilityElement(children: .combine)
                if index < reminders.count - 1 {
                    Divider().overlay(Theme.separator)
                }
            }
        }
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
    }
}

// MARK: - S4 Send a reminder

struct SendReminderView: View {
    @Environment(SharingStore.self) private var sharing
    @Environment(\.dismiss) private var dismiss

    enum When: String, CaseIterable, Identifiable {
        case now, evening, tomorrow
        var id: String { rawValue }

        var title: LocalizedStringKey {
            switch self {
            case .now: "Now"
            case .evening: "This evening"
            case .tomorrow: "Tomorrow"
            }
        }

        var date: Date {
            switch self {
            case .now: .now
            case .evening: ReminderTiming.tonight()
            case .tomorrow: ReminderTiming.tomorrowMorning()
            }
        }
    }

    @State private var recipients: Set<String> = []
    @State private var title = ""
    @State private var note = ""
    @State private var when: When = .now

    private var canSend: Bool {
        !recipients.isEmpty && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var chosenNames: [String] {
        sharing.others.filter { recipients.contains($0.id) }.map(\.displayName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel("For").padding(.leading, 4)
                        FlowChips(members: sharing.others, selected: $recipients)
                    }

                    VStack(spacing: 0) {
                        LabeledField(label: "What's the reminder?", text: $title, prompt: "Take the laundry out")
                        Divider().overlay(Theme.separator)
                        LabeledField(label: "A little note (optional)", text: $note, prompt: "No rush", bold: false)
                    }
                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.control))

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel("When should it pop up?").padding(.leading, 4)
                        Picker("When should it pop up?", selection: $when) {
                            ForEach(When.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    if !title.trimmingCharacters(in: .whitespaces).isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel("They'll see").padding(.leading, 4)
                            HStack(spacing: 10) {
                                MemberAvatar(member: sharing.me, size: 32)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(sharing.me?.displayName ?? "") added a reminder")
                                        .font(.footnote.weight(.bold))
                                        .foregroundStyle(Theme.inkSoft)
                                    Text(title).font(.body.weight(.bold))
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .padding(20)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        sharing.send(title: title, note: note, to: Array(recipients), showAt: when.date)
                        dismiss()
                    } label: {
                        Label {
                            if chosenNames.isEmpty {
                                Text("Pick someone first")
                            } else {
                                Text("Send to \(chosenNames.formatted(.list(type: .and)))")
                            }
                        } icon: {
                            Image(systemName: "heart")
                        }
                        .font(.body.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(canSend ? Theme.onAccent : Theme.inkSoft)
                    .background(canSend ? Theme.accent : Theme.segment, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                    .disabled(!canSend)

                    Text("They can take it, save it for later or pass. Any answer is a good answer.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .background(Theme.fog)
            }
            .background(Theme.fog)
            .foregroundStyle(Theme.ink)
            .navigationTitle(Text("Send a reminder"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if sharing.others.count == 1, let only = sharing.others.first {
                    recipients = [only.id]
                }
            }
        }
    }
}

/// Recipient chips that wrap onto new lines.
private struct FlowChips: View {
    let members: [SpaceMember]
    @Binding var selected: Set<String>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(members) { member in
                let on = selected.contains(member.id)
                Button {
                    if on { selected.remove(member.id) } else { selected.insert(member.id) }
                } label: {
                    HStack(spacing: 8) {
                        MemberAvatar(member: member, size: 34)
                        Text(member.displayName)
                            .font(.body.weight(.bold))
                            .lineLimit(1)
                            .fixedSize()
                        if on {
                            Image(systemName: "checkmark")
                                .font(.footnote.weight(.bold))
                        }
                    }
                    .padding(.leading, 6)
                    .padding(.trailing, 16)
                    .frame(minHeight: 48)
                    .background(on ? Theme.currentRow : Theme.paper, in: Capsule())
                    .overlay(Capsule().strokeBorder(on ? Theme.accent : Theme.segment, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
          }
          .padding(.vertical, 2)
        }
    }
}
