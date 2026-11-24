import CloudKit
import Foundation
import Observation
import SwiftData

/// A short, kind message after answering a reminder, with Undo.
struct SharingToast: Identifiable, Equatable {
    let id = UUID()
    let message: String
}

/// Owns the shared space on this device: members, reminders, snoozes.
///
/// The local cache (a small JSON file in the App Group) is the source for the UI. When the space
/// lives in iCloud, every change is marked dirty and saved; `refresh()` reads the whole zone.
/// Without a zone (demo data) everything stays local.
@MainActor
@Observable
final class SharingStore {
    /// Sharing is shown in test builds (Debug + TestFlight) only, until CloudKit sync is done.
    private(set) var isEnabled = TestBuild.isDebug

    private(set) var cache: SharingCache
    var toast: SharingToast?
    /// A calm line about iCloud trouble, shown in the shared space.
    var syncMessage: String?
    /// Set after creating a space so the shared space opens the invite sheet right away.
    var wantsInvite = false

    /// The live store, for the app delegate's background pushes.
    static weak var current: SharingStore?
    private let cloud = SharingCloud()

    /// What the last answer changed, so Undo can put it back.
    private struct UndoRecord {
        let reminderID: String
        let previousState: ReminderState
        let previousSnooze: Date?
        let createdTaskID: UUID?
    }
    private var undoRecord: UndoRecord?

    private let fileURL: URL

    init(fileURL: URL = SharingStore.defaultFileURL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let cache = try? JSONDecoder().decode(SharingCache.self, from: data) {
            self.cache = cache
        } else {
            self.cache = SharingCache()
        }
        SharingStore.current = self
        Task {
            isEnabled = await TestBuild.check()
            await refresh()
        }
    }

