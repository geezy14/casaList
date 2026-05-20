import Foundation

/// Packs an optional web link into a FamilyGoal's existing `note` field so
/// a requester can attach the URL of an item they want (e.g. an Amazon
/// product page) without a Core Data / CloudKit schema change.
///
/// Storage format inside `note`:
///   "<human note>\u{0001}url:<the url>"
///
/// The U+0001 (SOH) control character is the separator — it never appears
/// in user-typed text, so the human note and the URL round-trip cleanly.
/// A note with no link is just the plain string (no separator), so legacy
/// notes keep working untouched.
enum GoalLink {
    private static let sep = "\u{0001}url:"

    /// Combine a human note and an optional URL into the stored value.
    static func encode(note: String, url: String) -> String {
        let n = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let u = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !u.isEmpty else { return n }
        return n + sep + u
    }

    /// The human-readable note with any packed URL stripped off.
    static func note(from stored: String) -> String {
        guard let r = stored.range(of: sep) else { return stored }
        return String(stored[..<r.lowerBound])
    }

    /// The packed URL, if present and non-empty.
    static func url(from stored: String) -> String? {
        guard let r = stored.range(of: sep) else { return nil }
        let u = String(stored[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return u.isEmpty ? nil : u
    }

    /// A `URL` for SwiftUI `Link`, normalizing a bare "amazon.com/…" into
    /// "https://amazon.com/…". Returns nil if the string can't form a URL.
    static func resolvedURL(from stored: String) -> URL? {
        guard let raw = url(from: stored) else { return nil }
        if raw.lowercased().hasPrefix("http://") || raw.lowercased().hasPrefix("https://") {
            return URL(string: raw)
        }
        return URL(string: "https://" + raw)
    }
}
