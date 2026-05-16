import Foundation
import CoreData
import CloudKit

/// Identity layer for FamilyMember records, keyed by CloudKit user record ID
/// rather than typed name. The user record ID is stable across:
///   • App reinstalls
///   • Device changes
///   • iCloud account-level changes (within the same Apple ID)
///   • The user changing their displayed name
///
/// Using it as the identity key eliminates the whole class of name-collision
/// bugs (two "Dakoda" records when there are two real Dakodas; one "Dakoda"
/// reused across two different people; "owner" role bleeding across
/// pre-share local placeholders).
///
/// Old records that synced down before this field existed have an empty
/// `cloudKitUserID`. They get backfilled on next foreground if their `uid`
/// matches the legacy `meUid` UserDefaults claim.
enum FamilyIdentity {
    /// Fetch the current iCloud user's record ID. Returns the recordName as
    /// a string (e.g. `_abc123…`) which is what we stamp on FamilyMember.
    /// Cached after first lookup since it's stable per-container per-account.
    private static var cachedUserID: String?

    static func currentUserID(container: CKContainer = CKContainer(identifier: casalistCloudKitContainerID)) async -> String? {
        if let cached = cachedUserID { return cached }
        do {
            let id = try await container.userRecordID()
            let str = id.recordName
            cachedUserID = str
            return str
        } catch {
            CasalistAppDelegate.appendShareLog("FamilyIdentity: currentUserID failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Stamp the given FamilyMember with the current iCloud user's ID, if it
    /// isn't already stamped. Idempotent — running repeatedly is a no-op
    /// once the field is set.
    @MainActor
    static func stampOwnIdentity(on member: FamilyMember, in context: NSManagedObjectContext) async {
        guard member.userID.isEmpty else { return }
        guard let id = await currentUserID() else { return }
        member.cloudKitUserID = id
        try? context.save()
        CasalistAppDelegate.appendShareLog("FamilyIdentity: stamped own ID on \(member.name)")
    }

    /// Stamp a joiner-side FamilyMember with the participant user ID from a
    /// share metadata, if available. The share metadata exposes the
    /// joiner's own userIdentity through `participantUserRecordID` (or
    /// equivalent on the participants collection).
    @MainActor
    static func stampJoinerIdentity(on member: FamilyMember,
                                    from metadata: CKShare.Metadata,
                                    in context: NSManagedObjectContext) {
        guard member.userID.isEmpty else { return }
        // Try the metadata path first. Per Apple Forum reports, the
        // `userIdentity` properties on `currentUserParticipant` can be
        // incomplete at the exact moment of share-accept (nameComponents
        // and userRecordID both observed empty even when accountStatus is
        // .available). Fall back to CKContainer.userRecordID() which is
        // always reliable for the current user.
        if let id = metadata.share.currentUserParticipant?.userIdentity.userRecordID?.recordName,
           !id.isEmpty {
            member.cloudKitUserID = id
            cachedUserID = id
            try? context.save()
            CasalistAppDelegate.appendShareLog("FamilyIdentity: stamped joiner ID on \(member.name) via metadata")
            return
        }
        CasalistAppDelegate.appendShareLog("FamilyIdentity: metadata path empty — falling back to container.userRecordID()")
        Task { @MainActor in
            await stampOwnIdentity(on: member, in: context)
        }
    }

    /// Backfill: assign the current iCloud user's ID to whichever
    /// FamilyMember matches the legacy `meUid` claim, if it has no ID yet.
    /// Lets legacy records created before this field existed gain a stable
    /// identity without re-onboarding.
    @MainActor
    static func backfillSelf(in context: NSManagedObjectContext) async {
        let meUidStr = UserDefaults.standard.string(forKey: "meUid") ?? ""
        guard let meUid = UUID(uuidString: meUidStr) else { return }
        let req: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
        req.predicate = NSPredicate(format: "uid == %@", meUid as CVarArg)
        guard let member = (try? context.fetch(req))?.first else { return }
        await stampOwnIdentity(on: member, in: context)
    }

    /// Find the FamilyMember representing the current iCloud user. Looks up
    /// by `cloudKitUserID`; falls back to `meUid` UserDefaults for legacy
    /// records. Returns nil if no record matches.
    @MainActor
    static func findSelf(in context: NSManagedObjectContext) async -> FamilyMember? {
        if let id = await currentUserID() {
            let req: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
            req.predicate = NSPredicate(format: "cloudKitUserID == %@ AND deletedAt == nil AND cloudKitUserID != nil", id)
            if let live = (try? context.fetch(req))?.first { return live }
        }
        // Legacy fallback: match by meUid.
        let meUidStr = UserDefaults.standard.string(forKey: "meUid") ?? ""
        guard let meUid = UUID(uuidString: meUidStr) else { return nil }
        let req: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
        req.predicate = NSPredicate(format: "uid == %@ AND deletedAt == nil", meUid as CVarArg)
        return (try? context.fetch(req))?.first
    }
}
