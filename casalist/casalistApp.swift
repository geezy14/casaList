import SwiftUI
import CoreData
import CloudKit
import UIKit

final class CasalistAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
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
        Self.acceptShare(metadata: metadata)
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
        appendShareLog("calling acceptShareInvitations into store \(sharedStore.identifier)")
        stack.container.acceptShareInvitations(from: [metadata], into: sharedStore) { results, error in
            if let error {
                appendShareLog("FAILED: \(error)")
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
                    addJoinerAsFamilyMember()
                }
            }
        }
    }

    /// Called on fresh-install launch when the local store has no household
    /// records. Looks up the previously-saved share URL from iCloud KV and
    /// silently re-accepts the share, restoring access to the family.
    /// No-op if no URL is saved or if a household already exists locally.
    static func attemptAutoRejoinSavedShare() {
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
                // If Apple says the share is gone (revoked / expired), purge
                // the stale URL so we don't keep retrying.
                if let ckError = error as? CKError,
                   ckError.code == .unknownItem || ckError.code == .invalidArguments {
                    kv.removeObject(forKey: lastShareURLKey)
                    kv.synchronize()
                    appendShareLog("auto-rejoin cleared invalid share URL from iCloud KV")
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
    static func addJoinerAsFamilyMember() {
        let stack = CasaCoreDataStack.shared
        let context = stack.context

        // Find the shared household that just came in.
        let req = Household.fetchRequest()
        let households = (try? context.fetch(req)) ?? []
        guard let shared = households.first(where: { h in
            guard let store = h.objectID.persistentStore else { return false }
            return store == stack.sharedStore
        }) else {
            appendShareLog("addJoinerAsFamilyMember: no shared household yet, retrying in 2s")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                addJoinerAsFamilyMember()
            }
            return
        }

        // Skip if a member with the same name already exists in this household.
        let myName = UserDefaults.standard.string(forKey: "userName")?
            .trimmingCharacters(in: .whitespaces) ?? ""
        let displayName = myName.isEmpty ? "New member" : myName
        let memberReq: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
        memberReq.predicate = NSPredicate(format: "household == %@ AND name ==[c] %@", shared, displayName)
        if let existing = try? context.fetch(memberReq), !existing.isEmpty {
            appendShareLog("addJoinerAsFamilyMember: \(displayName) already in shared household")
            return
        }

        let m = FamilyMember(context: context, name: displayName, role: "Member", colorHex: 0x7AB97D)
        context.assign(m, toStoreOf: shared)
        m.household = shared
        do {
            try context.save()
            // Claim this member as "me" so the name prompt can rename it later
            // if the user joined before setting their name.
            UserDefaults.standard.set(m.uid.uuidString, forKey: "meUid")
            appendShareLog("addJoinerAsFamilyMember: added \(displayName) to shared household (meUid claimed)")
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
        completionHandler([.banner, .sound, .list, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
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

    var body: some Scene {
        WindowGroup {
            CasalistCottage.Root()
                .environment(\.managedObjectContext, stack.context)
                .task {
                    HouseholdProvisioner.reconcile(in: stack.context)
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
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
                    HouseholdProvisioner.reconcile(in: stack.context)
                    // A remote change just landed — check for redemptions
                    // and new assignments performed on another device.
                    if notificationsEnabled {
                        Task { @MainActor in
                            await NotificationsManager.detectAndNotifyRedemptions(in: stack.context)
                            await NotificationsManager.detectAndNotifyAssignments(in: stack.context, userName: userName)
                            await NotificationsManager.detectAndNotifyPendingRequests(in: stack.context, userName: userName)
                        }
                    }
                }
        }
        .onChange(of: scenePhase) { _, new in
            guard new == .active else { return }
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
                FamilyDedupe.mergeDuplicateMeRecords(in: stack.context, userName: userName)
            }
            if notificationsEnabled {
                Task {
                    await NotificationsManager.syncFromContext(stack.context)
                    await NotificationsManager.scheduleWeeklyRecap(in: stack.context)
                }
            }
            // Auto-snapshot to iCloud Drive if enabled and a day has passed.
            let backupOn = UserDefaults.standard.object(forKey: "backupEnabled") as? Bool ?? true
            if backupOn && CloudBackup.isAvailable && CloudBackup.isDue {
                DispatchQueue.global(qos: .utility).async {
                    _ = CloudBackup.snapshot(in: stack.context)
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

        // Auto-deletion is DISABLED. The previous version deleted "stray"
        // private households whenever CloudKit hadn't fetched a household's
        // members yet — turned a routine reinstall into a family-wide data
        // loss event. If the user accumulates duplicate households (rare),
        // they can clean up manually in Settings → Data.
        //
        // Keeping the function shape (and the cloudKitWarm guard above) so
        // the contract for callers doesn't change.
        _ = cloudKitWarm  // silence unused-warning if we re-enable later
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
        let req = Household.fetchRequest()
        if let existing = try? context.fetch(req).first { return existing }
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

