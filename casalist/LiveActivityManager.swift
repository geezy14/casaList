import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// Bridge between Casalist's status-ping flow and iOS ActivityKit.
/// The main app calls `start(...)` when a new status ping lands on
/// this device that we want to surface as a Lock Screen / Dynamic
/// Island card. `update(...)` reflects sender-side edits.
/// `end(uid:)` dismisses when the ping expires, is deleted, or the
/// sender clears it.
///
/// Renders via the Widget Extension target's StatusPingActivity
/// widget (created when the Widget Extension target is wired into
/// Xcode — see docs/v2-backlog.md and the 1.8 roadmap entry).
@available(iOS 16.2, *)
@MainActor
enum LiveActivityManager {
    /// Start (or re-start) a Live Activity for the given ping.
    /// Idempotent: if one already exists for this taskUid, we update
    /// it in place instead of stacking duplicates.
    @discardableResult
    static func start(
        taskUid: String,
        sender: String,
        senderColorHex: Int64,
        message: String,
        emoji: String,
        expiresAt: Date
    ) -> String? {
        // Bail when the system has disabled Live Activities entirely.
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }

        let attributes = StatusPingActivityAttributes(
            sender: sender,
            senderColorHex: senderColorHex,
            taskUid: taskUid
        )
        let state = StatusPingActivityAttributes.ContentState(
            message: message,
            emoji: emoji,
            expiresAt: expiresAt
        )

        // Already-running activity for this uid? Update it in place.
        if let existing = activeActivity(for: taskUid) {
            Task {
                await existing.update(
                    ActivityContent(state: state, staleDate: expiresAt)
                )
            }
            return existing.id
        }

        do {
            let activity = try Activity<StatusPingActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: expiresAt),
                pushType: nil
            )
            return activity.id
        } catch {
            // ActivityKit start can fail when the user is in low-power
            // mode, hit a system rate limit, or the build doesn't have
            // the Widget Extension wired in yet. Swallow silently — the
            // ping push still lands as a regular banner.
            return nil
        }
    }

    /// Push an updated state into an existing activity. No-op if no
    /// activity exists for this uid.
    static func update(
        taskUid: String,
        message: String,
        emoji: String,
        expiresAt: Date
    ) {
        guard let existing = activeActivity(for: taskUid) else { return }
        let state = StatusPingActivityAttributes.ContentState(
            message: message,
            emoji: emoji,
            expiresAt: expiresAt
        )
        Task {
            await existing.update(
                ActivityContent(state: state, staleDate: expiresAt)
            )
        }
    }

    /// Dismiss the activity for the given uid. Safe to call when none
    /// is running.
    static func end(taskUid: String) {
        guard let existing = activeActivity(for: taskUid) else { return }
        Task {
            await existing.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Best-effort lookup — ActivityKit's `Activity<T>.activities` is
    /// an in-memory list; if the app was killed and relaunched, the
    /// list re-populates from the OS on the first access.
    private static func activeActivity(for taskUid: String) -> Activity<StatusPingActivityAttributes>? {
        Activity<StatusPingActivityAttributes>.activities.first {
            $0.attributes.taskUid == taskUid
        }
    }
}
#endif
