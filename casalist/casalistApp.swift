import SwiftUI
import SwiftData
import CloudKit
import UIKit

final class CasalistAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        let container = CKContainer(identifier: metadata.containerIdentifier)
        Task {
            do { _ = try await container.accept(metadata) }
            catch { print("Accept share failed: \(error)") }
        }
    }
}

@main
struct CasalistApp: App {
    @UIApplicationDelegateAdaptor(CasalistAppDelegate.self) var appDelegate

    var sharedContainer: ModelContainer = {
        let schema = Schema([TaskItem.self, FamilyMember.self, Household.self])
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
        }
        .modelContainer(sharedContainer)
    }
}
