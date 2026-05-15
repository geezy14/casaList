import Foundation
import CoreData

/// Encodes "needs parent approval" state in the existing `ownerName` field
/// using a `PENDING:` prefix — avoids a CloudKit schema redeploy.
///
/// A goal where ownerName starts with "PENDING:" is awaiting approval.
/// Approve = strip the prefix. Deny = delete the record.
enum GoalApproval {
    static let pendingPrefix = "PENDING:"

    static func isPending(_ g: FamilyGoal) -> Bool {
        g.ownerName.hasPrefix(pendingPrefix)
    }

    /// The "real" intended owner — strips the PENDING: prefix if present.
    static func realOwnerName(_ g: FamilyGoal) -> String {
        if g.ownerName.hasPrefix(pendingPrefix) {
            return String(g.ownerName.dropFirst(pendingPrefix.count))
        }
        return g.ownerName
    }

    /// Compose an ownerName that signals "pending approval".
    static func makePendingOwnerName(_ realName: String) -> String {
        pendingPrefix + realName
    }

    /// Approve: strip the prefix in place. Caller saves the context.
    static func approve(_ g: FamilyGoal) {
        guard isPending(g) else { return }
        g.ownerName = realOwnerName(g)
    }

    /// Deny: soft-delete the record (goes to Trash). Caller saves the context.
    static func deny(_ g: FamilyGoal, in context: NSManagedObjectContext) {
        g.softDelete()
    }
}
