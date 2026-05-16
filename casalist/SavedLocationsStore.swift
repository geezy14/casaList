import Foundation

/// Device-local list of frequent locations ("Home", "Work", "School",
/// etc.) the user defines once in Settings and reuses across
/// location-based reminders. Stays out of CloudKit because each family
/// member's "Home" address can differ.
struct SavedLocation: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var label: String           // "Home"
    var address: String         // human-readable, displayed under the label
    var latitude: Double
    var longitude: Double
}

enum SavedLocationsStore {
    private static let key = "savedLocations"

    static func loadAll() -> [SavedLocation] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([SavedLocation].self, from: data)) ?? []
    }

    static func save(_ all: [SavedLocation]) {
        guard let data = try? JSONEncoder().encode(all) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func add(_ loc: SavedLocation) {
        var all = loadAll()
        all.append(loc)
        save(all)
    }

    static func remove(id: UUID) {
        save(loadAll().filter { $0.id != id })
    }
}
