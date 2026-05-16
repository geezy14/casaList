import Foundation

/// On-device log of reminder activity (fired in foreground, marked
/// done from the lock screen, snoozed). Local-only — same rationale
/// as photo attachments: doesn't belong in CloudKit, family members
/// don't need each other's reminder logs.
///
/// Storage: JSON array at `<Documents>/reminder-history.json`,
/// newest-first, capped at 500 entries.
enum ReminderHistory {
    enum Action: String, Codable {
        case fired       // notification presented while app foregrounded
        case markedDone  // tapped "Mark done" from lock screen / in-app
        case snoozed     // tapped a Snooze action
    }

    struct Entry: Codable, Identifiable {
        var id: UUID = UUID()
        var timestamp: Date
        var taskUid: String
        var taskName: String
        var action: Action
    }

    private static let maxEntries = 500

    private static var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("reminder-history.json")
    }

    /// Append a new entry. Caps total at `maxEntries`. Safe to call
    /// from any thread because file I/O is atomic.
    static func record(taskUid: String, taskName: String, action: Action) {
        var entries = load()
        let entry = Entry(
            timestamp: Date(),
            taskUid: taskUid,
            taskName: taskName,
            action: action
        )
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        save(entries)
    }

    /// Newest-first. Empty array on first run or read error.
    static func load() -> [Entry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    /// Wipe the log. Exposed for the "Clear history" button.
    static func clearAll() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static func save(_ entries: [Entry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
