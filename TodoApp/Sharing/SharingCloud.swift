import CloudKit
import Observation
import UIKit

/// Talks to iCloud for the shared space. Spec: docs/SHARING_SPEC.md → "CloudKit layout".
///
/// The owner keeps the space in a custom zone in their private database and shares the whole zone.
/// Members see the same zone in their shared database. The data is tiny (a few people, a few
/// dozen reminders), so every refresh simply reads the whole zone.
struct SharingCloud {
    static let containerID = "iCloud.com.erijako.onestep"

    let container = CKContainer(identifier: SharingCloud.containerID)

    enum RecordType {
        static let space = "Space"
        static let member = "Member"
        static let reminder = "Reminder"
    }

    enum CloudError: LocalizedError {
        case noAccount
        case alreadyInSpace(String)
        case noShare

        var errorDescription: String? {
            switch self {
            case .noAccount:
                String(localized: "Sharing works through iCloud. Sign in to iCloud in the Settings app, then try again.")
            case .alreadyInSpace(let name):
                String(localized: "You're already in \(name). Leave it first to join this one.")
            case .noShare:
                String(localized: "Couldn't make an invite link right now. Try again in a moment.")
            }
        }
    }

    // MARK: Account

    func requireAccount() async throws {
        guard try await container.accountStatus() == .available else { throw CloudError.noAccount }
    }

    /// Stable id for this person in this container, the same on all their devices.
    func myUserID() async throws -> String {
        try await container.userRecordID().recordName
    }

    func database(ownedByMe: Bool) -> CKDatabase {
        ownedByMe ? container.privateCloudDatabase : container.sharedCloudDatabase
    }

    // MARK: Space

    /// Creates the zone, the space, your member record and the zone-wide share.
    func createSpace(_ space: SharedSpace, me: SpaceMember) async throws -> CKRecordZone.ID {
        let zone = CKRecordZone(zoneName: "Space-\(UUID().uuidString)")
        let db = container.privateCloudDatabase
        let zoneResults = try await db.modifyRecordZones(saving: [zone], deleting: [])
        for (_, result) in zoneResults.saveResults { _ = try result.get() }
        // Records and share in one batch so a half-made space never exists.

        let share = CKShare(recordZoneID: zone.zoneID)
        share[CKShare.SystemFieldKey.title] = space.name as CKRecordValue
        share.publicPermission = .none
        try await save([
            Self.record(space, zone: zone.zoneID),
            Self.record(me, zone: zone.zoneID),
            share,
        ], in: db)
        return zone.zoneID
    }

    /// The zone-wide share, for the invite sheet (owner only).
    func share(in zoneID: CKRecordZone.ID) async throws -> CKShare {
        let id = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        guard let share = try await container.privateCloudDatabase.record(for: id) as? CKShare else {
            throw CloudError.noShare
        }
        return share
    }

