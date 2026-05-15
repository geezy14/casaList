import Foundation
import CoreData
import SwiftUI

/// A reusable bundle of chores a parent can spawn for a family member with
/// one tap. e.g. "Morning Routine" → make bed (5pt) + brush teeth (5pt) + pack
/// bag (10pt). Templates are stored locally in UserDefaults (per device); the
/// TaskItems they spawn sync via CloudKit as normal.
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
    }

    var totalPoints: Int { items.reduce(0) { $0 + $1.points } }
}

enum ChoreRoutineStore {
    private static let key = "choreRoutinesJSON"

    static func load() -> [ChoreRoutineTemplate] {
        guard let data = UserDefaults.standard.string(forKey: key)?.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([ChoreRoutineTemplate].self, from: data)) ?? []
    }

    static func save(_ routines: [ChoreRoutineTemplate]) {
        guard let data = try? JSONEncoder().encode(routines),
              let json = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(json, forKey: key)
    }

    /// Spawn TaskItems in `context` for every item in `routine`, all assigned
    /// to `routine.assigneeName`, with optional due date. Returns the count
    /// inserted.
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
                category: "Chores",
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
