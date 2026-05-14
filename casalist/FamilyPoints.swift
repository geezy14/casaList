import Foundation

/// Helpers for awarding/revoking task points and progressing recurring tasks
/// when their circle is tapped.
enum FamilyPoints {
    /// Called when the user taps the check circle on any task row.
    /// For one-shot tasks: flips `isCompleted` and awards/revokes points.
    /// For recurring tasks: awards points, bumps `dueDate` to the next
    /// occurrence, increments `completionCount`, keeps `isCompleted = false`.
    static func toggle(_ t: TaskItem, in members: [FamilyMember]) {
        let isRecurring = !t.effectiveRepeatKind.isEmpty
        if isRecurring {
            advanceRecurring(t, in: members)
        } else {
            t.isCompleted.toggle()
            if t.isCompleted {
                award(t, in: members)
            } else {
                revoke(t, in: members)
            }
        }
    }

    private static func advanceRecurring(_ t: TaskItem, in members: [FamilyMember]) {
        award(t, in: members)
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

    static func award(_ t: TaskItem, in members: [FamilyMember]) {
        guard let name = t.assignee, !name.isEmpty, t.points > 0 else { return }
        guard let member = match(name: name, in: members) else { return }
        member.points += t.points
    }

    static func revoke(_ t: TaskItem, in members: [FamilyMember]) {
        guard let name = t.assignee, !name.isEmpty, t.points > 0 else { return }
        guard let member = match(name: name, in: members) else { return }
        member.points = max(0, member.points - t.points)
    }

    static func match(name: String, in members: [FamilyMember]) -> FamilyMember? {
        let trimmed = name.trimmingCharacters(in: .whitespaces).lowercased()
        return members.first { $0.name.lowercased() == trimmed }
    }
}