    /// Accepts an invite link so the zone shows up in your shared database.
    func accept(_ metadata: CKShare.Metadata) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
            var failure: Error?
            operation.perShareResultBlock = { _, result in
                if case .failure(let error) = result { failure = error }
            }
            operation.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    if let failure { continuation.resume(throwing: failure) } else { continuation.resume() }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            container.add(operation)
        }
    }

    /// Owner: deletes the zone (ends the space for everyone). Member: removes your member record
    /// and yourself from the share. Errors are ignored: leaving should always work locally.
    func leave(zoneID: CKRecordZone.ID, ownedByMe: Bool, memberRecordName: String) async {
        if ownedByMe {
            _ = try? await container.privateCloudDatabase.modifyRecordZones(saving: [], deleting: [zoneID])
        } else {
            let db = container.sharedCloudDatabase
            let member = CKRecord.ID(recordName: memberRecordName, zoneID: zoneID)
            let share = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
            _ = try? await db.modifyRecords(saving: [], deleting: [member])
            _ = try? await db.modifyRecords(saving: [], deleting: [share])
        }
    }

    // MARK: Reading and writing

    /// Every record in the zone (the share itself left out).
    func fetchAll(zoneID: CKRecordZone.ID, ownedByMe: Bool) async throws -> [CKRecord] {
        let db = database(ownedByMe: ownedByMe)
        var token: CKServerChangeToken?
        var records: [CKRecord] = []
        var moreComing = true
        while moreComing {
            let changes = try await db.recordZoneChanges(inZoneWith: zoneID, since: token)
            for (_, result) in changes.modificationResultsByID {
                if case .success(let modification) = result, !(modification.record is CKShare) {
                    records.append(modification.record)
                }
            }
            token = changes.changeToken
            moreComing = changes.moreComing
        }
        return records
    }

    /// Saves records, overwriting the server copy. Throws the first per-record error.
    func save(_ records: [CKRecord], in db: CKDatabase) async throws {
        guard !records.isEmpty else { return }
        let results = try await db.modifyRecords(saving: records, deleting: [], savePolicy: .allKeys)
        // In an atomic batch every record fails, but only one carries the real reason; the rest say
        // "batch request failed". Throw the real one so the message means something.
        var errors: [Error] = []
        for (_, result) in results.saveResults {
            if case .failure(let error) = result { errors.append(error) }
        }
        if let real = errors.first(where: { ($0 as? CKError)?.code != .batchRequestFailed }) ?? errors.first {
            throw real
        }
    }

    /// A kind, readable message for an iCloud error, with a short code for troubleshooting.
    static func message(for error: Error) -> String {
        if let cloud = error as? CloudError { return cloud.localizedDescription }
        guard let ck = error as? CKError else { return error.localizedDescription }
        let detail = ck.localizedDescription.lowercased()
        let code = "CK\(ck.code.rawValue)"
        switch ck.code {
        case .notAuthenticated:
            return CloudError.noAccount.localizedDescription
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return String(localized: "iCloud isn't answering right now. Check your connection and try again in a moment. (\(code))")
        case .quotaExceeded:
            return String(localized: "Your iCloud storage is full, so sharing can't save. (\(code))")
        default:
            if detail.contains("type") || ck.code == .serverRejectedRequest || ck.code == .invalidArguments {
                return String(localized: "Sharing isn't set up in iCloud yet. The record types need to be deployed in CloudKit Console. (\(code))")
            }
            return String(localized: "Something went wrong with iCloud. Try again in a moment. (\(code))")
        }
    }

    /// Silent pushes when anything in the space changes, so the app can refresh in the background.
    func subscribe(zoneID: CKRecordZone.ID, ownedByMe: Bool) async {
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        let subscription: CKSubscription
        if ownedByMe {
            let zoneSubscription = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: "space-\(zoneID.zoneName)")
            zoneSubscription.notificationInfo = info
            subscription = zoneSubscription
        } else {
            let databaseSubscription = CKDatabaseSubscription(subscriptionID: "shared-database")
            databaseSubscription.notificationInfo = info
            subscription = databaseSubscription
        }
        _ = try? await database(ownedByMe: ownedByMe).modifySubscriptions(saving: [subscription], deleting: [])
    }

    /// True when the space no longer exists for you (owner closed it, or you left elsewhere).
    static func isGone(_ error: Error) -> Bool {
        guard let error = error as? CKError else { return false }
        return [.zoneNotFound, .userDeletedZone, .unknownItem].contains(error.code)
    }

    // MARK: Records <-> models

    static func memberRecordName(_ id: String) -> String { "member-\(id)" }

    static func record(_ space: SharedSpace, zone: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(recordType: RecordType.space, recordID: CKRecord.ID(recordName: "space", zoneID: zone))
        record["spaceName"] = space.name
        record["ownerID"] = space.ownerID
        return record
    }

    static func record(_ member: SpaceMember, zone: CKRecordZone.ID) -> CKRecord {
        let id = CKRecord.ID(recordName: memberRecordName(member.id), zoneID: zone)
        let record = CKRecord(recordType: RecordType.member, recordID: id)
        record["displayName"] = member.displayName
        record["colorIndex"] = Int64(member.colorIndex)
        record["joinedAt"] = member.joinedAt
        return record
    }

    static func record(_ reminder: SharedReminder, zone: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(recordType: RecordType.reminder, recordID: CKRecord.ID(recordName: reminder.id, zoneID: zone))
        record["title"] = reminder.title
        record["note"] = reminder.note
        record["senderID"] = reminder.senderID
        record["recipientID"] = reminder.recipientID
        record["showAt"] = reminder.showAt
        record["state"] = reminder.state.rawValue
        record["createdAt"] = reminder.createdAt
        record["answeredAt"] = reminder.answeredAt
        return record
    }

    static func space(from record: CKRecord) -> SharedSpace? {
        guard let name = record["spaceName"] as? String, let owner = record["ownerID"] as? String else { return nil }
        return SharedSpace(name: name, ownerID: owner)
    }

    static func member(from record: CKRecord) -> SpaceMember? {
        let prefix = "member-"
        let name = record.recordID.recordName
        guard name.hasPrefix(prefix), let displayName = record["displayName"] as? String else { return nil }
        return SpaceMember(
            id: String(name.dropFirst(prefix.count)),
            displayName: displayName,
            colorIndex: Int(record["colorIndex"] as? Int64 ?? 0),
            joinedAt: record["joinedAt"] as? Date ?? record.creationDate ?? .now
        )
    }

    static func reminder(from record: CKRecord) -> SharedReminder? {
        guard let title = record["title"] as? String,
              let sender = record["senderID"] as? String,
              let recipient = record["recipientID"] as? String else { return nil }
        return SharedReminder(
            id: record.recordID.recordName,
            title: title,
            note: record["note"] as? String ?? "",
            senderID: sender,
            recipientID: recipient,
            showAt: record["showAt"] as? Date ?? .now,
            state: ReminderState(rawValue: record["state"] as? String ?? "") ?? .sent,
            createdAt: record["createdAt"] as? Date ?? record.creationDate ?? .now,
            answeredAt: record["answeredAt"] as? Date
        )
    }
}

// MARK: - Invites and incoming share links

/// Holds an invite link the person just tapped, until the join screen (S2) handles it.
@MainActor
@Observable
final class ShareInbox {
    static let shared = ShareInbox()
    var pending: CKShare.Metadata?
}

/// Opens Apple's sharing sheet for the space (Messages, Mail, copy link…).
@MainActor
enum InvitePresenter {
    private static let delegate = InviteDelegate()

    static func present(share: CKShare, container: CKContainer, title: String, onDone: @escaping () -> Void) {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        delegate.title = title
        delegate.onDone = onDone
        controller.delegate = delegate
        topViewController()?.present(controller, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

private final class InviteDelegate: NSObject, UICloudSharingControllerDelegate {
    var title = ""
    var onDone: () -> Void = {}

    func itemTitle(for csc: UICloudSharingController) -> String? { title }

    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        onDone()
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) { onDone() }
    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) { onDone() }
}

/// Receives silent CloudKit pushes and routes the scene delegate (for invite links).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        await SharingStore.current?.refresh()
        return .newData
    }
}

/// Catches tapped iCloud invite links, on cold launch and while running.
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            Task { @MainActor in ShareInbox.shared.pending = metadata }
        }
    }

    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Task { @MainActor in ShareInbox.shared.pending = cloudKitShareMetadata }
    }
}
