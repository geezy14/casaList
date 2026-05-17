import Foundation

/// JSON snapshot of "today's reminders" written by the main app and
/// read by the Widget Extension via the shared App Group container.
///
/// **Shared between targets.** Add this file to BOTH the casalist
/// target and the CasalistWidgetsExtension target via Xcode's File
/// Inspector → Target Membership.
///
/// Intentionally minimal — only the fields the widget views need.
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

    /// Today's reminders, sorted by fireAt ascending; pinned-undated
    /// reminders fall to the end.
    var entries: [Entry]

    /// Wall-clock time the snapshot was written. Widget shows
    /// "Updated 2 min ago" using this.
    var generatedAt: Date

    /// Read the most-recent snapshot from disk. Used by the widget
    /// timeline provider AND by main-app diagnostic code. Returns
    /// nil if the file doesn't exist yet (first launch before any
    /// export).
    static func load() -> TodayReminderSnapshot? {
        let url = AppGroup.containerURL.appendingPathComponent("today-reminders-snapshot.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(TodayReminderSnapshot.self, from: data)
    }
}
