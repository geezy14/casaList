import Foundation

/// Per-device temporary mute of a family member's outbound activity
/// pushes (status pings, announcements, grocery activity, reward
/// requests, etc.). When a member is muted, this device suppresses
/// notifications they trigger — but the activity still happens in
/// CloudKit and shows up in the app. Useful when Dakoda is at work
/// and shouldn't be pinging your phone.
///
/// Storage: UserDefaults dictionary mapping member name (lowercased,
/// trimmed) → unix timestamp at which the mute expires. Names that
/// aren't in the map, OR have a timestamp in the past, are NOT muted.
enum MemberMuteStore {
    enum Duration: String, CaseIterable, Identifiable {
        case off
        case oneHour
        case fourHours
        case untilTomorrow

        var id: String { rawValue }

        var label: String {
            switch self {
            case .off:            return "Off"
            case .oneHour:        return "Mute for 1 hour"
            case .fourHours:      return "Mute for 4 hours"
            case .untilTomorrow:  return "Mute until tomorrow"
            }
        }

        /// Computes an absolute expiry. `.off` returns nil so the
        /// caller knows to clear the entry, not stash a past date.
        var expiry: Date? {
            let cal = Calendar.current
            let now = Date()
            switch self {
            case .off:
                return nil
            case .oneHour:
                return now.addingTimeInterval(3600)
            case .fourHours:
                return now.addingTimeInterval(4 * 3600)
            case .untilTomorrow:
                // 6 AM tomorrow — typical "deal with it then" anchor.
                let tomorrowStart = cal.startOfDay(for: now.addingTimeInterval(86400))
                return cal.date(bySettingHour: 6, minute: 0, second: 0, of: tomorrowStart) ?? tomorrowStart
            }
        }
    }

    private static let key = "memberMutes"

    private static func loadAll() -> [String: TimeInterval] {
        UserDefaults.standard.dictionary(forKey: key) as? [String: TimeInterval] ?? [:]
    }

    private static func saveAll(_ map: [String: TimeInterval]) {
        UserDefaults.standard.set(map, forKey: key)
    }

    private static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// True if the named member's pushes should be suppressed RIGHT
    /// NOW on this device.
    static func isMuted(_ name: String) -> Bool {
        let key = normalize(name)
        guard let expiry = loadAll()[key] else { return false }
        return Date().timeIntervalSince1970 < expiry
    }

    /// Returns the expiry date if currently muted, nil otherwise.
    /// Used for "Muted until 3:42 PM" footer display.
    static func mutedUntil(_ name: String) -> Date? {
        let key = normalize(name)
        guard let expiry = loadAll()[key] else { return nil }
        let date = Date(timeIntervalSince1970: expiry)
        return date > Date() ? date : nil
    }

    static func apply(_ duration: Duration, to name: String) {
        let normalized = normalize(name)
        guard !normalized.isEmpty else { return }
        var map = loadAll()
        if let until = duration.expiry {
            map[normalized] = until.timeIntervalSince1970
        } else {
            map.removeValue(forKey: normalized)
        }
        saveAll(map)
    }

    /// Optional housekeeping: drop expired entries so the dict doesn't
    /// grow unbounded.
    static func purgeExpired() {
        let now = Date().timeIntervalSince1970
        let map = loadAll().filter { $1 > now }
        saveAll(map)
    }
}
