import Foundation
import CoreData

/// Per-reminder streak tracking. Each reminder TaskItem (category =
/// "reminders" with a repeating kind) keeps its own consecutive-completion
/// count keyed by the task's UID. Storage lives in UserDefaults — per-device,
/// no CloudKit sync, no schema impact.
///
/// "On streak" depends on the repeat kind:
///   - daily   → completed within 1 day of the previous completion
///   - weekly  → completed within 1 week of the previous completion
///   - monthly → completed within 1 month of the previous completion
///   - yearly  → completed within 1 year of the previous completion
///   - hourly / everyNh / one-shot → no streak concept (returns 0)
enum ReminderStreak {
    struct State: Codable {
        var current: Int
        var best: Int
        var lastCompletionAt: Date
    }

    private static func key(_ uid: String) -> String { "reminder_streak_\(uid)" }

    static func load(for taskUid: String) -> State? {
        guard let data = UserDefaults.standard.data(forKey: key(taskUid)) else { return nil }
        return try? JSONDecoder().decode(State.self, from: data)
    }

    static func current(for taskUid: String) -> Int {
        load(for: taskUid)?.current ?? 0
    }

    static func best(for taskUid: String) -> Int {
        load(for: taskUid)?.best ?? 0
    }

    /// Called from FamilyPoints when a reminder TaskItem completes (either
    /// the toggle path or the recurring-advance path). Computes whether this
    /// completion continues the existing streak or restarts it.
    static func recordCompletion(for task: TaskItem) {
        // Only reminders streak. Other categories use FamilyProgress.
        guard task.category.lowercased() == "reminders" else { return }
        let kind = task.effectiveRepeatKind
        guard supportsStreak(kind) else { return }
        guard !task.uid.isEmpty else { return }

        let now = Date()
        let prev = load(for: task.uid)
        let newCurrent: Int = {
            guard let prev = prev else { return 1 }
            return continuesStreak(from: prev.lastCompletionAt, now: now, kind: kind)
                ? prev.current + 1
                : 1
        }()
        let newBest = max(newCurrent, prev?.best ?? 0)
        let state = State(current: newCurrent, best: newBest, lastCompletionAt: now)
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: key(task.uid))
        }
    }

    /// Drops the stored streak for a single reminder. Called when the user
    /// edits the schedule kind so a fresh cadence starts cleanly.
    static func reset(for taskUid: String) {
        UserDefaults.standard.removeObject(forKey: key(taskUid))
    }

    /// Used by "Reset all data" — clears every reminder streak in one pass.
    static func clearAll() {
        let d = UserDefaults.standard
        for k in d.dictionaryRepresentation().keys where k.hasPrefix("reminder_streak_") {
            d.removeObject(forKey: k)
        }
    }

    // MARK: – helpers

    private static func supportsStreak(_ kind: String) -> Bool {
        ["daily", "weekly", "monthly", "yearly"].contains(kind)
    }

    /// True if the gap between the previous completion and "now" is short
    /// enough for the streak to still be alive given the cadence.
    private static func continuesStreak(from previous: Date, now: Date, kind: String) -> Bool {
        let cal = Calendar.current
        switch kind {
        case "daily":
            let days = cal.dateComponents([.day],
                                          from: cal.startOfDay(for: previous),
                                          to: cal.startOfDay(for: now)).day ?? 0
            return days <= 1 && days >= 0
        case "weekly":
            let weeks = cal.dateComponents([.weekOfYear],
                                           from: cal.startOfDay(for: previous),
                                           to: cal.startOfDay(for: now)).weekOfYear ?? 0
            return weeks <= 1 && weeks >= 0
        case "monthly":
            let months = cal.dateComponents([.month],
                                            from: cal.startOfDay(for: previous),
                                            to: cal.startOfDay(for: now)).month ?? 0
            return months <= 1 && months >= 0
        case "yearly":
            let years = cal.dateComponents([.year],
                                           from: cal.startOfDay(for: previous),
                                           to: cal.startOfDay(for: now)).year ?? 0
            return years <= 1 && years >= 0
        default:
            return false
        }
    }
}
