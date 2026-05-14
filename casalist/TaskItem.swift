import Foundation
import SwiftData

@Model
final class TaskItem {
    var task: String = ""
    var assignee: String? = nil
    var dueDate: Date? = nil
    var category: String = ""
    var isCompleted: Bool = false
    var points: Int = 0
    var createdAt: Date = Date()
    var createdBy: String = ""
    /// Legacy field, retained for older records.
    var repeatHours: Int = 0
    /// Repeat kind: "" = once, "hourly", "every2h", "every4h", "every8h",
    /// "every12h", "daily", "weekly", "monthly", "yearly".
    /// When a calendar kind is set, `dueDate` provides the anchor time.
    var repeatKind: String = ""
    /// Cumulative tap-to-complete count for recurring reminders.
    /// Drives the stack-of-completions UI for hourly reminders.
    var completionCount: Int = 0

    init(
        task: String,
        assignee: String? = nil,
        dueDate: Date? = nil,
        category: String = "",
        isCompleted: Bool = false,
        points: Int = 0,
        createdBy: String = "",
        repeatHours: Int = 0,
        repeatKind: String = "",
        completionCount: Int = 0
    ) {
        self.task = task
        self.assignee = assignee
        self.dueDate = dueDate
        self.category = category
        self.isCompleted = isCompleted
        self.points = points
        self.createdAt = Date()
        self.createdBy = createdBy
        self.repeatHours = repeatHours
        self.repeatKind = repeatKind
        self.completionCount = completionCount
    }

    /// Returns the effective repeat kind, falling back to the legacy hours field.
    var effectiveRepeatKind: String {
        if !repeatKind.isEmpty { return repeatKind }
        switch repeatHours {
        case 1: return "hourly"
        case 2: return "every2h"
        case 4: return "every4h"
        case 8: return "every8h"
        case 12: return "every12h"
        case 24: return "daily"
        case 168: return "weekly"
        default: return ""
        }
    }
}
