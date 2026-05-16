import Foundation

/// Shared identifier and helpers for the App Group container used by
/// the main app + Widget Extension + Live Activity extension.
///
/// On first Xcode build with the Widget Extension target wired in,
/// automatic signing will:
/// - Add the group to the App ID's entitlements via developer.apple.com
/// - Add the entitlement key to both target's entitlement files
/// - Provision dev profiles that include the App Group capability
///
/// At runtime, both targets read/write a shared UserDefaults and a
/// shared filesystem container at this group's URL.
enum AppGroup {
    static let identifier = "group.com.gbrown10.casalist"

    /// UserDefaults suite shared with the widget. Use for lightweight
    /// flags ("widgets enabled", per-widget settings, the last-seen
    /// snapshot timestamp). NOT for the full data dump — that goes
    /// into a file in the container.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    /// Shared filesystem container URL. Cached so we don't re-resolve
    /// for every write. Falls back to the app's Documents directory
    /// if the group isn't entitled yet — useful during local dev
    /// before the Widget Extension target is added to Xcode.
    static var containerURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return url
        }
        // Fallback: app's Documents dir. Widgets can't read this, but
        // the main app's own code can still write/read for testing.
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}
