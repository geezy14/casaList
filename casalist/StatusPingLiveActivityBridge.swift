import Foundation
import CoreData
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Reconciles Casalist's status-ping records (TaskItem with
/// category="statusping") with iOS ActivityKit Live Activities.
///
/// Called after every remote-change sync. Walks the unexpired pings
/// in Core Data, starts a Live Activity for any that don't yet have
/// one, updates content for ones that changed, and ends activities
/// for pings that have been deleted or expired.
///
/// The receiving family's devices see the ping on their Lock Screen
/// + Dynamic Island until the announcement expiry passes. Sender's
/// own device skips the activity since they already know about it.
@available(iOS 16.2, *)
@MainActor
enum StatusPingLiveActivityBridge {
    /// Track which pings we've already started so the bridge is
    /// idempotent across multiple syncs in a session. Keyed by
    /// TaskItem.uid.
    private static var startedUids: Set<String> = []

    static func syncFromContext(_ context: NSManagedObjectContext, currentUser: String) {
        let trimmedUser = currentUser.trimmingCharacters(in: .whitespaces).lowercased()
        let now = Date()
        // Pull every live ping. Custom announcements use dueDate as
        // their expiry; quick presets without a date expire 15 min
        // after creation.
        let req: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        req.predicate = NSPredicate(
            format: "category == %@ AND deletedAt == nil",
            StatusPing.category
        )
        guard let pings = (try? context.fetch(req)) else { return }

        var activeUids: Set<String> = []

        for ping in pings {
            // Skip pings from this device's own user — they don't
            // need a Live Activity for their own announcement.
            if ping.createdBy.trimmingCharacters(in: .whitespaces).lowercased() == trimmedUser {
                continue
            }
            let expiry = ping.dueDate ?? ping.createdAt.addingTimeInterval(15 * 60)
            if expiry <= now { continue }   // already expired
            activeUids.insert(ping.uid)

            let (display, _) = StatusPing.parseLocationPing(ping.task)
            let emoji = extractLeadingEmoji(from: display)
            let messageMinusEmoji = stripLeadingEmoji(from: display, emoji: emoji)
            let senderColor = senderColorHex(in: context, name: ping.createdBy)

            if startedUids.contains(ping.uid) {
                // Update in place — sender may have edited the message
                // or changed the expiry.
                LiveActivityManager.update(
                    taskUid: ping.uid,
                    message: messageMinusEmoji,
                    emoji: emoji,
                    expiresAt: expiry
                )
            } else {
                _ = LiveActivityManager.start(
                    taskUid: ping.uid,
                    sender: ping.createdBy,
                    senderColorHex: senderColor,
                    message: messageMinusEmoji,
                    emoji: emoji,
                    expiresAt: expiry
                )
                startedUids.insert(ping.uid)
            }
        }

        // End any tracked activities that no longer have a live ping.
        for uid in startedUids.subtracting(activeUids) {
            LiveActivityManager.end(taskUid: uid)
            startedUids.remove(uid)
        }
    }

    /// Lookup a sender's avatar color in the local FamilyMember
    /// records so the Live Activity stripe matches their app color.
    /// Defaults to a neutral coral when not found.
    private static func senderColorHex(in context: NSManagedObjectContext, name: String) -> Int64 {
        let trimmed = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return 0xC97357 }
        let req: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
        req.predicate = NSPredicate(format: "deletedAt == nil")
        let members = (try? context.fetch(req)) ?? []
        if let m = members.first(where: { $0.name.lowercased() == trimmed }) {
            return Int64(m.colorHex)
        }
        return 0xC97357
    }

    /// Pull a single leading emoji off a ping message (Status pings
    /// preset format: "🚗 On my way" -> emoji "🚗", message "On my way").
    private static func extractLeadingEmoji(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.unicodeScalars.first,
              first.properties.isEmojiPresentation || first.properties.generalCategory == .otherSymbol else {
            return ""
        }
        // Capture the full grapheme cluster (handles emoji ZWJ sequences).
        if let firstChar = trimmed.first, firstChar.isEmoji {
            return String(firstChar)
        }
        return ""
    }

    private static func stripLeadingEmoji(from text: String, emoji: String) -> String {
        guard !emoji.isEmpty else { return text }
        return text.replacingOccurrences(of: emoji, with: "", options: [.anchored])
            .trimmingCharacters(in: .whitespaces)
    }
}

private extension Character {
    var isEmoji: Bool {
        unicodeScalars.contains { $0.properties.isEmojiPresentation || $0.properties.generalCategory == .otherSymbol }
    }
}
