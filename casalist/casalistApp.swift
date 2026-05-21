import SwiftUI
import CoreData
import CloudKit
import UIKit
import Combine

final class CasalistAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Self.registerReminderActions()
        return true
    }

    /// Register the "REMINDER_FIRE" notification category. Reminder
    /// notifications stamp this categoryIdentifier so the lock-screen
    /// presentation gets Mark Done / Snooze action buttons.
    static func registerReminderActions() {
        let done = UNNotificationAction(
            identifier: "REMINDER_DONE",
            title: "Mark done",
            options: []
        )
        let snooze15 = UNNotificationAction(
            identifier: "REMINDER_SNOOZE_15",
            title: "Snooze 15 min",
            options: []
        )
        let snooze1h = UNNotificationAction(
            identifier: "REMINDER_SNOOZE_1H",
            title: "Snooze 1 hour",
            options: []
        )
        let snoozeTomorrow = UNNotificationAction(
            identifier: "REMINDER_SNOOZE_TOMORROW",
            title: "Snooze until tomorrow",
            options: []
        )
        let skip = UNNotificationAction(
            identifier: "REMINDER_SKIP",
            title: "Skip this one",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: "REMINDER_FIRE",
            actions: [done, snooze15, snooze1h, snoozeTomorrow, skip],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        config.delegateClass = CasalistSceneDelegate.self
        return config
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        UNUserNotificationCenter.current().delegate = self
    }

    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        Self.appendShareLog("application(_:userDidAcceptCloudKitShareWith:) FIRED")
        if Self.isKnownBadShare(metadata) {
            Self.appendShareLog("SKIPPING — this share previously failed acceptance, not retrying")
            return
        }
        Self.acceptShare(metadata: metadata)
    }

    /// Names of CKShare record IDs that previously failed to accept on this
    /// device. Persisted so we don't loop into Apple's 'Item Unavailable'
    /// alert on every app launch when iOS keeps re-delivering a dead share.
    private static let badShareKey = "failedShareRecordIDs"

    static func isKnownBadShare(_ metadata: CKShare.Metadata) -> Bool {
        let bad = Set(UserDefaults.standard.stringArray(forKey: badShareKey) ?? [])
        return bad.contains(metadata.share.recordID.recordName)
    }

    static func markBadShare(_ metadata: CKShare.Metadata) {
        var bad = Set(UserDefaults.standard.stringArray(forKey: badShareKey) ?? [])
        bad.insert(metadata.share.recordID.recordName)
        UserDefaults.standard.set(Array(bad), forKey: badShareKey)
    }

    static func clearBadShareList() {
        UserDefaults.standard.removeObject(forKey: badShareKey)
    }

    /// Runs the dedupe + self-heal pipeline on a BACKGROUND context. The
    /// main reason this exists: doing context.save() on the main context
    /// can synchronously trigger a SQLite WAL checkpoint that competes
    /// with CloudKit's own writes on the shared store's SQLQueue. When
    /// that contention exceeds 10 seconds, iOS's scene-update watchdog
    /// kills the app (FRONTBOARD 0x8BADF00D). Pushing the work off-main
    /// lets the watchdog see a responsive UI thread and keeps the merge
    /// from blocking the queue that CloudKit needs.
    static func runDedupePipeline(userName: String) {
        let stack = CasaCoreDataStack.shared
        // REVERTED to 2.2's pattern in TF 2.5 (2026-05-18). The
        // performBackgroundTask variant was theory-correct but empirically
        // broke cross-device sync on Production even after clean
        // reinstalls. Whatever the actual interaction with
        // NSPersistentCloudKitContainer's export queue, 2.2's
        // newBackgroundContext() + automaticallyMergesChangesFromParent
        // worked, so we ship what worked.
        let bg = stack.container.newBackgroundContext()
        bg.automaticallyMergesChangesFromParent = true
        bg.perform {
            // Dedupe pipeline on a private-queue context. All saves go
            // through bg.perform, NOT the main thread — so the SQLite WAL
            // checkpoint can't deadlock the scene-update watchdog.
            // Stamping the user's own cloudKitUserID is async (needs
            // CKContainer.userRecordID), so we kick that off in parallel
            // and let it complete on its own.
            FamilyDedupe.mergeByCloudKitUserID(in: bg)
            FamilyDedupe.mergeLegacyNameDupes(in: bg)
            FamilyDedupe.mergeDuplicateMeRecords(in: bg, userName: userName)
            ensureMeInHouseholdOnBackground(userName: userName, context: bg)
        }
        // Fire stamping separately — it's async + main-actor-bound and
        // touches the main context. Done after the background dedupe so
        // it doesn't race for the SQLite queue.
        Task { @MainActor in
            await FamilyIdentity.backfillSelf(in: stack.context)
        }
    }

    /// Background-context version of ensureMeInSharedHousehold. Same
    /// logic, just doesn't touch the main context.
    static func ensureMeInHouseholdOnBackground(userName: String, context: NSManagedObjectContext) {
        let trimmed = userName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let stack = CasaCoreDataStack.shared
        let households = (try? context.fetch(Household.fetchRequest())) ?? []
        let target: Household
        let isJoiner: Bool
        if let shared = households.first(where: { $0.objectID.persistentStore === stack.sharedStore }) {
            target = shared; isJoiner = true
        } else if let priv = households.first(where: {
            $0.objectID.persistentStore === stack.privateStore && $0.deletedAtValue == nil
        }) {
            target = priv; isJoiner = false
        } else {
            return
        }
        if isJoiner {
            let privateHouseholds = households.filter {
                $0.objectID.persistentStore === stack.privateStore && $0.deletedAtValue == nil
            }
            for ph in privateHouseholds {
                for member in (ph.members as? Set<FamilyMember>) ?? [] where member.deletedAtValue == nil {
                    member.softDelete()
                }
                ph.softDelete()
            }
        }
        let req: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
        req.predicate = NSPredicate(format: "household == %@ AND name ==[c] %@", target, trimmed)
        let matches = (try? context.fetch(req)) ?? []
        if let live = matches.first(where: { $0.deletedAtValue == nil }) {
            UserDefaults.standard.set(live.uid.uuidString, forKey: "meUid")
            try? context.save()
            return
        }
        if let dead = matches.min(by: { $0.createdAt < $1.createdAt }) {
            dead.restore()
            // Preserve the role the admin set — do NOT force .standard here.
            // Forcing it caused a CloudKit race: the admin's .kid setting would
            // sync back and overwrite, then the next self-heal would force
            // .standard again, creating an infinite flip-flop.
            UserDefaults.standard.set(dead.uid.uuidString, forKey: "meUid")
            try? context.save()
            return
        }
        let assignedRole: FamilyRole = isJoiner ? .standard : .owner
        let m = FamilyMember(context: context, name: trimmed, role: assignedRole.label, colorHex: 0x7AB97D, roleLevel: assignedRole)
        context.assign(m, toStoreOf: target)
        m.household = target
        try? context.save()
        UserDefaults.standard.set(m.uid.uuidString, forKey: "meUid")
    }

    /// Should the saved share URL be cleared from iCloud KV after a fetch
    /// error? Default is "no" — only clear when CloudKit explicitly says
    /// the share is permanently unreachable from this account. Transient
    /// failures (network, rate limit, account temporarily unavailable,
    /// not authenticated) must preserve the URL so the next online launch
    /// can rejoin without needing a re-invite. Born from session in which
    /// a single bad-wifi launch permanently bricked the auto-rejoin path.
    static func shouldClearSavedShareURL(after error: NSError) -> Bool {
        guard error.domain == CKError.errorDomain,
              let code = CKError.Code(rawValue: error.code) else {
            return false
        }
        switch code {
        case .unknownItem, .permissionFailure, .participantMayNeedVerification,
             .invalidArguments, .badContainer:
            return true
        case .networkUnavailable, .networkFailure, .serviceUnavailable,
             .requestRateLimited, .zoneBusy, .notAuthenticated,
             .accountTemporarilyUnavailable:
            return false
        default:
            // Unknown CloudKit error → assume transient, keep the URL.
            // Safer to retry on next launch than to brick rejoin.
            return false
        }
    }

    /// NSUbiquitousKeyValueStore key — persists the share URL the user last
    /// accepted. Lives at the iCloud account level, NOT the app sandbox, so
    /// it SURVIVES app deletion. Used to auto-rejoin the family on a fresh
    /// reinstall without needing the owner to re-send a share link.
    static let lastShareURLKey = "lastJoinedShareURL"

    static func acceptShare(metadata: CKShare.Metadata) {
        appendShareLog("acceptShare called. share=\(metadata.share.recordID.recordName)")
        let stack = CasaCoreDataStack.shared
        guard let sharedStore = stack.sharedStore else {
            appendShareLog("FAILED — sharedStore not loaded; retrying in 1.5s")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                acceptShare(metadata: metadata)
            }
            return
        }
        // Bail before calling Apple's framework if we already know this
        // share can't be accepted — prevents the 'Item Unavailable' alert
        // from re-firing on every launch.
        if isKnownBadShare(metadata) {
            appendShareLog("SKIPPING acceptShareInvitations — known-bad share \(metadata.share.recordID.recordName)")
            return
        }
        appendShareLog("calling acceptShareInvitations into store \(sharedStore.identifier)")
        stack.container.acceptShareInvitations(from: [metadata], into: sharedStore) { results, error in
            if let error {
                appendShareLog("FAILED: \(error)")
                markBadShare(metadata)
                // Acceptance failed — most likely the share is gone (owner
                // stopped sharing, revoked, household deleted, etc.). Purge
                // the saved URL so we don't loop into Apple's "Item
                // Unavailable" alert on every launch.
                let kv = NSUbiquitousKeyValueStore.default
                kv.removeObject(forKey: lastShareURLKey)
                kv.synchronize()
                appendShareLog("cleared stale share URL from iCloud KV after acceptance failure")
            } else {
                appendShareLog("SUCCEEDED: \(results?.count ?? 0) shares accepted")
                // Persist the share URL to NSUbiquitousKeyValueStore so a
                // future fresh install (after app delete or device reset)
                // can silently re-accept and rejoin the family. Lives at
                // the iCloud account level — survives app deletion.
                if let url = metadata.share.url {
                    let kv = NSUbiquitousKeyValueStore.default
                    kv.set(url.absoluteString, forKey: lastShareURLKey)
                    kv.synchronize()
                    appendShareLog("Saved share URL to iCloud KV for auto-rejoin: \(url.absoluteString)")
                }
                // Give CloudKit a moment to sync down the shared household so we
                // can attach a FamilyMember for the joiner.
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    addJoinerAsFamilyMember(metadata: metadata)
                }
            }
        }
    }

    /// Session-scoped guard so auto-rejoin only runs once per app launch.
    /// Without this, scenePhase = .active firings can re-trigger it after
    /// a failed attempt, looping the user into Apple's "Item Unavailable"
    /// alert on every launch / foreground.
    private static var didAttemptAutoRejoinThisSession = false

    /// Called on fresh-install launch when the local store has no household
    /// records. Looks up the previously-saved share URL from iCloud KV and
    /// silently re-accepts the share, restoring access to the family.
    /// No-op if no URL is saved or if a household already exists locally.
    static func attemptAutoRejoinSavedShare() {
        guard !didAttemptAutoRejoinThisSession else {
            appendShareLog("attemptAutoRejoinSavedShare: already tried this session, skipping")
            return
        }
        didAttemptAutoRejoinThisSession = true
        let stack = CasaCoreDataStack.shared

        let req = Household.fetchRequest()
        let count = (try? stack.context.count(for: req)) ?? 0
        guard count == 0 else {
            appendShareLog("attemptAutoRejoinSavedShare: skipped — already have \(count) household(s) locally")
            return
        }

        let kv = NSUbiquitousKeyValueStore.default
        kv.synchronize()
        guard let urlString = kv.string(forKey: lastShareURLKey),
              let url = URL(string: urlString) else {
            appendShareLog("attemptAutoRejoinSavedShare: no saved share URL in iCloud KV")
            return
        }
        appendShareLog("attemptAutoRejoinSavedShare: trying URL \(urlString)")

        let container = CKContainer(identifier: "iCloud.com.gbrown10.casalist")
        container.fetchShareMetadata(with: url) { metadata, error in
            if let error {
                appendShareLog("auto-rejoin fetchShareMetadata FAILED: \(error)")
                let ns = error as NSError
                if shouldClearSavedShareURL(after: ns) {
                    kv.removeObject(forKey: lastShareURLKey)
                    kv.synchronize()
                    appendShareLog("auto-rejoin cleared share URL — permanent failure (code=\(ns.code))")
                } else {
                    appendShareLog("auto-rejoin keeping share URL — transient failure (code=\(ns.code))")
                }
                return
            }
            guard let metadata else { return }
            appendShareLog("auto-rejoin fetched metadata, calling acceptShare")
            DispatchQueue.main.async {
                acceptShare(metadata: metadata)
            }
        }
    }

    /// After accepting a share, auto-create a FamilyMember in the shared
    /// household for the recipient so the inviter sees them immediately. Pulls
    /// the name from the user's `userName` AppStorage; falls back to "New
    /// member" if not set yet.
    /// Idempotent foreground self-heal. If the device has any household
    /// (private OR shared) but no live FamilyMember matching userName, create
    /// one in the appropriate household and stamp it with this device's
    /// cloudKitUserID. Handles three cases:
    ///   • Joiner: shared household present, no me-record → create in shared
    ///   • Owner who had their record wiped: private household present, no
    ///     me-record (because welcome screen got skipped due to existing
    ///     CloudKit-synced household) → create in private
    ///   • User whose record was soft-deleted on another device → restore +
    ///     re-stamp
    static func ensureMeInSharedHousehold(userName: String) {
        let stack = CasaCoreDataStack.shared
        let context = stack.context
        let trimmed = userName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let households = (try? context.fetch(Household.fetchRequest())) ?? []
        let sharedCount = households.filter { $0.objectID.persistentStore === stack.sharedStore }.count
        let privCount = households.filter { $0.objectID.persistentStore === stack.privateStore && $0.deletedAtValue == nil }.count

        // Target household: shared if we joined one (we're a participant),
        // otherwise the live private one (we're the owner). Bail only if
        // neither exists — then there's no household to attach to anyway.
        let target: Household
        let isJoiner: Bool
        if let shared = households.first(where: { $0.objectID.persistentStore === stack.sharedStore }) {
            target = shared
            isJoiner = true
        } else if let priv = households.first(where: {
            $0.objectID.persistentStore === stack.privateStore && $0.deletedAtValue == nil
        }) {
            target = priv
            isJoiner = false
        } else {
            appendShareLog("ensureMeInSharedHousehold[\(trimmed)]: no household at all (priv=\(privCount), shared=\(sharedCount)) — bail")
            return
        }
        appendShareLog("ensureMeInSharedHousehold[\(trimmed)]: ENTER priv=\(privCount) shared=\(sharedCount) target=\(isJoiner ? "shared" : "private")")
        // Alias for legacy code below that refers to `shared` by name.
        let shared = target

        // Retire any leftover pre-share private households on this device,
        // BUT only for joiners. An owner's "private household" is their own
        // legitimate household — retiring it would wipe their data.
        if isJoiner {
            let privateHouseholds = households.filter {
                $0.objectID.persistentStore === stack.privateStore && $0.deletedAtValue == nil
            }
            var retired = false
            for ph in privateHouseholds {
                let memberCount = ((ph.members as? Set<FamilyMember>) ?? []).filter { $0.deletedAtValue == nil }.count
                for member in (ph.members as? Set<FamilyMember>) ?? [] where member.deletedAtValue == nil {
                    member.softDelete()
                }
                ph.softDelete()
                retired = true
                appendShareLog("ensureMeInSharedHousehold: retired private household '\(ph.name)' (had \(memberCount) live members)")
            }
            if retired { try? context.save() }
        }

        let req: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
        req.predicate = NSPredicate(format: "household == %@ AND name ==[c] %@", shared, trimmed)
        let matches = (try? context.fetch(req)) ?? []
        if let live = matches.first(where: { $0.deletedAtValue == nil }) {
            // Found my record in the shared household. Make sure it's
            // stamped with this device's cloudKitUserID — otherwise other
            // devices see it as "legacy" and dedupe-loop with their stamped
            // record. Also re-claim meUid onto it.
            UserDefaults.standard.set(live.uid.uuidString, forKey: "meUid")
            if live.userID.isEmpty {
                Task { @MainActor in
                    await FamilyIdentity.stampOwnIdentity(on: live, in: context)
                }
            }
            appendShareLog("ensureMeInSharedHousehold: live \(trimmed) found in shared — meUid claimed, ID \(live.userID.isEmpty ? "stamp scheduled" : "already stamped")")
            return
        }
        if let dead = matches.min(by: { $0.createdAt < $1.createdAt }) {
            dead.restore()
            dead.roleLevel = FamilyRole.standard.rawValue
            UserDefaults.standard.set(dead.uid.uuidString, forKey: "meUid")
            try? context.save()
            appendShareLog("ensureMeInSharedHousehold: restored soft-deleted \(trimmed)")
            return
        }
        // No record exists at all — create one in the target store.
        // Owners get .owner, joiners get .standard.
        let assignedRole: FamilyRole = isJoiner ? .standard : .owner
        let m = FamilyMember(context: context, name: trimmed, role: assignedRole.label, colorHex: 0x7AB97D, roleLevel: assignedRole)
        context.assign(m, toStoreOf: shared)
        m.household = shared
        do {
            try context.save()
            UserDefaults.standard.set(m.uid.uuidString, forKey: "meUid")
            appendShareLog("ensureMeInSharedHousehold: created \(trimmed) in shared store")
        } catch {
            appendShareLog("ensureMeInSharedHousehold save error: \(error)")
        }
    }

    static func addJoinerAsFamilyMember(metadata: CKShare.Metadata? = nil) {
        let stack = CasaCoreDataStack.shared
        let context = stack.context
        appendShareLog("addJoinerAsFamilyMember: ENTER userName=\(UserDefaults.standard.string(forKey: "userName") ?? "")")

        // Find the shared household that just came in.
        let req = Household.fetchRequest()
        let households = (try? context.fetch(req)) ?? []
        guard let shared = households.first(where: { h in
            guard let store = h.objectID.persistentStore else { return false }
            return store == stack.sharedStore
        }) else {
            appendShareLog("addJoinerAsFamilyMember: no shared household yet, retrying in 2s")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                addJoinerAsFamilyMember(metadata: metadata)
            }
            return
        }

        // Look for an existing same-name member (live OR soft-deleted) in the
        // shared household. If we find one, reuse it — restoring if necessary
        // — instead of creating a duplicate. Without this check, a joiner who
        // was deleted-then-rejoins would either silently fail (when the
        // soft-deleted record blocks the create) or pile up duplicates.
        let myName = UserDefaults.standard.string(forKey: "userName")?
            .trimmingCharacters(in: .whitespaces) ?? ""
        let displayName = myName.isEmpty ? "New member" : myName
        let memberReq: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
        memberReq.predicate = NSPredicate(format: "household == %@ AND name ==[c] %@", shared, displayName)
        if let existing = try? context.fetch(memberReq), !existing.isEmpty {
            // Prefer a live record; fall back to restoring a soft-deleted one.
            let live = existing.first(where: { $0.deletedAtValue == nil })
            let target = live ?? existing.min(by: { $0.createdAt < $1.createdAt })!
            if target.deletedAtValue != nil {
                target.restore()
                appendShareLog("addJoinerAsFamilyMember: restored soft-deleted \(displayName)")
                // Only reset to standard on restore if the role is kid — a
                // fresh rejoin shouldn't force-demote an admin, but it should
                // unblock someone accidentally left in kid mode with no admin
                // present to fix it.
                if target.level == .kid { target.roleLevel = FamilyRole.standard.rawValue }
            }
            // Do NOT force-set roleLevel for live records — the admin may have
            // intentionally set kid/admin and CloudKit is the source of truth.
            UserDefaults.standard.set(target.uid.uuidString, forKey: "meUid")
            if let metadata, target.userID.isEmpty {
                Task { @MainActor in
                    FamilyIdentity.stampJoinerIdentity(on: target, from: metadata, in: context)
                }
            }
            try? context.save()
            return
        }

        // Joiners always come in as .standard. Owner is reserved for the
        // share creator; if this device had an "owner" FamilyMember from a
        // previous solo household, that role doesn't carry into the new one.
        let m = FamilyMember(context: context, name: displayName, role: "Member", colorHex: 0x7AB97D, roleLevel: .standard)
        context.assign(m, toStoreOf: shared)
        m.household = shared

        // Stamp the joiner's iCloud user ID from the share metadata so the
        // record has a stable identity from creation. If no metadata (e.g.
        // called from a foreground self-heal path), the foreground task
        // will backfill via FamilyIdentity.stampOwnIdentity.
        if let metadata {
            Task { @MainActor in
                FamilyIdentity.stampJoinerIdentity(on: m, from: metadata, in: context)
            }
        } else {
            Task { @MainActor in
                await FamilyIdentity.stampOwnIdentity(on: m, in: context)
            }
        }

        // Demote any pre-existing same-name FamilyMember records on this
        // device so they can't reintroduce the owner role through dedupe.
        let priorReq: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
        priorReq.predicate = NSPredicate(format: "name ==[c] %@ AND deletedAt == nil AND SELF != %@", displayName, m)
        for prior in (try? context.fetch(priorReq)) ?? [] {
            prior.roleLevel = FamilyRole.standard.rawValue
        }

        // Retire the joiner's pre-share private household. It's a placeholder
        // from before they joined a real household and would otherwise leave
        // ghost FamilyMembers (their old "Dakoda owner" record) hanging around
        // in the family list alongside the new shared-store one.
        let privateHouseholds = households.filter { $0.objectID.persistentStore === stack.privateStore && $0.deletedAtValue == nil }
        for ph in privateHouseholds {
            for member in (ph.members as? Set<FamilyMember>) ?? [] where member.deletedAtValue == nil {
                member.softDelete()
            }
            ph.softDelete()
            appendShareLog("addJoinerAsFamilyMember: retired private household \(ph.name)")
        }

        do {
            try context.save()
            // Claim this member as "me" so the name prompt can rename it later
            // if the user joined before setting their name.
            UserDefaults.standard.set(m.uid.uuidString, forKey: "meUid")
            appendShareLog("addJoinerAsFamilyMember: added \(displayName) to shared household (meUid claimed, role=standard)")
        } catch {
            appendShareLog("addJoinerAsFamilyMember save error: \(error)")
        }
    }

    static func appendShareLog(_ msg: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(stamp)] \(msg)\n"
        NSLog("Casa share: \(msg)")
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let url = docs.appendingPathComponent("share-log.txt")
            if let data = line.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: url.path) {
                    // Rotate when the file exceeds 100KB. Otherwise hours of
                    // heavy instrumentation builds a multi-MB file which can
                    // freeze the Settings sync-log reader.
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                       let size = attrs[.size] as? Int, size > 100_000 {
                        // Keep the most recent ~40KB; rewrite atomically.
                        if let existing = try? Data(contentsOf: url) {
                            let keepFrom = max(0, existing.count - 40_000)
                            let kept = existing.subdata(in: keepFrom..<existing.count)
                            try? (kept + data).write(to: url)
                            return
                        }
                    }
                    if let handle = try? FileHandle(forWritingTo: url) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        try? handle.close()
                    }
                } else {
                    try? data.write(to: url)
                }
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Record foreground fires so the Reminder history view has
        // something to show. Lock-screen fires can't be intercepted —
        // iOS delivers them without calling back to the app.
        if notification.request.content.categoryIdentifier == "REMINDER_FIRE",
           let uid = notification.request.content.userInfo["taskUid"] as? String {
            ReminderHistory.record(
                taskUid: uid,
                taskName: notification.request.content.title,
                action: .fired
            )
        }
        completionHandler([.banner, .sound, .list, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo

        // Reminder action buttons (Mark done / Snooze 15m / 1h / Tomorrow).
        if response.notification.request.content.categoryIdentifier == "REMINDER_FIRE",
           let uid = info["taskUid"] as? String {
            Task { @MainActor in
                ReminderActionHandler.handle(actionID: response.actionIdentifier, taskUid: uid)
                completionHandler()
            }
            return
        }

        // Status ping with attached location → tapping the notification
        // opens Apple Maps centered on the sender's pinned coordinate.
        if let lat = info["pingCoordLat"] as? Double,
           let lng = info["pingCoordLng"] as? Double {
            let sender = (info["pingSender"] as? String) ?? "Family"
            let q = sender.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? sender
            if let url = URL(string: "https://maps.apple.com/?ll=\(lat),\(lng)&q=\(q)") {
                DispatchQueue.main.async { UIApplication.shared.open(url) }
            } else if let mapsURL = URL(string: "maps://?ll=\(lat),\(lng)&q=\(q)") {
                DispatchQueue.main.async { UIApplication.shared.open(mapsURL) }
            }
        }
        completionHandler()
    }
}

