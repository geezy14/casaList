import Foundation
import CoreData
import SwiftUI
import UIKit

// MARK: – Snapshot Codable model

/// A versioned point-in-time snapshot of every household, family member,
/// task, goal, and event the device knows about. Written as JSON to the
/// app's iCloud Drive folder so the user (or a future install) can recover
/// the data even if CloudKit is mid-tantrum.
struct CasalistBackup: Codable {
    /// Bump if/when the on-disk schema changes. Reader rejects newer than
    /// it understands.
    static let currentVersion = 1

    var version: Int = currentVersion
    var generatedAt: Date = Date()
    var deviceName: String = ""
    var households: [HouseholdSnapshot] = []
    var members: [MemberSnapshot] = []
    var tasks: [TaskSnapshot] = []
    var goals: [GoalSnapshot] = []
    var events: [EventSnapshot] = []

    struct HouseholdSnapshot: Codable {
        var uid: UUID
        var name: String
        var createdAt: Date
        var deletedAt: Date?
    }
    struct MemberSnapshot: Codable {
        var uid: UUID
        var name: String
        var role: String
        var colorHex: Int64
        var points: Int64
        var createdAt: Date
        var roleLevel: String
        var photoBlob: Data?
        var deletedAt: Date?
        var householdUid: UUID?
    }
    struct TaskSnapshot: Codable {
        var uid: String
        var task: String
        var assignee: String?
        var dueDate: Date?
        var category: String
        var isCompleted: Bool
        var points: Int64
        var createdAt: Date
        var createdBy: String
        var repeatHours: Int64
        var repeatKind: String
        var completionCount: Int64
        var parentUid: String
        var deletedAt: Date?
        var householdUid: UUID?
    }
    struct GoalSnapshot: Codable {
        var uid: UUID
        var ownerName: String
        var label: String
        var targetPoints: Int64
        var createdAt: Date
        var isRedeemed: Bool
        var redeemedAt: Date?
        var deletedAt: Date?
        var householdUid: UUID?
    }
    struct EventSnapshot: Codable {
        var uid: UUID
        var title: String
        var startDate: Date
        var isAllDay: Bool
        var location: String
        var latitude: Double
        var longitude: Double
        var attendees: String
        var notes: String
        var repeatKind: String
        var createdAt: Date
        var createdBy: String
        var deletedAt: Date?
        var householdUid: UUID?
    }
}

// MARK: – Encoder/Decoder

enum BackupEncoder {
    static func snapshot(from context: NSManagedObjectContext) -> CasalistBackup {
        var b = CasalistBackup()
        b.deviceName = UIDevice.current.name
        let households = (try? context.fetch(Household.fetchRequest())) ?? []
        b.households = households.map { h in
            CasalistBackup.HouseholdSnapshot(
                uid: h.uid, name: h.name, createdAt: h.createdAt, deletedAt: h.deletedAt
            )
        }
        let members = (try? context.fetch(FamilyMember.fetchRequest())) ?? []
        b.members = members.map { m in
            CasalistBackup.MemberSnapshot(
                uid: m.uid, name: m.name, role: m.role, colorHex: m.colorHex,
                points: m.points, createdAt: m.createdAt, roleLevel: m.roleLevel,
                photoBlob: m.photoBlob, deletedAt: m.deletedAt,
                householdUid: m.household?.uid
            )
        }
        let tasks = (try? context.fetch(TaskItem.fetchRequest())) ?? []
        b.tasks = tasks.map { t in
            CasalistBackup.TaskSnapshot(
                uid: t.uid, task: t.task, assignee: t.assignee, dueDate: t.dueDate,
                category: t.category, isCompleted: t.isCompleted, points: t.points,
                createdAt: t.createdAt, createdBy: t.createdBy, repeatHours: t.repeatHours,
                repeatKind: t.repeatKind, completionCount: t.completionCount,
                parentUid: t.parentUid, deletedAt: t.deletedAt,
                householdUid: t.household?.uid
            )
        }
        let goals = (try? context.fetch(FamilyGoal.fetchRequest())) ?? []
        b.goals = goals.map { g in
            CasalistBackup.GoalSnapshot(
                uid: g.uid, ownerName: g.ownerName, label: g.label,
                targetPoints: g.targetPoints, createdAt: g.createdAt,
                isRedeemed: g.isRedeemed, redeemedAt: g.redeemedAt,
                deletedAt: g.deletedAt, householdUid: g.household?.uid
            )
        }
        let events = (try? context.fetch(FamilyEvent.fetchRequest())) ?? []
        b.events = events.map { e in
            CasalistBackup.EventSnapshot(
                uid: e.uid, title: e.title, startDate: e.startDate, isAllDay: e.isAllDay,
                location: e.location, latitude: e.latitude, longitude: e.longitude,
                attendees: e.attendees, notes: e.notes, repeatKind: e.repeatKind,
                createdAt: e.createdAt, createdBy: e.createdBy, deletedAt: e.deletedAt,
                householdUid: e.household?.uid
            )
        }
        return b
    }
}

