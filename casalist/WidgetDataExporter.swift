import Foundation
import CoreData
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Writes a snapshot of "today's reminders" to a JSON file in the
/// shared App Group container so the Widget Extension's timeline
/// provider can read it without needing direct Core Data access.
///
/// The widget extension runs in its own process and can't reach the
/// app's NSPersistentCloudKitContainer directly — even if it could,
/// CloudKit auth, schema, and the share-zone setup would all need to
/// be re-done in-extension. A JSON snapshot in shared storage is
/// simpler, smaller, and refreshes whenever the main app saves.
///
/// Snapshot is intentionally minimal: enough for the widget views to
/// render, no more. We dump after every save in the main app and on
/// foreground entry.
struct TodayReminderSnapshot: Codable {
    /// One reminder firing today.
    struct Entry: Codable, Identifiable {
        var id: String           // TaskItem.uid
        var title: String
        var fireAt: Date?        // dueDate; nil for pinned reminders without a time
        var isDone: Bool
        var colorTagRaw: String  // ReminderColorTag rawValue ("none", "red", …)
        var assignee: String     // empty == everyone
    }

    /// All today-relevant reminders, sorted by fireAt ascending.
    /// Pinned-but-undated reminders are sorted last.
    var entries: [Entry]

    /// When this snapshot was written. The widget displays "Updated
    /// 2 min ago" using this — surfaces staleness without needing a
    /// background refresh hook from the extension side.
    var generatedAt: Date
}

enum WidgetDataExporter {
    /// Filename inside the App Group container.
    private static let snapshotFilename = "today-reminders-snapshot.json"

    private static var snapshotURL: URL {
        AppGroup.containerURL.appendingPathComponent(snapshotFilename)
    }

    /// Read today's reminders from the given context, serialize them,
    /// and atomically write the snapshot. Safe to call from the main
    /// thread; the actual disk write is fast (small JSON blob).
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

        // Tickle the widget extension to reload via WidgetCenter. The
        // import is gated behind canImport because the WidgetKit
        // framework is iOS 14+ and this file otherwise compiles fine
        // on older targets / on macOS test runs.
        reloadTimelines()
    }

    /// Read the most-recent snapshot. Returns nil if the file doesn't
    /// exist yet (first launch before any export).
    static func loadSnapshot() -> TodayReminderSnapshot? {
        guard let data = try? Data(contentsOf: snapshotURL) else { return nil }
        return try? JSONDecoder().decode(TodayReminderSnapshot.self, from: data)
    }

    private static func reloadTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "TodayRemindersWidget")
        #endif
    }
}