/// Custom UIWindowSceneDelegate so iOS routes CloudKit share accepts to our
/// app. SwiftUI's default scene delegate doesn't implement
/// `windowScene(_:userDidAcceptCloudKitShareWith:)`, so without this the
/// system silently drops share-accept callbacks.
final class CasalistSceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        CasalistAppDelegate.appendShareLog("windowScene(_:userDidAcceptCloudKitShareWith:) FIRED")
        CasalistAppDelegate.acceptShare(metadata: metadata)
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        CasalistAppDelegate.appendShareLog("scene willConnectTo with \(options.cloudKitShareMetadata == nil ? "no" : "YES") cloudKitShareMetadata")
        if let metadata = options.cloudKitShareMetadata {
            CasalistAppDelegate.acceptShare(metadata: metadata)
        }
    }
}

@main
struct CasalistApp: App {
    @UIApplicationDelegateAdaptor(CasalistAppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("userName") private var userName: String = ""

    private let stack = CasaCoreDataStack.shared

    /// Debounced relay for the heavy pipeline (dedupe + notifications).
    /// NSPersistentStoreRemoteChange fires on EVERY local save, not just
    /// remote ones. Running reconcile + dedupe on each fires causes a
    /// cascade: each bg save triggers another notification which triggers
    /// another save, keeping the SQLite WAL locked and preventing
    /// NSPersistentCloudKitContainer from checkpointing its export queue.
    /// 2-second debounce absorbs the burst; the CloudKit export completes
    /// during the quiet window and remote devices see the change promptly.
    private let remoteChangePipeline = PassthroughSubject<Void, Never>()

    /// Wire the shared GameRulesStore to the active Household so settings
    /// (reward tiers, category points, expiration window) sync across
    /// every device. Safe to call repeatedly — `attach` short-circuits
    /// when state hasn't changed. Called on first launch and after every
    /// remote-change debounce.
    private func attachGameRulesStore() {
        let req = Household.fetchRequest()
        guard let households = try? stack.context.fetch(req) else { return }
        let active = households.first { $0.deletedAtValue == nil }
        guard active != nil else { return }
        GameRulesStore.shared.attach(to: active, context: stack.context)
    }

    var body: some Scene {
        WindowGroup {
            CasalistCottage.Root()
                .environment(\.managedObjectContext, stack.context)
                .environmentObject(stack)
                .modifier(LocalFallbackBannerOverlay())
                .modifier(SaveErrorBannerOverlay())
                // Week starts on Saturday in every DatePicker / calendar
                // grid descendant. See SaturdayFirstCalendar.swift.
                .environment(\.calendar, .casalist)
                .task {
                    HouseholdProvisioner.reconcile(in: stack.context)
                    attachGameRulesStore()
                    // Raise lifetime to at least current balance so admin-
                    // granted points count toward level (fixes "Rookie at
                    // 45 pts"). Idempotent.
                    FamilyPoints.backfillLifetime(in: stack.context)
                    LocationSharingService.shared.resumeIfPreviouslySharing()
                    // Re-register geofences for any active
                    // location-based reminders so monitoring picks up
                    // where iOS left off across reboots / cold starts.
                    LocationReminderService.shared.resyncMonitoredRegions(in: stack.context)
                    // If this device has no household (fresh install on a
                    // previous share-joiner), try silently re-accepting the
                    // last-known share URL from iCloud KV. Restores the
                    // family without owner action.
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1))  // give iCloud KV a beat to sync
                        CasalistAppDelegate.attemptAutoRejoinSavedShare()
                    }
                    if notificationsEnabled {
                        _ = await NotificationsManager.requestAuth()
                        await NotificationsManager.syncFromContext(stack.context)
                        await NotificationsManager.scheduleWeeklyRecap(in: stack.context)
                        await NotificationsManager.scheduleDailyBriefing(in: stack.context)
                        await NotificationsManager.scheduleReminderRecap()
                        await NotificationsManager.syncEventsFromContext(stack.context)
                    }
                    // Widget extension reads a JSON snapshot from the
                    // shared App Group container. Refresh on every
                    // launch so the widget shows current state.
                    WidgetDataExporter.export(from: stack.context)
                    // Reconcile any active status pings into Live
                    // Activities on this device's Lock Screen / Dynamic
                    // Island. Skips pings created by the current user.
                    if #available(iOS 16.2, *) {
                        StatusPingLiveActivityBridge.syncFromContext(stack.context, currentUser: userName)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
                    // Step 1 — immediate UI refresh so @FetchRequest results
                    // update the moment CloudKit delivers new data. Does NOT
                    // save, so it can't cascade into another notification.
                    stack.context.refreshAllObjects()
                    // Step 2 — heavy pipeline fires after a 2-second quiet
                    // window. NSPersistentStoreRemoteChange fires on every
                    // local save too, so without the debounce each bg save
                    // triggers another notification → another save → WAL stays
                    // locked → NSPersistentCloudKitContainer can't export.
                    // 2s of quiet gives the CloudKit export queue breathing room.
                    remoteChangePipeline.send()
                }
                .onReceive(remoteChangePipeline.debounce(for: .seconds(2), scheduler: DispatchQueue.main)) { _ in
                    HouseholdProvisioner.reconcile(in: stack.context)
                    attachGameRulesStore()
                    GameRulesStore.shared.refreshFromHousehold()
                    CasalistAppDelegate.runDedupePipeline(userName: userName)
                    if notificationsEnabled {
                        Task { @MainActor in
                            await NotificationsManager.detectAndNotifyRedemptions(in: stack.context)
                            await NotificationsManager.detectAndNotifyAssignments(in: stack.context, userName: userName)
                            await NotificationsManager.detectAndNotifyPendingRequests(in: stack.context, userName: userName)
                            await NotificationsManager.detectAndNotifyGroceryActivity(in: stack.context, userName: userName)
                            await NotificationsManager.detectAndNotifyStatusPings(in: stack.context, userName: userName)
                            if #available(iOS 16.2, *) {
                                StatusPingLiveActivityBridge.syncFromContext(stack.context, currentUser: userName)
                            }
                            await NotificationsManager.syncEventsFromContext(stack.context)
                        }
                    }
                    WidgetDataExporter.export(from: stack.context)
                }
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .active else { return }
            // Foregrounding: invalidate the row cache so the next read pulls
            // any changes that synced while the app was backgrounded.
            // NSPersistentCloudKitContainer already fetches automatically on
            // foreground; refreshAllObjects ensures the UI displays the new
            // state without waiting for a separate user action.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                stack.context.refreshAllObjects()
                // After the cache invalidates and CloudKit has had a beat
                // to land remote changes, run the dedupe pass. Catches the
                // reinstall-race "two me" pattern.
                try? await Task.sleep(for: .milliseconds(1500))
                // Dedupe + self-heal off-main (background context) so
                // SQLite WAL checkpoint doesn't block main thread → watchdog
                // kill (FRONTBOARD 0x8BADF00D). Runs the full pipeline on
                // a private-queue context.
                CasalistAppDelegate.runDedupePipeline(userName: userName)
            }
            if notificationsEnabled {
                Task {
                    await NotificationsManager.syncFromContext(stack.context)
                    await NotificationsManager.scheduleWeeklyRecap(in: stack.context)
                        await NotificationsManager.scheduleDailyBriefing(in: stack.context)
                        await NotificationsManager.scheduleReminderRecap()
                }
            }
            // Auto-snapshot to iCloud Drive if enabled and a day has passed.
            // CRITICAL: don't use stack.context (main-thread-bound) from a
            // background queue. NSManagedObjectContext is thread-affine —
            // using it off-thread can corrupt state or crash. Spin up a
            // proper background context off the container instead.
            let backupOn = UserDefaults.standard.object(forKey: "backupEnabled") as? Bool ?? true
            if backupOn && CloudBackup.isAvailable && CloudBackup.isDue {
                let bgContext = stack.container.newBackgroundContext()
                bgContext.perform {
                    _ = CloudBackup.snapshot(in: bgContext)
                }
            }
        }
    }
}

