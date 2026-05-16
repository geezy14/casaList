import SwiftUI

/// Per-reminder color tag. Stored on-device only (UserDefaults map
/// keyed by TaskItem.uid) so each family member can categorize their
/// own reminder feed without polluting the shared schema.
enum ReminderColorTag: String, CaseIterable, Identifiable {
    case none, red, orange, yellow, green, blue, purple, pink

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none:   return "No tag"
        case .red:    return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green:  return "Green"
        case .blue:   return "Blue"
        case .purple: return "Purple"
        case .pink:   return "Pink"
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .none:   return .gray.opacity(0.4)
        case .red:    return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green:  return .green
        case .blue:   return .blue
        case .purple: return .purple
        case .pink:   return .pink
        }
    }
}

enum ReminderColorTagStore {
    private static let key = "reminderColorTags"

    private static func loadAll() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
    }

    private static func saveAll(_ map: [String: String]) {
        UserDefaults.standard.set(map, forKey: key)
    }

    static func tag(for uid: String) -> ReminderColorTag {
        let raw = loadAll()[uid] ?? "none"
        return ReminderColorTag(rawValue: raw) ?? .none
    }

    static func set(_ tag: ReminderColorTag, for uid: String) {
        var map = loadAll()
        if tag == .none {
            map.removeValue(forKey: uid)
        } else {
            map[uid] = tag.rawValue
        }
        saveAll(map)
    }
}
