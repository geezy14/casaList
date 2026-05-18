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
        case year = "y"

        var label: String {
            switch self {
            case .minute: return "Minutes"
            case .hour:   return "Hours"
            case .day:    return "Days"
            case .week:   return "Weeks"
            case .month:  return "Months"
            case .year:   return "Years"
            }
        }
        var singular: String {
            switch self {
            case .minute: return "minute"
            case .hour:   return "hour"
            case .day:    return "day"
            case .week:   return "week"
            case .month:  return "month"
            case .year:   return "year"
            }
        }
    }

    /// "Every N <unit>" — N is at least 1.
    var interval: Int
    var unit: Unit
    /// iOS weekday convention: 1=Sun, 2=Mon, ..., 7=Sat. Only meaningful
    /// when `unit == .week` and `weekdays` is empty.
    var weekday: Int?
    /// Multi-weekday set ("every Mon, Wed, Fri" or "every weekday"). When
    /// non-empty supersedes `weekday`. Each Int is iOS weekday convention.
    /// Only meaningful when `unit == .week`.
    var weekdays: [Int]?

    // Compact JSON keys to keep the encoded form short.
    private enum CodingKeys: String, CodingKey {
        case interval = "i"
        case unit = "u"
        case weekday = "d"
        case weekdays = "dd"
    }

    /// Effective weekday list. `weekdays` wins when set; otherwise falls
    /// back to a single-element list built from `weekday`. Returns []
    /// when neither is set.
    var effectiveWeekdays: [Int] {
        if let wds = weekdays, !wds.isEmpty { return wds.sorted() }
        if let wd = weekday { return [wd] }
        return []
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
        case .year:   nounPlural = interval == 1 ? "year"   : "years"
        }
        var s = interval == 1 ? "Every \(nounPlural.dropFirst(0))" : "Every \(interval) \(nounPlural)"
        if interval == 1 { s = "Every \(unit.singular)" }
        if unit == .week {
            let wds = effectiveWeekdays
            let symbols = Calendar.current.standaloneWeekdaySymbols
            let shorts = Calendar.current.shortStandaloneWeekdaySymbols
            // Special cases for multi-weekday sets
            if Set(wds) == Set([2, 3, 4, 5, 6]) {
                s = interval == 1 ? "Every weekday" : "Every \(interval) weeks on weekdays"
            } else if Set(wds) == Set([1, 7]) {
                s = interval == 1 ? "Every weekend" : "Every \(interval) weeks on weekends"
            } else if wds.count > 1 {
                let names = wds.map { shorts[max(0, min(6, $0 - 1))] }.joined(separator: ", ")
                s = interval == 1 ? "Every week on \(names)" : "Every \(interval) weeks on \(names)"
            } else if let wd = wds.first {
                let idx = max(0, min(symbols.count - 1, wd - 1))
                if interval == 1 {
                    s = "Every \(symbols[idx])"
                } else if interval == 2 {
                    s = "Every other \(symbols[idx])"
                } else {
                    s = "Every \(interval) weeks on \(symbols[idx])"
                }
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

    /// Map a legacy preset string ("daily", "hourly", "every2h", …) to
    /// an equivalent RepeatRule. Returns nil for unknown strings. Used
    /// by the picker to pre-fill its UI state when editing a reminder
    /// that was created before the custom sheet existed.
    static func fromLegacy(_ raw: String) -> RepeatRule? {
        switch raw {
        case "hourly":   return RepeatRule(interval: 1,  unit: .hour,  weekday: nil)
        case "every2h":  return RepeatRule(interval: 2,  unit: .hour,  weekday: nil)
        case "every4h":  return RepeatRule(interval: 4,  unit: .hour,  weekday: nil)
        case "every8h":  return RepeatRule(interval: 8,  unit: .hour,  weekday: nil)
        case "every12h": return RepeatRule(interval: 12, unit: .hour,  weekday: nil)
        case "daily":    return RepeatRule(interval: 1,  unit: .day,   weekday: nil)
        case "weekly":   return RepeatRule(interval: 1,  unit: .week,  weekday: nil)
        case "monthly":  return RepeatRule(interval: 1,  unit: .month, weekday: nil)
        case "yearly":   return RepeatRule(interval: 1,  unit: .year,  weekday: nil)
        default:         return nil
        }
    }

    /// If the rule matches one of the legacy preset shapes, return that
    /// string so callers can store it as the existing repeatKind value
    /// (preserves all the existing `repeatKind == "hourly"` filters,
    /// notification scheduling paths, etc.). Returns nil when the rule
    /// only expresses as a `custom:…` JSON blob.
    var legacyEquivalent: String? {
        if weekday != nil { return nil }   // weekday-specific rules are always custom
        if let wds = weekdays, !wds.isEmpty { return nil } // multi-weekday is always custom
        switch (unit, interval) {
        case (.hour, 1):   return "hourly"
        case (.hour, 2):   return "every2h"
        case (.hour, 4):   return "every4h"
        case (.hour, 8):   return "every8h"
        case (.hour, 12):  return "every12h"
        case (.day, 1):    return "daily"
        case (.week, 1):   return "weekly"
        case (.month, 1):  return "monthly"
        case (.year, 1):   return "yearly"
        default:           return nil
        }
    }

    /// Save form: legacy preset string when available, otherwise the
    /// JSON-encoded custom form. Empty string means "no repeat" — use
    /// the caller-side toggle for that.
    var saveForm: String {
        legacyEquivalent ?? encoded
    }
}