/// On first launch (or after a share is accepted), reconciles the household
/// situation:
///
/// - If the user already has a household (private or shared), do nothing.
/// - If only one auto-created empty local household exists AND a shared
///   household has since arrived, delete the empty local one so the user
///   doesn't see "2 households" in the UI.
/// - If no household exists at all and the user is going to need one
///   (they've already set a userName), create one.
enum HouseholdProvisioner {
    /// Tracks the timestamp of the first reconcile in this session. The
    /// destructive "delete stray households" path only runs after enough
    /// real wall-clock time has passed for CloudKit to have had a fair
    /// chance to sync the existing household down. Without this delay,
    /// reconcile would see a fresh install's still-empty just-synced
    /// household, mistake it for stray garbage, delete it, and propagate
    /// that delete back to CloudKit — wiping the entire family from every
    /// device. (Lost Geezy's setup on 2026-05-15 exactly this way.)
    private static var firstReconcileAt: Date?
    private static let cloudKitGrace: TimeInterval = 120  // 2 min

    static func reconcile(in context: NSManagedObjectContext) {
        Trash.purgeExpired(in: context)
        let req = Household.fetchRequest()
        let households = (try? context.fetch(req)) ?? []
        let stack = CasaCoreDataStack.shared

        if firstReconcileAt == nil { firstReconcileAt = Date() }
        let cloudKitWarm = (Date().timeIntervalSince(firstReconcileAt!) >= cloudKitGrace)

        // Only auto-create a private household when the user has none at all
        // (fresh install, no share joined). A joiner — someone whose only
        // household is a shared one — shouldn't get a stray empty private
        // alongside it. If they later try to invite people, InviteFamilyView
        // calls ensureHouseholdExists explicitly to spin one up at that moment.
        //
        // CRITICAL: only auto-create AFTER the CloudKit grace period. On a
        // reinstall, the user's existing household lives in CloudKit but
        // hasn't fetched yet — if we create a new one here, we end up with
        // two private households and the dedup logic below could clobber
        // the real one.
        if households.isEmpty && cloudKitWarm {
            _ = ensureHouseholdExists(in: context)
        }

        // Merge duplicate private households. Race condition root cause:
        // on reinstall, the user's old household syncs down from CloudKit
        // moments after `ensureHouseholdExists` already created a fresh
        // local one. We end up with two private households parented to the
        // same user. Merge them by moving children to the survivor (oldest
        // createdAt, with most live members) and soft-deleting the rest.
        // Safe because soft-delete preserves the records for trash recovery
        // and we never touch the shared store.
        let privates = households.filter {
            $0.objectID.persistentStore === stack.privateStore && $0.deletedAtValue == nil
        }
        if privates.count > 1 {
            func liveMembers(_ h: Household) -> Int {
                ((h.members as? Set<FamilyMember>) ?? []).filter { $0.deletedAtValue == nil }.count
            }
            let survivor = privates.max(by: { a, b in
                let am = liveMembers(a), bm = liveMembers(b)
                if am != bm { return am < bm }
                return a.createdAt > b.createdAt  // older wins
            })!
            var moved = 0
            for h in privates where h !== survivor {
                for m in (h.members as? Set<FamilyMember>) ?? [] { m.household = survivor; moved += 1 }
                for t in (h.tasks as? Set<TaskItem>) ?? [] { t.household = survivor; moved += 1 }
                for g in (h.goals as? Set<FamilyGoal>) ?? [] { g.household = survivor; moved += 1 }
                for e in (h.events as? Set<FamilyEvent>) ?? [] { e.household = survivor; moved += 1 }
                h.softDelete()
            }
            try? context.save()
            CasalistAppDelegate.appendShareLog("reconcile: merged \(privates.count) private households into 1 (\(moved) children moved)")
        }

        _ = cloudKitWarm  // silence unused-warning
    }

