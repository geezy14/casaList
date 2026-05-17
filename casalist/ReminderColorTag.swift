import SwiftUI
import UIKit

/// Per-reminder color tag. Stored on-device only (UserDefaults map
/// keyed by TaskItem.uid) so each family member can categorize their
/// own reminder feed without polluting the shared schema.
///
/// Two flavors:
/// - **Named presets** (red / orange / etc.) — the quick-pick row of
///   swatches in the tag panel. Stored as the lowercase name.
/// - **Custom hex** — picked via the SwiftUI ColorPicker color wheel
///   for full freedom. Stored as "custom:#RRGGBB".
enum ReminderColorTag: Hashable, Identifiable {
    case none
    case red, orange, yellow, green, blue, purple, pink
    case custom(String)   // hex like "#FF8800"

    /// The fixed-palette presets shown as swatches. Custom is NOT
    /// in here — the UI renders it as a separate color-wheel button.
    static let presets: [ReminderColorTag] = [.none, .red, .orange, .yellow, .green, .blue, .purple, .pink]

    var id: String { rawValue }

    var rawValue: String {
        switch self {
        case .none:          return "none"
        case .red:           return "red"
        case .orange:        return "orange"
        case .yellow:        return "yellow"
        case .green:         return "green"
        case .blue:          return "blue"
        case .purple:        return "purple"
        case .pink:          return "pink"
        case .custom(let h): return "custom:" + h
        }
    }

    init?(rawValue: String) {
        switch rawValue {
        case "none":   self = .none
        case "red":    self = .red
        case "orange": self = .orange
        case "yellow": self = .yellow
        case "green":  self = .green
        case "blue":   self = .blue
        case "purple": self = .purple
        case "pink":   self = .pink
        default:
            if rawValue.hasPrefix("custom:") {
                let hex = String(rawValue.dropFirst("custom:".count))
                self = .custom(hex)
            } else {
                return nil
            }
        }
    }

    var label: String {
        switch self {
        case .none:           return "No tag"
        case .red:            return "Red"
        case .orange:         return "Orange"
        case .yellow:         return "Yellow"
        case .green:          return "Green"
        case .blue:           return "Blue"
        case .purple:         return "Purple"
        case .pink:           return "Pink"
        case .custom:         return "Custom"
        }
    }

    /// Is this a custom hex tag? Used by the UI to distinguish the
    /// color-wheel button from the preset swatches.
    var isCustom: Bool {
        if case .custom = self { return true }
        return false
    }

    var swiftUIColor: Color {
        switch self {
        case .none:           return .gray.opacity(0.4)
        case .red:            return .red
        case .orange:         return .orange
        case .yellow:         return .yellow
        case .green:          return .green
        case .blue:           return .blue
        case .purple:         return .purple
        case .pink:           return .pink
        case .custom(let h):  return Color(hex: h) ?? .gray.opacity(0.4)
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

// MARK: – Hex <-> Color helpers

extension Color {
    /// Parse "#RRGGBB" (or "RRGGBB") into a Color. Returns nil for
    /// anything we can't read — caller falls back to a default.
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Convert this Color to an "#RRGGBB" hex string. Goes through
    /// UIColor so we get the resolved RGB components even for system
    /// / accent / asset colors.
    var hexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X",
                      Int((r * 255).rounded()),
                      Int((g * 255).rounded()),
                      Int((b * 255).rounded()))
    }
}
