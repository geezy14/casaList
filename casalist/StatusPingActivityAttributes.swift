import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// Live Activity for a Casalist status ping. Lives on the receiving
/// devices' Lock Screen + Dynamic Island for the duration of the
/// ping's expiry window. Wraps the family-wide "On my way" /
/// "At the store" announcement into a glanceable card.
///
/// `ActivityAttributes` immutables — set once at activity start, never
/// change. Use for the sender's name + the ping uid so we can target
/// updates / dismissals by uid.
///
/// `ContentState` mutables — updated via `Activity.update` whenever
/// the sender edits their announcement message or changes its expiry.
@available(iOS 16.1, *)
struct StatusPingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Display message ("On my way", "At the store", or a custom
        /// announcement). Shown as the card's primary text.
        public var message: String

        /// Optional leading emoji ("🚗", "🛒", …). Pulled from the
        /// preset list in StatusPingSheet. Empty string when the
        /// sender wrote a custom no-emoji message.
        public var emoji: String

        /// Absolute Date the ping should auto-dismiss. The Live
        /// Activity stops itself when iOS clock hits this; we also
        /// call Activity.end as a backstop.
        public var expiresAt: Date
    }

    /// Sender's display name. Shown as the card's secondary text /
    /// "FROM" label.
    public var sender: String

    /// Sender's avatar color (Casalist FamilyMember.colorHex). Used
    /// as the card accent so each family member's ping has a
    /// recognizable color stripe.
    public var senderColorHex: Int64

    /// Casalist TaskItem.uid (the underlying status-ping record).
    /// Used to target updates / dismissals.
    public var taskUid: String
}
#endif