    /// True if this household has no members, tasks, goals, chores, or events.
    private static func isEmpty(_ h: Household) -> Bool {
        (h.members?.count ?? 0) == 0 &&
        (h.tasks?.count ?? 0) == 0 &&
        (h.goals?.count ?? 0) == 0 &&
        (h.chores?.count ?? 0) == 0 &&
        (h.events?.count ?? 0) == 0
    }

    /// Like `isEmpty`, but also true when the household's only content is the
    /// local user's own FamilyMember and nothing else. This catches the
    /// "joiner typed their name before accepting" stray-household state:
    /// they have a one-person private household that should disappear once
    /// the real shared household arrives.
    private static func isOnlySelf(_ h: Household) -> Bool {
        let lc = (UserDefaults.standard.string(forKey: "userName") ?? "")
            .trimmingCharacters(in: .whitespaces).lowercased()
        guard !lc.isEmpty else { return false }
        let members = (h.members as? Set<FamilyMember>) ?? []
        guard members.count == 1, let only = members.first, only.name.lowercased() == lc else { return false }
        return (h.tasks?.count ?? 0) == 0
            && (h.goals?.count ?? 0) == 0
            && (h.chores?.count ?? 0) == 0
            && (h.events?.count ?? 0) == 0
    }

    /// True if this household lives in the user's private store (i.e. they own
    /// it). Households arriving via CKShare live in the shared store.
    private static func isOwnedByMe(_ h: Household, in context: NSManagedObjectContext) -> Bool {
        let stack = CasaCoreDataStack.shared
        if let sharedStore = stack.sharedStore, h.objectID.persistentStore == sharedStore {
            return false
        }
        return true
    }

