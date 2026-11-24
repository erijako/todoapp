import Foundation

// v1.1 Sharing: the shared space's data. See docs/SHARING_SPEC.md.
// These mirror the CloudKit record types (Space, Member, Reminder). Until CloudKit lands they
// live only in the local cache.

/// The one shared space you belong to (max `SharedSpace.maxMembers` people).
struct SharedSpace: Codable, Equatable {
    static let maxMembers = 5

    var name: String
    /// Member id of the person who created the space.
    var ownerID: String
}

/// A person in the shared space. Each person writes their own record.
struct SpaceMember: Codable, Equatable, Identifiable {
    /// Stable id (later: the CloudKit user record name).
    var id: String
    var displayName: String
    /// Picks one of `Theme.Avatar.palette`, assigned in join order.
    var colorIndex: Int
    var joinedAt: Date = .now

    var initial: String {
        displayName.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "?"
    }
}

/// Where a reminder is in its life. Completion is never part of this, on purpose.
enum ReminderState: String, Codable {
    /// Waiting for the recipient.
    case sent
    /// The recipient put it on their list.
    case taken
    /// The recipient said "not this time".
    case passed
    /// The recipient took it, then handed it back to the sender.
    case handedBack
    /// The sender dealt with a handed-back reminder. Hidden everywhere.
    case closed
}

/// A gentle reminder from one person to one other person (one record per recipient).
struct SharedReminder: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var title: String
    var note: String = ""
    var senderID: String
    var recipientID: String
    /// When it should pop up for the recipient.
    var showAt: Date = .now
    var state: ReminderState = .sent
    var createdAt: Date = .now
    var answeredAt: Date?
}

/// Everything the app keeps on this device about sharing.
struct SharingCache: Codable, Equatable {
    var myID: String = UUID().uuidString
    var space: SharedSpace?
    var members: [SpaceMember] = []
    var reminders: [SharedReminder] = []
    /// Local only: "bring it back later" times per reminder id. The sender never sees these.
    var snoozedUntil: [String: Date] = [:]
}

/// Friendly times used by "Later" and by "When should it pop up?".
enum ReminderTiming {
    static func inAnHour(from now: Date = .now) -> Date {
        now.addingTimeInterval(3600)
    }

    /// 18:00 today; later in the evening it moves to 21:00; after that, tomorrow morning.
    static func tonight(from now: Date = .now) -> Date {
        let calendar = Calendar.current
        for hour in [18, 21] {
            if let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now),
               date > now.addingTimeInterval(30 * 60) {
                return date
            }
        }
        return tomorrowMorning(from: now)
    }

    /// 09:00 tomorrow.
    static func tomorrowMorning(from now: Date = .now) -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }
}
