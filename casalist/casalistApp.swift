import SwiftUI
import SwiftData

@main
struct CasalistApp: App {
    var body: some Scene {
        WindowGroup {
            CasalistCottage.Root()
        }
        // This initializes your database based on the TaskItem schema
        .modelContainer(for: TaskItem.self)
    }
}
