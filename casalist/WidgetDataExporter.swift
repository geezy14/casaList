import Foundation
import CoreData
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Writes a `TodayReminderSnapshot` JSON file to the shared App Group
/// container so the Widget Extension's timeline provider can render
/// without needing direct Core Data access.
///
/// The widget extension runs in its own process and can't reach the
/// app's NSPersistentCloudKitContainer directly — even if it could,
/// CloudKit auth, schema, and the share-zone setup would all need to
/// be re-done in-extension. A JSON snapshot in shared storage is
/// simpler, smaller, and refreshes whenever the main app saves.
///
/// Main-app-only target membership. The snapshot TYPE itself
/// (TodayReminderSnapshot.swift) is the shared file.
enum WidgetDataExporter {
    private static let snapshotFilename = "today-reminders-snapshot.json"

    private static var snapshotURL: URL {
        AppGroup.containerURL.appendingPathComponent(snapshotFilename)
    }

    /// Read today's reminders from the given context, serialize them,
    /// and atomically write the snapshot. Tickles the widget extension
    /// to reload its timeline.
    static func export(from context: NSManagedObjectContext) {
        let cal = Calendar.current
        let now = Date()
        let endOfDay = cal.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now

        let req: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        req.predicate = NSPredicate(
            format: "category ==[c] %@ AND deletedAt == nil AND (dueDate == nil OR dueDate <= %@)",
            "reminders", endOfDay as NSDate
        )
        let tasks = (try? context.fetch(req)) ?? []

        let entries = tasks.map { t -> TodayReminderSnapshot.Entry in
            TodayReminderSnapshot.Entry(
                id: t.uid,
                title: t.task,
                fireAt: t.dueDate,
                isDone: t.isCompleted,
                colorTagRaw: ReminderColorTagStore.tag(for: t.uid).rawValue,
                assignee: t.assignee ?? ""
            )
        }
        .sorted {
            switch ($0.fireAt, $1.fireAt) {
            case let (a?, b?): return a < b
            case (nil, _?):    return false
            case (_?, nil):    return true
            case (nil, nil):   return $0.title < $1.title
            }
        }

        let snapshot = TodayReminderSnapshot(entries: entries, generatedAt: now)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: snapshotURL, options: .atomic)
        reloadTimelines()
    }

    private static func reloadTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "TodayRemindersWidget")
        #endif
    }
}
