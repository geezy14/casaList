import Foundation

/// A flexible recurrence rule encoded as JSON inside the existing
/// `repeatKind` String field on TaskItem / FamilyEvent. Lets us support
/// custom cadences ("every 2 weeks on Friday", "every 3 hours") without
/// a Core Data + CloudKit schema change.
///
/// Encoding:
///   "custom:{\"i\":2,\"u\":\"w\",\"d\":6}"  →  every 2 weeks on Friday
///   "custom:{\"i\":3,\"u\":\"h\"}"         →  every 3 hours
///
/// Legacy strings ("", "daily", "weekly", "hourly", "every2h", etc.)
/// continue to work — the parser only kicks in for the `custom:` prefix.
struct RepeatRule: Codable, Equatable {
    enum Unit: String, Codable, CaseIterable, Equatable {
        case minute = "min"
        case hour = "h"
        case day = "d"
        case week = "w"
        case month = "m"

        var label: String {
            switch self {
            case .minute: return "Minutes"
            case .hour:   return "Hours"
            case .day:    return "Days"
            case .week:   return "Weeks"
            case .month:  return "Months"
            }
        }
        var singular: String {
            switch self {
            case .minute: return "minute"
            case .hour:   return "hour"
            case .day:    return "day"
            case .week:   return "week"
            case .month:  return "month"
            }
        }
    }

    /// "Every N <unit>" — N is at least 1.
    var interval: Int
    var unit: Unit
    /// iOS weekday convention: 1=Sun, 2=Mon, ..., 7=Sat. Only meaningful
    /// when `unit == .week`.
    var weekday: Int?

    // Compact JSON keys to keep the encoded form short.
    private enum CodingKeys: String, CodingKey {
        case interval = "i"
        case unit = "u"
        case weekday = "d"
    }

    /// Human-readable label for use in the picker / event row.
    var label: String {
        let nounPlural: String
        switch unit {
        case .minute: nounPlural = interval == 1 ? "minute" : "minutes"
        case .hour:   nounPlural = interval == 1 ? "hour"   : "hours"
        case .day:    nounPlural = interval == 1 ? "day"    : "days"
        case .week:   nounPlural = interval == 1 ? "week"   : "weeks"
        case .month:  nounPlural = interval == 1 ? "month"  : "months"
        }
        var s = interval == 1 ? "Every \(nounPlural.dropFirst(0))" : "Every \(interval) \(nounPlural)"
        // Simpler phrasing for "Every 1 X":
        if interval == 1 { s = "Every \(unit.singular)" }
        if unit == .week, let wd = weekday {
            let symbols = Calendar.current.standaloneWeekdaySymbols  // ["Sunday", ..., "Saturday"]
            let idx = max(0, min(symbols.count - 1, wd - 1))
            if interval == 1 {
                s = "Every \(symbols[idx])"
            } else if interval == 2 {
                s = "Every other \(symbols[idx])"
            } else {
                s = "Every \(interval) weeks on \(symbols[idx])"
            }
        }
        return s
    }

    /// JSON-encoded with `custom:` prefix. Safe to store in repeatKind.
    var encoded: String {
        let enc = JSONEncoder()
        enc.outputFormatting = []  // compact
        guard let data = try? enc.encode(self), let str = String(data: data, encoding: .utf8) else {
            return ""
        }
        return "custom:" + str
    }

    /// Parse a stored repeatKind string. Returns nil for legacy strings
    /// like "daily" / "hourly" — caller falls back to existing logic.
    static func decode(_ raw: String) -> RepeatRule? {
        guard raw.hasPrefix("custom:") else { return nil }
        let json = String(raw.dropFirst("custom:".count))
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(RepeatRule.self, from: data)
    }
}
