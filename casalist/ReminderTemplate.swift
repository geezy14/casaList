import Foundation

/// Saved reminder template — title + cadence + assignee + location +
/// stop time. Lives in UserDefaults so it stays device-local (no
/// CloudKit) and a fresh install starts with no templates.
///
/// Photos and one-shot due dates are intentionally NOT templated:
/// - Photos belong to a specific reminder instance.
/// - A fixed dueDate ("Aug 14 at 3pm") doesn't make sense to copy.
///   Cadence rules (daily / weekly / hourly / custom) ARE templated
///   because they describe a pattern rather than a moment.
struct ReminderTemplate: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String          // template label, shown in the picker
    var title: String         // the reminder's title text
    var repeatKind: String    // legacy preset or "custom:{...}"
    var repeatEndMinutes: Int64
    var assignee: String      // empty == whole household
    var locationLat: Double
    var locationLng: Double
    var locationRadius: Double
    var locationOnArrive: Bool
    var locationName: String
    var hasFireTime: Bool     // when no repeat, do we want a one-shot date?
    var fireHour: Int         // hour of the day (0-23) used if hasFireTime
    var fireMinute: Int       // minute (0-59)
}

/// Storage facade — kept simple because the list is tiny per user.
enum ReminderTemplateStore {
    private static let key = "reminderTemplates"

    static func loadAll() -> [ReminderTemplate] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([ReminderTemplate].self, from: data)) ?? []
    }

    static func save(_ templates: [ReminderTemplate]) {
        guard let data = try? JSONEncoder().encode(templates) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func add(_ t: ReminderTemplate) {
        var all = loadAll()
        all.append(t)
        save(all)
    }

    static func remove(id: UUID) {
        let filtered = loadAll().filter { $0.id != id }
        save(filtered)
    }
}
