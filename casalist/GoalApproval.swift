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

    /// Approve: strip the PENDING: prefix, (optionally) set the price,
    /// mark the goal as redeemed (so it surfaces in Recently Redeemed),
    /// and debit the requester's spendable wallet (`member.points`).
    ///
    /// IMPORTANT: lifetime/season points are **not** touched, so the
    /// leaderboard standing the requester earned is preserved — only
    /// their usable wallet drops. If they spent everything, wallet
    /// floors at 0; the leaderboard number stays.
    ///
    /// `context` is required to look up the requester FamilyMember
    /// scoped to the goal's household. Caller saves the context.
    static func approve(
        _ g: FamilyGoal,
        targetPoints: Int? = nil,
        in context: NSManagedObjectContext
    ) {
        guard isPending(g) else { return }
        let realOwner = realOwnerName(g)
        g.ownerName = realOwner
        if let tp = targetPoints {
            g.targetPoints = Int64(max(1, tp))
        }
        // Mark as redeemed so the redemption appears in the
        // "Recently Redeemed" / inbox feed.
        g.isRedeemed = true
        g.redeemedAt = Date()
        // Debit the requester's spendable wallet, scoped to the goal's
        // household so name collisions across households can't cross-debit.
        if let member = requesterMember(for: g, realOwner: realOwner, in: context) {
            let cost = g.targetPoints
            member.points = max(0, member.points - cost)
        }
    }

    /// Look up the FamilyMember who requested this goal — same household,
    /// case-insensitive name match. Returns nil if the requester record
    /// can't be found (e.g. renamed/deleted after requesting).
    private static func requesterMember(
        for goal: FamilyGoal,
        realOwner: String,
        in context: NSManagedObjectContext
    ) -> FamilyMember? {
        let req: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
        let trimmed = realOwner.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if let household = goal.household {
            req.predicate = NSPredicate(
                format: "name ==[c] %@ AND deletedAt == nil AND household == %@",
                trimmed, household
            )
        } else {
            req.predicate = NSPredicate(
                format: "name ==[c] %@ AND deletedAt == nil",
                trimmed
            )
        }
        req.fetchLimit = 1
        return (try? context.fetch(req))?.first
    }

    /// Redeem an already-approved goal: marks it redeemed (so it appears
    /// in Recently Redeemed) and debits the requester's spendable wallet.
    /// Lifetime/season points untouched — leaderboard standing preserved.
    /// Idempotent: no-op if the goal is already redeemed or still pending
    /// approval. Caller saves the context.
    ///
    /// Use this for the "Redeem from inbox" admin shortcut on legacy
    /// goals that were approved before approve = redeem went in, or any
    /// other explicit one-tap redeem path.
    static func redeem(_ g: FamilyGoal, in context: NSManagedObjectContext) {
        guard !isPending(g), !g.isRedeemed else { return }
        g.isRedeemed = true
        g.redeemedAt = Date()
        if let member = requesterMember(for: g, realOwner: g.ownerName, in: context) {
            let cost = g.targetPoints
            member.points = max(0, member.points - cost)
        }
    }

    /// Deny: soft-delete the record (goes to Trash). Caller saves the context.
    static func deny(_ g: FamilyGoal, in context: NSManagedObjectContext) {
        g.softDelete()
    }
}
