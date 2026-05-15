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
    }

    private static func nextOccurrence(after date: Date, kind: String) -> Date {
        let cal = Calendar.current
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
        default:         return date
        }
    }

    static func award<S: Sequence>(_ t: TaskItem, in members: S) where S.Element == FamilyMember {
        guard let name = t.assignee, !name.isEmpty, t.points > 0 else { return }
        guard let member = match(name: name, in: members) else { return }
        member.points += t.points
        if let ctx = member.managedObjectContext {
            FamilyProgress.recordCompletion(member: member, context: ctx)
        }
    }

    static func revoke<S: Sequence>(_ t: TaskItem, in members: S) where S.Element == FamilyMember {
        guard let name = t.assignee, !name.isEmpty, t.points > 0 else { return }
        guard let member = match(name: name, in: members) else { return }
        member.points = max(0, member.points - t.points)
    }

    static func match<S: Sequence>(name: String, in members: S) -> FamilyMember? where S.Element == FamilyMember {
        let trimmed = name.trimmingCharacters(in: .whitespaces).lowercased()
        return members.first { $0.name.lowercased() == trimmed }
    }
}
