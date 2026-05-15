import Foundation
import CoreData

/// Tracks recent chore creations so the Home dashboard can show one-tap
/// "Quick Add" chips for the parent's most-used chores. Per-device list,
/// stored in UserDefaults — no sync, no schema impact.
struct QuickAddEntry: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var label: String
    var assignee: String
    var points: Int
    var category: String
    var savedAt: Date = Date()
}

enum QuickAddHistory {
    private static let key = "quickAddHistoryJSON"
    private static let maxEntries = 8

    static func load() -> [QuickAddEntry] {
        guard let data = UserDefaults.standard.string(forKey: key)?.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([QuickAddEntry].self, from: data)) ?? []
    }

    private static func save(_ entries: [QuickAddEntry]) {
        if let data = try? JSONEncoder().encode(entries),
           let json = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(json, forKey: key)
        }
    }

    /// Record a chore creation. Dedupes on (label, assignee) — most-recent
    /// wins. Capped at maxEntries.
    static func record(label: String, assignee: String?, points: Int, category: String) {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, points > 0 else { return }
        var entries = load()
        entries.removeAll { $0.label.lowercased() == trimmed.lowercased() && $0.assignee.lowercased() == (assignee ?? "").lowercased() }
        entries.insert(QuickAddEntry(label: trimmed, assignee: assignee ?? "", points: points, category: category), at: 0)
        if entries.count > maxEntries { entries = Array(entries.prefix(maxEntries)) }
        save(entries)
    }

    static func remove(_ entry: QuickAddEntry) {
        var entries = load()
        entries.removeAll { $0.id == entry.id }
        save(entries)
    }

    /// Wipe the entire history. Used by the "Clear all" affordance on the
    /// quick-add chip strip.
    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Spawns a single TaskItem from a saved chip with a due date of today
    /// (preserving assignee, points, category). Used by tap-to-clone.
    @discardableResult
    static func spawn(
        _ entry: QuickAddEntry,
        creator: String,
        in context: NSManagedObjectContext,
        household: Household?
    ) -> TaskItem {
        let t = TaskItem(
            context: context,
            task: entry.label,
            assignee: entry.assignee.isEmpty ? nil : entry.assignee,
            dueDate: Date(),
            category: entry.category,
            isCompleted: false,
            points: entry.points,
            createdBy: creator
        )
        if let h = household {
            context.assign(t, toStoreOf: h)
            t.household = h
        }
        try? context.save()
        return t
    }
}
