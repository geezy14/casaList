import Foundation
import SwiftData

/// A points-savings goal owned by a single family member.
@Model
final class FamilyGoal {
    var ownerName: String = ""
    var label: String = ""
    var targetPoints: Int = 100
    var createdAt: Date = Date()
    var uid: UUID = UUID()

    init(ownerName: String = "", label: String = "", targetPoints: Int = 100) {
        self.ownerName = ownerName
        self.label = label
        self.targetPoints = targetPoints
        self.createdAt = Date()
        self.uid = UUID()
    }
}
