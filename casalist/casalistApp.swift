import SwiftUI
import SwiftData
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
        // Belt-and-suspenders: also set on foreground.
        UNUserNotificationCenter.current().delegate = self
    }

    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        let container = CKContainer(identifier: metadata.containerIdentifier)
        Task {
            do { _ = try await container.accept(metadata) }
            catch { print("Accept share failed: \(error)") }
        }
    }

    /// Lets banners + sound show even when Casalist is in the foreground.
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

    var sharedContainer: ModelContainer = {
        let schema = Schema([TaskItem.self, FamilyMember.self, Household.self, FamilyGoal.self, ChoreTemplate.self, FamilyEvent.self])
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.gbrown10.casalist")
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            return try! ModelContainer(for: schema, configurations: [local])
        }
    }()

    var body: some Scene {
        WindowGroup {
            CasalistCottage.Root()
                .task {
                    if notificationsEnabled {
                        _ = await NotificationsManager.requestAuth()
                        await NotificationsManager.syncFromContext(sharedContainer.mainContext)
                    }
                }
        }
        .modelContainer(sharedContainer)
        .onChange(of: scenePhase) { _, new in
            if new == .active && notificationsEnabled {
                Task { await NotificationsManager.syncFromContext(sharedContainer.mainContext) }
            }
        }
    }
}
