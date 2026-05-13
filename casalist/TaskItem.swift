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

    init(
        task: String,
        assignee: String? = nil,
        dueDate: Date? = nil,
        category: String = "",
        isCompleted: Bool = false,
        points: Int = 0,
        createdBy: String = ""
    ) {
        self.task = task
        self.assignee = assignee
        self.dueDate = dueDate
        self.category = category
        self.isCompleted = isCompleted
        self.points = points
        self.createdAt = Date()
        self.createdBy = createdBy
    }
}
