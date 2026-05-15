import Foundation
import CoreData

/// Merges duplicate FamilyMember records for the current user. The classic
/// trigger: reinstall the app, type your name → app creates a local
/// FamilyMember while CloudKit is still fetching → the original
/// FamilyMember syncs down minutes later → now there are two same-name
/// "me" records in the family list.
///
/// This helper finds same-name members, keeps the OLDEST (typically the
/// CloudKit-synced original with the photo + history), transfers any
/// non-null state from newer dupes onto the survivor, soft-deletes the
/// rest, and re-claims `meUid` so the user keeps their identity on the
/// survivor.
///
/// Conservative on purpose:
///   - Only merges same-name members where AT LEAST one is claimed as
///     `meUid` OR `meUid` is empty. Two real different family members
///     who happen to share a name aren't merged unintentionally.
///   - Operates only on live records (deletedAt == nil).
///   - Idempotent — running repeatedly is a no-op once dupes are gone.
enum FamilyDedupe {
    /// Returns the number of records that got soft-deleted in this pass.
    @discardableResult
    static func mergeDuplicateMeRecords(in context: NSManagedObjectContext, userName: String) -> Int {
        let trimmed = userName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return 0 }
        let lc = trimmed.lowercased()

        let req: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
        req.predicate = NSPredicate(format: "name LIKE[c] %@ AND deletedAt == nil", lc)
        let matches = (try? context.fetch(req)) ?? []
        guard matches.count > 1 else { return 0 }

        let meUid = UserDefaults.standard.string(forKey: "meUid") ?? ""
        let myDupeExists = matches.contains { $0.uid.uuidString == meUid }
        // Don't merge two unrelated same-name members unless we're cleaning
        // up the user's own dupes.
        guard myDupeExists || meUid.isEmpty else { return 0 }

        // Keep the OLDEST record (lower createdAt). That's typically the
        // original from before reinstall, not the local placeholder.
        guard let survivor = matches.min(by: { $0.createdAt < $1.createdAt }) else { return 0 }

        var removed = 0
        for m in matches where m !== survivor {
            // Pull useful state forward onto the survivor when the survivor
            // is missing it. Photo, points, roleLevel — preserve the
            // record with the richest history.
            if survivor.photoBlob == nil, let blob = m.photoBlob, !blob.isEmpty {
                survivor.photoBlob = blob
            }
            if m.points > survivor.points {
                survivor.points = m.points
            }
            // Don't downgrade the survivor's role.
            let priority: [String: Int] = ["owner": 3, "admin": 2, "standard": 1, "kid": 0]
            let sPri = priority[survivor.roleLevel] ?? 1
            let mPri = priority[m.roleLevel] ?? 1
            if mPri > sPri {
                survivor.roleLevel = m.roleLevel
            }
            m.softDelete()
            removed += 1
        }

        // Re-claim meUid to the survivor so the user keeps their identity.
        UserDefaults.standard.set(survivor.uid.uuidString, forKey: "meUid")
        try? context.save()
        return removed
    }
}
