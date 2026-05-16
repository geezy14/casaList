import Foundation

/// Device-local custom sort order for the Reminders grid. UIDs that
/// aren't in the map fall to the bottom (sorted by createdAt as
/// before). Long-press "Pin to top" / "Send to bottom" rewrites this
/// dictionary so each device keeps its own preferred ordering.
enum ReminderOrderStore {
    private static let key = "reminderOrderMap"

    private static func loadAll() -> [String: Double] {
        UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:]
    }

    private static func saveAll(_ map: [String: Double]) {
        UserDefaults.standard.set(map, forKey: key)
    }

    /// Reading order. Lower number = appears earlier. Missing entries
    /// return `.greatestFiniteMagnitude` so they sort after explicit
    /// ones — fall-back keeps untouched reminders in creation order.
    static func order(for uid: String) -> Double {
        loadAll()[uid] ?? .greatestFiniteMagnitude
    }

    /// Move `uid` to the very top by giving it a position below the
    /// current minimum. Doesn't renumber other entries — sparse
    /// numbering keeps subsequent updates O(1).
    static func pinToTop(_ uid: String) {
        var map = loadAll()
        let minExisting = map.values.min() ?? 0
        map[uid] = minExisting - 1
        saveAll(map)
    }

    /// Move `uid` to the very bottom by giving it a position above
    /// the current maximum (but keep it finite).
    static func sendToBottom(_ uid: String) {
        var map = loadAll()
        let maxExisting = map.values.filter { $0 < .greatestFiniteMagnitude }.max() ?? 0
        map[uid] = maxExisting + 1
        saveAll(map)
    }

    static func clear(for uid: String) {
        var map = loadAll()
        map.removeValue(forKey: uid)
        saveAll(map)
    }
}
