import Foundation
import SwiftData

@Model
final class TaskItem {
    // 📋 These properties match your Notion columns exactly
    var task: String        // Notion: "Task"
    var assignee: String?   // Notion: "Assignee"
    var dueDate: Date?      // Notion: "Due Date"
    var category: String    // Notion: "Multi-select"
    var isCompleted: Bool   // Notion: "Checkbox"
    var points: Int         // Notion: "points" (Formula)

    init(
        task: String,
        assignee: String? = nil,
        dueDate: Date? = nil,
        category: String = "",
        isCompleted: Bool = false,
        points: Int = 0
    ) {
        self.task = task
        self.assignee = assignee
        self.dueDate = dueDate
        self.category = category
        self.isCompleted = isCompleted
        self.points = points
    }
}