enum BackupDecoder {
    /// Additive restore — only inserts records whose uid isn't already in
    /// the store. Doesn't touch existing records. Returns count inserted.
    @discardableResult
    static func restore(_ backup: CasalistBackup, into context: NSManagedObjectContext) -> Int {
        var inserted = 0
        let stack = CasaCoreDataStack.shared
        // Index existing uids per entity for fast existence check.
        let existingHouseholdUids: Set<UUID> = {
            let req = Household.fetchRequest()
            return Set(((try? context.fetch(req)) ?? []).map { $0.uid })
        }()
        let existingMemberUids: Set<UUID> = {
            let req = FamilyMember.fetchRequest()
            return Set(((try? context.fetch(req)) ?? []).map { $0.uid })
        }()
        let existingTaskUids: Set<String> = {
            let req = TaskItem.fetchRequest()
            return Set(((try? context.fetch(req)) ?? []).map { $0.uid })
        }()
        let existingGoalUids: Set<UUID> = {
            let req = FamilyGoal.fetchRequest()
            return Set(((try? context.fetch(req)) ?? []).map { $0.uid })
        }()
        let existingEventUids: Set<UUID> = {
            let req = FamilyEvent.fetchRequest()
            return Set(((try? context.fetch(req)) ?? []).map { $0.uid })
        }()

        // Households first so the relationships can resolve.
        for h in backup.households where !existingHouseholdUids.contains(h.uid) {
            guard let entity = NSEntityDescription.entity(forEntityName: "Household", in: context) else { continue }
            let obj = Household(entity: entity, insertInto: context)
            obj.uid = h.uid
            obj.name = h.name
            obj.createdAt = h.createdAt
            obj.deletedAt = h.deletedAt
            if let priv = stack.privateStore { context.assign(obj, to: priv) }
            inserted += 1
        }
        // Snapshot of households AFTER inserts for relationship lookup.
        let allHouseholds = (try? context.fetch(Household.fetchRequest())) ?? []
        func householdForUid(_ uid: UUID?) -> Household? {
            guard let uid else { return nil }
            return allHouseholds.first(where: { $0.uid == uid })
        }

        for m in backup.members where !existingMemberUids.contains(m.uid) {
            let obj = FamilyMember(
                context: context, name: m.name, role: m.role,
                colorHex: Int(m.colorHex), points: Int(m.points),
                photoBlob: nil,
                roleLevel: FamilyRole(rawValue: m.roleLevel) ?? .standard
            )
            obj.uid = m.uid
            obj.createdAt = m.createdAt
            obj.deletedAt = m.deletedAt
            obj.photoBlob = m.photoBlob
            if let h = householdForUid(m.householdUid) {
                context.assign(obj, toStoreOf: h)
                obj.household = h
            }
            inserted += 1
        }
        for t in backup.tasks where !existingTaskUids.contains(t.uid) {
            let obj = TaskItem(
                context: context, task: t.task, assignee: t.assignee, dueDate: t.dueDate,
                category: t.category, isCompleted: t.isCompleted, points: Int(t.points),
                createdBy: t.createdBy, repeatHours: Int(t.repeatHours),
                repeatKind: t.repeatKind, completionCount: Int(t.completionCount),
                uid: t.uid, parentUid: t.parentUid
            )
            obj.createdAt = t.createdAt
            obj.deletedAt = t.deletedAt
            if let h = householdForUid(t.householdUid) {
                context.assign(obj, toStoreOf: h)
                obj.household = h
            }
            inserted += 1
        }
        for g in backup.goals where !existingGoalUids.contains(g.uid) {
            let obj = FamilyGoal(
                context: context, ownerName: g.ownerName, label: g.label,
                targetPoints: Int(g.targetPoints)
            )
            obj.uid = g.uid
            obj.createdAt = g.createdAt
            obj.isRedeemed = g.isRedeemed
            obj.redeemedAt = g.redeemedAt
            obj.deletedAt = g.deletedAt
            if let h = householdForUid(g.householdUid) {
                context.assign(obj, toStoreOf: h)
                obj.household = h
            }
            inserted += 1
        }
        for e in backup.events where !existingEventUids.contains(e.uid) {
            let obj = FamilyEvent(
                context: context, title: e.title, startDate: e.startDate,
                isAllDay: e.isAllDay, location: e.location, attendees: e.attendees,
                notes: e.notes, repeatKind: e.repeatKind, createdBy: e.createdBy
            )
            obj.uid = e.uid
            obj.createdAt = e.createdAt
            obj.latitude = e.latitude
            obj.longitude = e.longitude
            obj.deletedAt = e.deletedAt
            if let h = householdForUid(e.householdUid) {
                context.assign(obj, toStoreOf: h)
                obj.household = h
            }
            inserted += 1
        }
        try? context.save()
        return inserted
    }
}

