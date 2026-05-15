import Foundation
import CoreData
import SwiftUI

/// A reusable bundle of chores a parent can spawn for a family member with
/// one tap. e.g. "Morning Routine" → make bed (5pt) + brush teeth (5pt) + pack
/// bag (10pt). Templates live as JSON on the current Household so the list
/// syncs across family members through the shared CloudKit store.
///
/// NOTE: requires the `routinesJSON` attribute on Household + the matching
/// CloudKit schema redeploy before sync works in Production. Routines are
/// currently #if DEBUG-gated, so until the redeploy ships, the field is
/// device-local for the dev build.
struct ChoreRoutineTemplate: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var assigneeName: String
    var symbol: String = "sun.max.fill"
    var items: [Item] = []

    struct Item: Identifiable, Codable, Equatable {
        var id: UUID = UUID()
        var label: String
        var points: Int
        /// Per-item Core Data category — mirrors the same set used by
        /// AddTaskView ("Chores", "home", "groceries", "Maintenance").
        /// Defaults to "Chores" when decoded from older JSON.
        var category: String = "Chores"

        // Back-compat decoder: older saved JSON has no `category`.
        private enum CodingKeys: String, CodingKey { case id, label, points, category }
        init(id: UUID = UUID(), label: String, points: Int, category: String = "Chores") {
            self.id = id; self.label = label; self.points = points; self.category = category
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
            self.label = (try? c.decode(String.self, forKey: .label)) ?? ""
            self.points = (try? c.decode(Int.self, forKey: .points)) ?? 0
            self.category = (try? c.decode(String.self, forKey: .category)) ?? "Chores"
        }
    }

    var totalPoints: Int { items.reduce(0) { $0 + $1.points } }
}

enum ChoreRoutineStore {
    private static let legacyKey = "choreRoutinesJSON"

    /// Load routines for a specific household. Falls back to the legacy
    /// UserDefaults store the first time so anything created on the device
    /// before the Core Data migration is preserved.
    static func load(from household: Household?) -> [ChoreRoutineTemplate] {
        if let h = household, !h.routinesJSON.isEmpty,
           let data = h.routinesJSON.data(using: .utf8),
           let arr = try? JSONDecoder().decode([ChoreRoutineTemplate].self, from: data) {
            return arr
        }
        if let data = UserDefaults.standard.string(forKey: legacyKey)?.data(using: .utf8),
           let arr = try? JSONDecoder().decode([ChoreRoutineTemplate].self, from: data) {
            return arr
        }
        return []
    }

    /// Save routines onto the supplied household. If no household exists yet
    /// we fall back to UserDefaults so the parent's edits aren't lost.
    static func save(_ routines: [ChoreRoutineTemplate], to household: Household?, context: NSManagedObjectContext?) {
        guard let data = try? JSONEncoder().encode(routines),
              let json = String(data: data, encoding: .utf8) else { return }
        if let h = household {
            h.routinesJSON = json
            try? context?.save()
            UserDefaults.standard.removeObject(forKey: legacyKey)
        } else {
            UserDefaults.standard.set(json, forKey: legacyKey)
        }
    }

    /// Spawn TaskItems in `context` for every item in `routine`, all assigned
    /// to `routine.assigneeName`, with optional due date. Each item's
    /// `category` flows through to the spawned task.
    @discardableResult
    static func spawn(
        _ routine: ChoreRoutineTemplate,
        creator: String,
        dueDate: Date?,
        in context: NSManagedObjectContext,
        household: Household?
    ) -> Int {
        for item in routine.items {
            let t = TaskItem(
                context: context,
                task: item.label,
                assignee: routine.assigneeName,
                dueDate: dueDate,
                category: item.category,
                isCompleted: false,
                points: item.points,
                createdBy: creator
            )
            if let h = household {
                context.assign(t, toStoreOf: h)
                t.household = h
            }
        }
        try? context.save()
        return routine.items.count
    }
}

/// Curated SF Symbols a parent can pick when naming a routine.
enum RoutineSymbol {
    static let options: [String] = [
        "sun.max.fill", "moon.fill", "sparkles", "bed.double.fill",
        "fork.knife", "shower.fill", "backpack.fill", "bus.fill",
        "book.fill", "gamecontroller.fill", "trash.fill", "dog.fill",
        "leaf.fill", "wand.and.stars",
    ]
}

/// Category choices for an individual routine item — same vocabulary used
/// elsewhere in the app (AddTaskView).
enum RoutineItemCategory {
    static let options: [(label: String, tag: String)] = [
        ("Chores", "Chores"),
        ("Home", "home"),
        ("Groceries", "groceries"),
        ("Maintenance", "Maintenance"),
    ]
}