    /// If we claimed a FamilyMember (meUid) but it no longer exists in any
    /// store, the owner deleted us. Auto-leave any shared households so the
    /// local UI snaps back to a clean state instead of showing a ghost
    /// identity (userName set, no member, owner's avatars at top-left).
    static func detectRemovalByOwner(in context: NSManagedObjectContext) {
        let meUidString = UserDefaults.standard.string(forKey: "meUid") ?? ""
        guard !meUidString.isEmpty, let myUid = UUID(uuidString: meUidString) else { return }

        let memberReq: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
        memberReq.predicate = NSPredicate(format: "uid == %@", myUid as CVarArg)
        let stillExists = ((try? context.count(for: memberReq)) ?? 0) > 0
        guard !stillExists else { return }

        let stack = CasaCoreDataStack.shared
        let req = Household.fetchRequest()
        let households = (try? context.fetch(req)) ?? []
        let sharedHouseholds = households.filter { $0.objectID.persistentStore == stack.sharedStore }

        if !sharedHouseholds.isEmpty, let sharedStore = stack.sharedStore {
            var zoneIDs = Set<CKRecordZone.ID>()
            for h in sharedHouseholds {
                if let record = try? stack.container.record(for: h.objectID) {
                    zoneIDs.insert(record.recordID.zoneID)
                }
            }
            for zid in zoneIDs {
                stack.container.purgeObjectsAndRecordsInZone(with: zid, in: sharedStore) { _, _ in }
            }
            NSLog("Casa: meUid claim missing and shared households present — auto-left share")
        }
        // Clear stale claim either way so the UI doesn't dangle.
        UserDefaults.standard.set("", forKey: "meUid")
    }

    /// Creates a household if the user has none. Call this when the user is
    /// about to need one (e.g. adding their first family member).
    @discardableResult
    static func ensureHouseholdExists(in context: NSManagedObjectContext) -> Household? {
        let stack = CasaCoreDataStack.shared
        let req = Household.fetchRequest()
        let all = (try? context.fetch(req)) ?? []
        // Prefer a live private-store household. Falling back to any household
        // covers the not-yet-synced shared-store-only case.
        let existing = all.first(where: {
            $0.objectID.persistentStore === stack.privateStore && $0.deletedAtValue == nil
        }) ?? all.first(where: { $0.deletedAtValue == nil })
        if let existing { return existing }
        guard let entity = NSEntityDescription.entity(forEntityName: "Household", in: context) else {
            NSLog("Casa: Household entity not found in model — Core Data probably failed to load")
            return nil
        }
        let household = Household(entity: entity, insertInto: context)
        household.uid = UUID()
        household.name = UserDefaults.standard.string(forKey: "householdName") ?? "My Household"
        household.createdAt = Date()
        try? context.save()
        return household
    }
}

