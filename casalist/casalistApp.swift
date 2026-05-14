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

    func applicationDidBecomeActive(_ application: UIApplication) {
        UNUserNotificationCenter.current().delegate = self
    }

    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        let stack = CasaCoreDataStack.shared
        guard let sharedStore = stack.sharedStore else {
            NSLog("Casalist share accept: shared store not loaded yet")
            return
        }
        stack.container.acceptShareInvitations(from: [metadata], into: sharedStore) { _, error in
            if let error { NSLog("Accept share failed: \(error)") }
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

@main
struct CasalistApp: App {
    @UIApplicationDelegateAdaptor(CasalistAppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true

    private let stack = CasaCoreDataStack.shared

    var body: some Scene {
        WindowGroup {
            CasalistCottage.Root()
                .environment(\.managedObjectContext, stack.context)
                .task {
                    HouseholdProvisioner.reconcile(in: stack.context)
                    if notificationsEnabled {
                        _ = await NotificationsManager.requestAuth()
                        await NotificationsManager.syncFromContext(stack.context)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
                    HouseholdProvisioner.reconcile(in: stack.context)
                }
        }
        .onChange(of: scenePhase) { _, new in
            if new == .active && notificationsEnabled {
                Task { await NotificationsManager.syncFromContext(stack.context) }
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
    static func reconcile(in context: NSManagedObjectContext) {
        let req = Household.fetchRequest()
        let households = (try? context.fetch(req)) ?? []

        // Make sure the user always has a private household to share (so CloudKit
        // has time to export it before they tap Send Invite).
        let privateHouseholds = households.filter { isOwnedByMe($0, in: context) }
        if privateHouseholds.isEmpty {
            _ = ensureHouseholdExists(in: context)
        }

        // Delete empty private households if we have more than one private one
        // OR if a shared household is present (avoids "2 households" after accept).
        let updatedHouseholds = (try? context.fetch(req)) ?? []
        let updatedPrivate = updatedHouseholds.filter { isOwnedByMe($0, in: context) }
        let hasShared = updatedHouseholds.contains { !isOwnedByMe($0, in: context) }
        let emptyPrivate = updatedPrivate.filter { isEmpty($0) }
        if (hasShared && !emptyPrivate.isEmpty) || updatedPrivate.count > 1 {
            // Keep one non-empty private if we have one, otherwise keep one empty.
            let nonEmpty = updatedPrivate.filter { !isEmpty($0) }
            let keep: Household? = nonEmpty.first ?? (hasShared ? nil : emptyPrivate.first)
            for h in updatedPrivate where h != keep {
                context.delete(h)
            }
            try? context.save()
        }
    }

    /// True if this household has no members, tasks, goals, chores, or events.
    private static func isEmpty(_ h: Household) -> Bool {
        (h.members?.count ?? 0) == 0 &&
        (h.tasks?.count ?? 0) == 0 &&
        (h.goals?.count ?? 0) == 0 &&
        (h.chores?.count ?? 0) == 0 &&
        (h.events?.count ?? 0) == 0
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

