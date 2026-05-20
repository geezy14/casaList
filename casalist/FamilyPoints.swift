import Foundation
import CoreData

/// Helpers for awarding/revoking task points and progressing recurring tasks
/// when their circle is tapped.
enum FamilyPoints {
    static func toggle<S: Sequence>(_ t: TaskItem, in members: S) where S.Element == FamilyMember {
        let isRecurring = !t.effectiveRepeatKind.isEmpty
        if isRecurring {
            advanceRecurring(t, in: members)
        } else {
            t.isCompleted.toggle()
            if t.isCompleted {
                t.completedAt = Date()
                award(t, in: members)
            } else {
                t.completedAt = nil
                revoke(t, in: members)
            }
        }
    }

    private static func advanceRecurring<S: Sequence>(_ t: TaskItem, in members: S) where S.Element == FamilyMember {
        award(t, in: members)
        // Recurring tasks never stay "completed", but stamp completedAt
        // each time so WHAT'S NEW and My Wins can show the most recent
        // pass-through with an accurate timestamp.
        t.completedAt = Date()
        t.completionCount += 1
        if let due = t.dueDate {
            t.dueDate = nextOccurrence(after: due, kind: t.effectiveRepeatKind)
        }
        // Reminders carry their own per-task 🔥 streak counter — bump it
        // here so daily/weekly/monthly/yearly reminders earn a streak when
        // checked off on cadence.
        ReminderStreak.recordCompletion(for: t)
    }

    private static func nextOccurrence(after date: Date, kind: String) -> Date {
        let cal = Calendar.current
        // Custom rules (custom:{…} JSON — every N units, specific weekday(s),
        // multi-weekday) advance via RepeatRule so the dueDate actually rolls
        // forward. Without this they'd hit the default and never move, leaving
        // the chore stuck "active" and its schedule frozen.
        if let rule = RepeatRule.decode(kind) {
            return rule.nextDate(after: date)
        }
        switch kind {
        case "hourly":   return cal.date(byAdding: .hour, value: 1, to: date) ?? date
        case "every2h":  return cal.date(byAdding: .hour, value: 2, to: date) ?? date
        case "every4h":  return cal.date(byAdding: .hour, value: 4, to: date) ?? date
        case "every8h":  return cal.date(byAdding: .hour, value: 8, to: date) ?? date
        case "every12h": return cal.date(byAdding: .hour, value: 12, to: date) ?? date
        case "daily":    return cal.date(byAdding: .day, value: 1, to: date) ?? date
        case "weekly":   return cal.date(byAdding: .day, value: 7, to: date) ?? date
        case "monthly":  return cal.date(byAdding: .month, value: 1, to: date) ?? date
        case "yearly":   return cal.date(byAdding: .year, value: 1, to: date) ?? date
        case "weekdays":
            // Mon–Fri: next weekday strictly after date.
            let wds: Set<Int> = [2, 3, 4, 5, 6]
            for add in 1...7 {
                if let cand = cal.date(byAdding: .day, value: add, to: date),
                   wds.contains(cal.component(.weekday, from: cand)) {
                    return cand
                }
            }
            return cal.date(byAdding: .day, value: 1, to: date) ?? date
        default:         return date
        }
    }

    static func award<S: Sequence>(_ t: TaskItem, in members: S) where S.Element == FamilyMember {
        guard let name = t.assignee, !name.isEmpty, t.points > 0 else { return }
        guard let member = match(name: name, in: members) else { return }
        // Expired chores still get checked off but don't pay points.
        // The completion + completionCount + completedAt update upstream
        // still runs so What's New / streaks reflect the action.
        guard !isExpired(t) else {
            if let ctx = member.managedObjectContext {
                FamilyProgress.recordCompletion(member: member, context: ctx)
            }
            return
        }
        member.points += t.points
        member.lifetimePoints += t.points
        if let ctx = member.managedObjectContext {
            FamilyProgress.recordCompletion(member: member, context: ctx)
        }
    }

    static func revoke<S: Sequence>(_ t: TaskItem, in members: S) where S.Element == FamilyMember {
        guard let name = t.assignee, !name.isEmpty, t.points > 0 else { return }
        guard let member = match(name: name, in: members) else { return }
        // Mirror award: don't claw back points we never granted.
        guard !isExpired(t) else { return }
        member.points = max(0, member.points - t.points)
    }

    /// True if `t` is past the household's expiration window. Recurring
    /// tasks never expire (each occurrence resets the clock via
    /// `nextOccurrence`). Configurable household-wide via
    /// `GameRulesStore.shared.rules.expirationWindowDays`. Set to 0 to
    /// disable.
    static func isExpired(_ t: TaskItem) -> Bool {
        let window = GameRulesStore.shared.rules.expirationWindowDays
        guard window > 0 else { return false }
        guard t.effectiveRepeatKind.isEmpty else { return false }
        let anchor = t.dueDate ?? t.createdAt
        guard let expiry = Calendar.current.date(byAdding: .day, value: window, to: anchor) else {
            return false
        }
        return Date() > expiry
    }

    /// Points this task will award if completed right now. Returns 0 for
    /// expired chores so the UI can show a struck-through value.
    static func effectivePoints(_ t: TaskItem) -> Int {
        isExpired(t) ? 0 : Int(t.points)
    }

    static func match<S: Sequence>(name: String, in members: S) -> FamilyMember? where S.Element == FamilyMember {
        let trimmed = name.trimmingCharacters(in: .whitespaces).lowercased()
        return members.first { $0.name.lowercased() == trimmed }
    }
}
