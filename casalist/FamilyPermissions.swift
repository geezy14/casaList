import Foundation
import SwiftUI
import CoreData

enum FamilyPermissions {
    static func currentMember<S: Sequence>(members: S, userName: String, meUid: String) -> FamilyMember?
    where S.Element == FamilyMember {
        if !meUid.isEmpty, let u = UUID(uuidString: meUid),
           let m = members.first(where: { $0.uid == u && $0.deletedAt == nil }) {
            return m
        }
        let trimmed = userName.trimmingCharacters(in: .whitespaces).lowercased()
        if !trimmed.isEmpty,
           let m = members.first(where: { $0.name.lowercased() == trimmed }) {
            return m
        }
        return nil
    }

    /// Make the local user the household owner — but only if it's safe:
    /// (a) we don't already have an owner, (b) our FamilyMember exists in
    /// a household that lives in OUR private store (i.e. we created the
    /// share, we're not a joiner), and (c) the matching member is local.
    ///
    /// Previously this just promoted "the oldest member" to owner, which
    /// caused a race on fresh installs: a joiner's record could arrive via
    /// CloudKit before the local user existed, and the helper would
    /// silently make the joiner owner. That's gone.
    static func ensureOwner<S: Sequence>(
        members: S,
        context: NSManagedObjectContext,
        userName: String,
        meUid: String
    ) where S.Element == FamilyMember {
        let array = Array(members)
        // Already have an owner? Leave it alone.
        guard !array.contains(where: { $0.level == .owner }) else { return }
        // Find our own member.
        guard let me = currentMember(members: array, userName: userName, meUid: meUid) else { return }
        // Only the household-owning device can grant owner status.
        let stack = CasaCoreDataStack.shared
        guard let household = me.household,
              household.objectID.persistentStore == stack.privateStore else { return }
        me.roleLevel = FamilyRole.owner.rawValue
        try? context.save()
    }

    static func adminCount<S: Sequence>(in members: S) -> Int
    where S.Element == FamilyMember {
        members.filter { $0.level == .admin }.count
    }
}