// MARK: – iCloud Drive snapshot orchestration

/// Manages writing JSON snapshots to the app's iCloud Drive ubiquity
/// container, rotating older ones, and exposing status.
enum CloudBackup {
    static let containerID = casalistCloudKitContainerID
    static let folderName = "Backups"
    static let fileExtension = "casabackup"
    /// Keep up to this many snapshots; older ones get pruned.
    static let maxSnapshots = 14
    /// Auto-snapshot frequency.
    static let interval: TimeInterval = 24 * 60 * 60

    /// `nil` if the device isn't signed into iCloud or the container isn't
    /// available yet. App should hide / show "iCloud unavailable" copy when
    /// this is nil.
    static var documentsURL: URL? {
        guard let base = FileManager.default.url(forUbiquityContainerIdentifier: containerID) else {
            return nil
        }
        let url = base.appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var isAvailable: Bool { documentsURL != nil }

    /// Lists existing snapshots, newest first.
    static func listSnapshots() -> [URL] {
        guard let dir = documentsURL else { return [] }
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [])) ?? []
        return files
            .filter { $0.pathExtension == fileExtension }
            .sorted { a, b in
                let aD = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let bD = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return aD > bD
            }
    }

    static var lastSnapshotDate: Date? {
        guard let first = listSnapshots().first else { return nil }
        return (try? first.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? nil
    }

    /// Whether a fresh snapshot is due (interval has elapsed since last one).
    static var isDue: Bool {
        guard let last = lastSnapshotDate else { return true }
        return Date().timeIntervalSince(last) >= interval
    }

    /// Build a JSON snapshot of the current context and write it to iCloud
    /// Drive. Rotates older snapshots beyond `maxSnapshots`.
    @discardableResult
    static func snapshot(in context: NSManagedObjectContext) -> Result<URL, BackupError> {
        guard let dir = documentsURL else { return .failure(.iCloudUnavailable) }
        let backup = BackupEncoder.snapshot(from: context)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(backup) else { return .failure(.encodeFailed) }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd'T'HHmmss"
        let name = "casalist-\(fmt.string(from: backup.generatedAt)).\(fileExtension)"
        let url = dir.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return .failure(.writeFailed(error))
        }
        rotate()
        return .success(url)
    }

    /// Loads a snapshot from disk and restores it (additive — non-destructive).
    static func restore(from fileURL: URL, into context: NSManagedObjectContext) -> Result<Int, BackupError> {
        guard let data = try? Data(contentsOf: fileURL) else { return .failure(.readFailed) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(CasalistBackup.self, from: data) else {
            return .failure(.decodeFailed)
        }
        guard backup.version <= CasalistBackup.currentVersion else {
            return .failure(.versionMismatch(backup.version))
        }
        let n = BackupDecoder.restore(backup, into: context)
        return .success(n)
    }

    private static func rotate() {
        let snaps = listSnapshots()
        guard snaps.count > maxSnapshots else { return }
        for url in snaps.dropFirst(maxSnapshots) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    enum BackupError: Error {
        case iCloudUnavailable
        case encodeFailed
        case decodeFailed
        case writeFailed(Error)
        case readFailed
        case versionMismatch(Int)

        var message: String {
            switch self {
            case .iCloudUnavailable: return "iCloud Drive isn't available. Make sure you're signed in."
            case .encodeFailed:      return "Couldn't encode the snapshot."
            case .decodeFailed:      return "Couldn't read the backup file."
            case .writeFailed(let e): return "Couldn't write to iCloud Drive: \(e.localizedDescription)"
            case .readFailed:        return "Couldn't read the backup file."
            case .versionMismatch(let v): return "Backup version \(v) is newer than this app understands. Update the app."
            }
        }
    }
}
