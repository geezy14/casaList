import Foundation
import SwiftData

/// A reusable chore that any family member can "claim" — claiming creates a
/// TaskItem for them based on this template.
@Model
final class ChoreTemplate {
    var label: String = ""
    var points: Int = 10
    var symbol: String = "checkmark.circle"
    var createdAt: Date = Date()
    var uid: UUID = UUID()

    init(label: String = "", points: Int = 10, symbol: String = "checkmark.circle") {
        self.label = label
        self.points = points
        self.symbol = symbol
        self.createdAt = Date()
        self.uid = UUID()
    }
}
