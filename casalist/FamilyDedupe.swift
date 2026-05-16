import Foundation
import CoreData

/// Dedupes FamilyMember records. Identity is keyed on `cloudKitUserID`
/// (the iCloud user record ID), which is stable across reinstalls, device
/// changes, and name changes. Two records with the same cloudKitUserID are
/// the same person; merge them. Two records with the same NAME but
/// different cloudKitUserIDs are different people (e.g. two siblings both
/// named Dakoda); leave them alone.
///
/// Legacy fallback: records created before the `cloudKitUserID` field
/// existed have an empty string in that field. For those, we still try to
/// dedupe by name + `meUid` match (the old logic) so a single in-flight
/// upgrade doesn't strand the user.
///
/// All passes are idempotent — running them repeatedly is a no-op once
/// dupes are gone.
enum FamilyDedupe {
    /// Merge any FamilyMember records that share a cloudKitUserID. Survivor
    /// preference: shared-store > older createdAt. Returns soft-deletes
    /// count. The dropped record's photo/points/role get transferred onto
    /// the survivor when relevant.
    @discardableResult
    static func mergeByCloudKitUserID(in context: NSManagedObjectContext) -> Int {
        let req: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
        req.predicate = NSPredicate(format: "deletedAt == nil AND cloudKitUserID != nil AND cloudKitUserID != ''")
        let all = (try? context.fetch(req)) ?? []

        var groups: [String: [FamilyMember]] = [:]
        for m in all where !m.userID.isEmpty {
            groups[m.userID, default: []].append(m)
        }

        let sharedStore = CasaCoreDataStack.shared.sharedStore
        let priority: [String: Int] = ["owner": 3, "admin": 2, "standard": 1, "kid": 0]
        var removed = 0
        for (id, group) in groups where group.count > 1 {
            let survivor = group.max(by: { a, b in
                let aShared = a.objectID.persistentStore === sharedStore
                let bShared = b.objectID.persistentStore === sharedStore
                if aShared != bShared { return !aShared && bShared }
                return a.createdAt > b.createdAt
            })!
            for m in group where m !== survivor {
                if survivor.photoBlob == nil, let blob = m.photoBlob, !blob.isEmpty {
                    survivor.photoBlob = blob
                }
                if m.points > survivor.points { survivor.points = m.points }
                let sPri = priority[survivor.roleLevel] ?? 1
                let mPri = priority[m.roleLevel] ?? 1
                if mPri > sPri { survivor.roleLevel = m.roleLevel }
                m.softDelete()
                removed += 1
            }
            CasalistAppDelegate.appendShareLog("mergeByCloudKitUserID: id=\(id.prefix(12))… \(group.count) → 1 (\(group.count - 1) deleted)")
        }
        if removed > 0 { try? context.save() }
        return removed
    }

    /// Merges same-name members in the same household when AT LEAST ONE
    /// has a stamped cloudKitUserID. Bridge for mixed-state data: legacy
    /// records (empty cloudKitUserID) that sync down after a reinstall
    /// would otherwise sit alongside the fresh stamped record forever
    /// because mergeByCloudKitUserID treats empty and stamped IDs as
    /// different identities. This collapses them, keeping the stamped
    /// one as survivor (which is the live "me" record).
    /// NON-DESTRUCTIVE bridge. For each same-name + same-household pair
    /// where exactly one record has a stamped cloudKitUserID, COPY the
    /// stamped ID onto the legacy record. This unifies their identity
    /// without soft-deleting either one. The next `mergeByCloudKitUserID`
    /// pass will then see them as the same person and collapse them
    /// deterministically — same survivor on every device, no soft-delete
    /// cycle where Device A delete syncs to Device B which restores it
    /// which syncs back to Device A.
    @discardableResult
    static func mergeLegacyNameDupes(in context: NSManagedObjectContext) -> Int {
        let req: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
        req.predicate = NSPredicate(format: "deletedAt == nil")
        let all = (try? context.fetch(req)) ?? []

        var groups: [String: [FamilyMember]] = [:]
        for m in all {
            let hid = m.household?.uid.uuidString ?? "_none"
            let key = "\(hid)|\(m.name.trimmingCharacters(in: .whitespaces).lowercased())"
            groups[key, default: []].append(m)
        }

        var stamped = 0
        for (_, group) in groups where group.count > 1 {
            let withId = group.filter { !$0.userID.isEmpty }
            let withoutId = group.filter { $0.userID.isEmpty }
            // Need at least one stamped to know what ID to assign. If all
            // unstamped, leave alone — possibly truly different people we
            // can't disambiguate yet.
            guard let first = withId.first, !first.userID.isEmpty, !withoutId.isEmpty else { continue }
            let id = first.userID
            for m in withoutId {
                m.cloudKitUserID = id
                stamped += 1
            }
            CasalistAppDelegate.appendShareLog("mergeLegacyNameDupes: name=\(group.first?.name ?? "?") stamped \(withoutId.count) legacy record(s) with id=\(id.prefix(12))…")
        }
        if stamped > 0 {
            try? context.save()
            // Now that legacy records have IDs, deterministic merge collapses them.
            mergeByCloudKitUserID(in: context)
        }
        return stamped
    }

    /// LEGACY fallback. Same as before — merges same-name dupes for the
    /// current user's typed name when at least one record matches the
    /// legacy `meUid` UserDefaults claim. Only fires for records that
    /// haven't been backfilled with a cloudKitUserID yet.
    @discardableResult
    static func mergeDuplicateMeRecords(in context: NSManagedObjectContext, userName: String) -> Int {
        let trimmed = userName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return 0 }
        let lc = trimmed.lowercased()

        let req: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
        req.predicate = NSPredicate(format: "name LIKE[c] %@ AND deletedAt == nil AND (cloudKitUserID == nil OR cloudKitUserID == '')", lc)
        let matches = (try? context.fetch(req)) ?? []
        guard matches.count > 1 else { return 0 }

        let meUid = UserDefaults.standard.string(forKey: "meUid") ?? ""
        let myDupeExists = matches.contains { $0.uid.uuidString == meUid }
        guard myDupeExists || meUid.isEmpty else { return 0 }

        let sharedStore = CasaCoreDataStack.shared.sharedStore
        let priority: [String: Int] = ["owner": 3, "admin": 2, "standard": 1, "kid": 0]
        guard let survivor = matches.max(by: { a, b in
            let aShared = a.objectID.persistentStore === sharedStore
            let bShared = b.objectID.persistentStore === sharedStore
            if aShared != bShared { return !aShared && bShared }
            return a.createdAt > b.createdAt
        }) else { return 0 }

        var removed = 0
        for m in matches where m !== survivor {
            if survivor.photoBlob == nil, let blob = m.photoBlob, !blob.isEmpty {
                survivor.photoBlob = blob
            }
            if m.points > survivor.points { survivor.points = m.points }
            let sPri = priority[survivor.roleLevel] ?? 1
            let mPri = priority[m.roleLevel] ?? 1
            if mPri > sPri { survivor.roleLevel = m.roleLevel }
            m.softDelete()
            removed += 1
        }

        UserDefaults.standard.set(survivor.uid.uuidString, forKey: "meUid")
        try? context.save()
        CasalistAppDelegate.appendShareLog("mergeDuplicateMeRecords[\(trimmed)]: legacy fallback, removed \(removed)")
        return removed
    }
}