    nonisolated static var defaultFileURL: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("sharing.json")
    }

    // MARK: Reading

    var myID: String { cache.myID }
    var space: SharedSpace? { cache.space }
    var hasSpace: Bool { cache.space != nil }
    var isOwner: Bool { cache.space?.ownerID == cache.myID }
    var cacheZoneName: String? { cache.zoneName }
    /// The space lives in iCloud (not demo data).
    var isCloud: Bool { cache.zoneName != nil }

    private var zoneID: CKRecordZone.ID? {
        guard let name = cache.zoneName else { return nil }
        return CKRecordZone.ID(zoneName: name, ownerName: cache.zoneOwner ?? CKCurrentUserDefaultName)
    }

    /// Whether the zone is in your private database (you created the space).
    private var ownedByMe: Bool { (cache.zoneOwner ?? CKCurrentUserDefaultName) == CKCurrentUserDefaultName }

    var members: [SpaceMember] {
        cache.members.sorted { $0.joinedAt < $1.joinedAt }
    }

    /// Everyone except you.
    var others: [SpaceMember] { members.filter { $0.id != myID } }

    var me: SpaceMember? { cache.members.first { $0.id == myID } }

    var canInviteMore: Bool { cache.members.count < SharedSpace.maxMembers }
    var spotsLeft: Int { max(0, SharedSpace.maxMembers - cache.members.count) }

    func member(_ id: String) -> SpaceMember? {
        cache.members.first { $0.id == id }
    }

    func name(of id: String) -> String {
        member(id)?.displayName ?? String(localized: "Someone")
    }

    /// Reminders waiting for you right now, oldest first: new ones for you (not snoozed,
    /// already due) and ones handed back to you.
    func incoming(now: Date = .now) -> [SharedReminder] {
        cache.reminders
            .filter { reminder in
                if reminder.recipientID == myID, reminder.state == .sent {
                    let snooze = cache.snoozedUntil[reminder.id] ?? .distantPast
                    return reminder.showAt <= now && snooze <= now
                }
                return reminder.senderID == myID && reminder.state == .handedBack
            }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// What you sent in the last 14 days, newest first.
    var sent: [SharedReminder] {
        let cutoff = Date.now.addingTimeInterval(-14 * 24 * 3600)
        return cache.reminders
            .filter { $0.senderID == myID && $0.state != .closed && $0.createdAt >= cutoff }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// The status line the sender sees. Never anything about completion.
    func senderStatus(_ reminder: SharedReminder) -> String {
        let name = name(of: reminder.recipientID)
        switch reminder.state {
        case .sent, .closed: return String(localized: "Sent")
        case .taken: return String(localized: "\(name)'s got it")
        case .passed: return String(localized: "Not this time")
        case .handedBack: return String(localized: "Handed back")
        }
    }

    // MARK: Space

    /// Creates your space in iCloud (S1). Invites go out through the share sheet afterwards.
    func createSpace(name: String, myName: String) async throws {
        try await cloud.requireAccount()
        let uid = try await cloud.myUserID()
        let spaceName = name.trimmed.isEmpty ? String(localized: "Home") : name.trimmed
        let space = SharedSpace(name: spaceName, ownerID: uid)
        let me = SpaceMember(id: uid, displayName: myName.trimmed.isEmpty ? String(localized: "Me") : myName.trimmed, colorIndex: 2)
        let zone = try await cloud.createSpace(space, me: me)

        var fresh = SharingCache()
        fresh.myID = uid
        fresh.space = space
        fresh.members = [me]
        fresh.zoneName = zone.zoneName
        fresh.zoneOwner = zone.ownerName
        cache = fresh
        toast = nil
        undoRecord = nil
        syncMessage = nil
        wantsInvite = true
        persist()
        await cloud.subscribe(zoneID: zone, ownedByMe: true)
    }

    /// Joins someone's space from an invite link (S2).
    func join(_ metadata: CKShare.Metadata, myName: String) async throws {
        // Your own invite link: nothing to accept.
        if metadata.participantRole == .owner {
            await refresh()
            return
        }
        if let space = cache.space, isCloud, cache.zoneName != metadata.share.recordID.zoneID.zoneName {
            throw SharingCloud.CloudError.alreadyInSpace(space.name)
        }
        try await cloud.requireAccount()
        try await cloud.accept(metadata)
        let uid = try await cloud.myUserID()
        let zone = metadata.share.recordID.zoneID

        var fresh = SharingCache()
        fresh.myID = uid
        fresh.zoneName = zone.zoneName
        fresh.zoneOwner = zone.ownerName
        cache = fresh
        toast = nil
        undoRecord = nil
        syncMessage = nil
        persist()

        await refresh()
        let me = SpaceMember(id: uid, displayName: myName.trimmed.isEmpty ? String(localized: "Me") : myName.trimmed,
                             colorIndex: cache.members.count % Theme.Avatar.palette.count)
        cache.members.removeAll { $0.id == uid }
        cache.members.append(me)
        markDirty(SharingCloud.memberRecordName(uid))
        await cloud.subscribe(zoneID: zone, ownedByMe: false)
    }

    /// The share to hand to the invite sheet (owner only).
    func shareForInvite() async throws -> (CKShare, CKContainer) {
        guard let zoneID, ownedByMe else { throw SharingCloud.CloudError.noShare }
        return (try await cloud.share(in: zoneID), cloud.container)
    }

    func renameSpace(_ name: String) {
        guard !name.trimmed.isEmpty else { return }
        cache.space?.name = name.trimmed
        markDirty("space")
    }

    func setMyName(_ name: String) {
        guard !name.trimmed.isEmpty, let index = cache.members.firstIndex(where: { $0.id == myID }) else { return }
        cache.members[index].displayName = name.trimmed
        markDirty(SharingCloud.memberRecordName(myID))
    }

    /// Leaves the space (member) or ends it for everyone (owner). Your own tasks stay.
    func leaveSpace() async {
        if let zoneID {
            await cloud.leave(zoneID: zoneID, ownedByMe: ownedByMe, memberRecordName: SharingCloud.memberRecordName(myID))
        }
        let myID = cache.myID
        cache = SharingCache()
        cache.myID = myID
        toast = nil
        undoRecord = nil
        persist()
    }

    // MARK: Sending

    func send(title: String, note: String, to recipients: [String], showAt: Date) {
        guard !title.trimmed.isEmpty else { return }
        for recipient in recipients where recipient != myID {
            cache.reminders.append(SharedReminder(
                title: title.trimmed,
                note: note.trimmed,
                senderID: myID,
                recipientID: recipient,
                showAt: showAt
            ))
            markDirty(cache.reminders[cache.reminders.count - 1].id)
        }
        persist()
    }

    // MARK: Answering (S5)

    /// Puts the reminder on your Personal list, at the end. It never jumps the queue.
    func take(_ reminder: SharedReminder, in context: ModelContext) {
        let task = TaskItem(title: reminder.title, mode: .personal)
        let fromID = reminder.state == .handedBack ? reminder.recipientID : reminder.senderID
        // A handed-back reminder comes from you; there is no one to hand it back to.
        if reminder.state != .handedBack {
            task.fromReminderID = reminder.id
            task.fromName = name(of: fromID)
            task.fromNote = reminder.note.isEmpty ? nil : reminder.note
            task.fromSentAt = reminder.createdAt
        }
        context.insert(task)
        context.saveAndRefresh()

        let next: ReminderState = reminder.state == .handedBack ? .closed : .taken
        answer(reminder, state: next, createdTaskID: task.id)
        let message = reminder.state == .handedBack
            ? String(localized: "Back on your list.")
            : String(localized: "On your list. \(name(of: fromID)) will see you've got it.")
        toast = SharingToast(message: message)
    }

    /// Hides it until `date`. Local only: the sender sees nothing.
    func snooze(_ reminder: SharedReminder, until date: Date) {
        undoRecord = UndoRecord(reminderID: reminder.id, previousState: reminder.state,
                                previousSnooze: cache.snoozedUntil[reminder.id], createdTaskID: nil)
        cache.snoozedUntil[reminder.id] = date
        persist()
        let time = date.formatted(date: .omitted, time: .shortened)
        toast = SharingToast(message: Calendar.current.isDateInToday(date)
            ? String(localized: "Tucked away. It'll come back at \(time).")
            : String(localized: "Tucked away. It'll come back tomorrow at \(time)."))
    }

    func pass(_ reminder: SharedReminder) {
        let handedBack = reminder.state == .handedBack
        answer(reminder, state: handedBack ? .closed : .passed, createdTaskID: nil)
        toast = SharingToast(message: handedBack
            ? String(localized: "Let go. That's allowed.")
            : String(localized: "Passed, no hard feelings. \(name(of: reminder.senderID)) just sees \"not this time\"."))
    }

    /// Reverts the last answer, including the task it created.
    func undo(in context: ModelContext) {
        guard let record = undoRecord,
              let index = cache.reminders.firstIndex(where: { $0.id == record.reminderID }) else {
            toast = nil
            return
        }
        cache.reminders[index].state = record.previousState
        cache.reminders[index].answeredAt = nil
        cache.snoozedUntil[record.reminderID] = record.previousSnooze
        if let taskID = record.createdTaskID {
            let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskID })
            if let task = try? context.fetch(descriptor).first {
                context.delete(task)
                context.saveAndRefresh()
            }
        }
        undoRecord = nil
        toast = nil
        markDirty(record.reminderID)
    }

    func dismissToast() {
        toast = nil
        undoRecord = nil
    }

    // MARK: Hand it back (S6)

    /// Whether a task that came from a reminder can still be handed back.
    func canHandBack(_ task: TaskItem) -> Bool {
        guard let id = task.fromReminderID else { return false }
        return cache.reminders.contains { $0.id == id && $0.state == .taken }
    }

    /// Removes the task from your list and returns the reminder to its sender.
    func handBack(_ task: TaskItem, in context: ModelContext) {
        if let id = task.fromReminderID, let index = cache.reminders.firstIndex(where: { $0.id == id }) {
            cache.reminders[index].state = .handedBack
            cache.reminders[index].answeredAt = .now
            markDirty(id)
        }
        context.delete(task)
        context.saveAndRefresh()
    }

    // MARK: Private

    private func answer(_ reminder: SharedReminder, state: ReminderState, createdTaskID: UUID?) {
        guard let index = cache.reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        undoRecord = UndoRecord(reminderID: reminder.id, previousState: reminder.state,
                                previousSnooze: cache.snoozedUntil[reminder.id], createdTaskID: createdTaskID)
        cache.reminders[index].state = state
        cache.reminders[index].answeredAt = .now
        cache.snoozedUntil[reminder.id] = nil
        markDirty(reminder.id)
    }

    // MARK: iCloud sync

    /// Remembers that a record changed here and saves it to iCloud (no-op for demo data).
    private func markDirty(_ recordName: String) {
        guard isCloud else { persist(); return }
        var dirty = Set(cache.dirty ?? [])
        dirty.insert(recordName)
        cache.dirty = Array(dirty)
        persist()
        Task { await pushDirty() }
    }

    /// Reads the whole space from iCloud, keeps local changes that aren't saved yet, then saves them.
    func refresh() async {
        guard let zoneID else { return }
        do {
            let records = try await cloud.fetchAll(zoneID: zoneID, ownedByMe: ownedByMe)
            apply(records)
            syncMessage = nil
            await pushDirty()
        } catch let error where SharingCloud.isGone(error) {
            let name = cache.space?.name ?? String(localized: "Your space")
            let myID = cache.myID
            cache = SharingCache()
            cache.myID = myID
            persist()
            syncMessage = String(localized: "\(name) was closed. Your own tasks are all still here.")
        } catch {
            syncMessage = String(localized: "Couldn't reach iCloud just now. Changes are saved here and will sync later.")
        }
    }

    private func apply(_ records: [CKRecord]) {
        let dirty = Set(cache.dirty ?? [])
        var members: [SpaceMember] = []
        var reminders: [SharedReminder] = []
        for record in records where !dirty.contains(record.recordID.recordName) {
            switch record.recordType {
            case SharingCloud.RecordType.space:
                if let space = SharingCloud.space(from: record) { cache.space = space }
            case SharingCloud.RecordType.member:
                if let member = SharingCloud.member(from: record) { members.append(member) }
            case SharingCloud.RecordType.reminder:
                if let reminder = SharingCloud.reminder(from: record) { reminders.append(reminder) }
            default:
                break
            }
        }
        // Keep local versions of anything not yet saved.
        members += cache.members.filter { dirty.contains(SharingCloud.memberRecordName($0.id)) }
        reminders += cache.reminders.filter { dirty.contains($0.id) }
        cache.members = members
        cache.reminders = reminders
        persist()
    }

    private func pushDirty() async {
        guard let zoneID, let dirty = cache.dirty, !dirty.isEmpty else { return }
        var records: [CKRecord] = []
        for name in dirty {
            if name == "space", let space = cache.space {
                records.append(SharingCloud.record(space, zone: zoneID))
            } else if let member = cache.members.first(where: { SharingCloud.memberRecordName($0.id) == name }) {
                records.append(SharingCloud.record(member, zone: zoneID))
            } else if let reminder = cache.reminders.first(where: { $0.id == name }) {
                records.append(SharingCloud.record(reminder, zone: zoneID))
            }
        }
        do {
            try await cloud.save(records, in: cloud.database(ownedByMe: ownedByMe))
            cache.dirty = (cache.dirty ?? []).filter { !dirty.contains($0) }
            persist()
            syncMessage = nil
        } catch {
            syncMessage = String(localized: "Couldn't reach iCloud just now. Changes are saved here and will sync later.")
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: Demo data (test builds only, until CloudKit invites work)

    /// Fills the space with the canvas example: Alex, Sam and you in "Home".
    func loadDemo() {
        let alex = "demo-alex", sam = "demo-sam"
        let now = Date.now
        var demo = SharingCache()
        demo.myID = cache.myID
        demo.space = SharedSpace(name: "Home", ownerID: alex)
        demo.members = [
            SpaceMember(id: alex, displayName: "Alex", colorIndex: 0, joinedAt: now.addingTimeInterval(-300)),
            SpaceMember(id: sam, displayName: "Sam", colorIndex: 1, joinedAt: now.addingTimeInterval(-200)),
            SpaceMember(id: cache.myID, displayName: "Jo", colorIndex: 2, joinedAt: now.addingTimeInterval(-100)),
        ]
        demo.reminders = [
            SharedReminder(title: "Pick up oat milk", note: "Whenever you pass the shop. No rush!",
                           senderID: alex, recipientID: cache.myID, createdAt: now.addingTimeInterval(-60)),
            SharedReminder(title: "Call grandma back", senderID: cache.myID, recipientID: sam,
                           state: .taken, createdAt: now.addingTimeInterval(-26 * 3600)),
            SharedReminder(title: "Bring the bins in", senderID: cache.myID, recipientID: alex,
                           createdAt: now.addingTimeInterval(-2 * 3600)),
        ]
        cache = demo
        toast = nil
        undoRecord = nil
        persist()
    }

    /// Pretends someone just sent you a reminder.
    func simulateIncoming() {
        guard let sender = others.randomElement() else { return }
        let examples = [
            ("Take the laundry out of the machine", "No rush, before bed is perfect"),
            ("Water the basil", ""),
            ("Text me when you're home", "Just so I know"),
        ]
        let pick = examples.randomElement()!
        cache.reminders.append(SharedReminder(title: pick.0, note: pick.1, senderID: sender.id, recipientID: myID))
        persist()
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
