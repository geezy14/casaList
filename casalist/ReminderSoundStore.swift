import Foundation

/// Per-reminder sound preference. Stored device-local in UserDefaults
/// keyed by TaskItem.uid — defaults to "play sound" for backward
/// compatibility. Only "silent" reminders show up in the map; the
/// absence of an entry means default behavior.
///
/// Future expansion: swap Bool for a String enum naming a bundled
/// .caf file once we ship a real sound picker. Storage shape stays
/// compatible because the absence of an entry still means default.
enum ReminderSoundStore {
    private static let silentKey = "reminderSilentSet"

    private static func loadSilent() -> Set<String> {
        let arr = UserDefaults.standard.stringArray(forKey: silentKey) ?? []
        return Set(arr)
    }

    private static func saveSilent(_ set: Set<String>) {
        UserDefaults.standard.set(Array(set), forKey: silentKey)
    }

    /// True if the reminder should play its notification sound.
    static func playsSound(for uid: String) -> Bool {
        !loadSilent().contains(uid)
    }

    static func setPlaysSound(_ on: Bool, for uid: String) {
        var s = loadSilent()
        if on {
            s.remove(uid)
        } else {
            s.insert(uid)
        }
        saveSilent(s)
    }
}
