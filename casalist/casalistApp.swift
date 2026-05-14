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
                    HouseholdProvisioner.ensureHouseholdExists(in: stack.context)
                    if notificationsEnabled {
                        _ = await NotificationsManager.requestAuth()
                        await NotificationsManager.syncFromContext(stack.context)
                    }
                }
        }
        .onChange(of: scenePhase) { _, new in
            if new == .active && notificationsEnabled {
                Task { await NotificationsManager.syncFromContext(stack.context) }
            }
        }
    }
}

/// On first launch, ensures the current user has a Household record in their
/// private store. Future family members the user adds become children of this
/// household.
enum HouseholdProvisioner {
    static func ensureHouseholdExists(in context: NSManagedObjectContext) {
        let req = Household.fetchRequest()
        req.fetchLimit = 1
        if let _ = try? context.fetch(req).first { return }
        guard let entity = NSEntityDescription.entity(forEntityName: "Household", in: context) else {
            NSLog("Casa: Household entity not found in model — Core Data probably failed to load")
            return
        }
        let household = Household(entity: entity, insertInto: context)
        household.uid = UUID()
        household.name = UserDefaults.standard.string(forKey: "householdName") ?? "My Household"
        household.createdAt = Date()
        try? context.save()
    }
}
