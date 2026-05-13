import Foundation
import SwiftData

@Model
final class Household {
    var name: String = "My Household"
    var createdAt: Date = Date()
    var uid: UUID = UUID()

    init(name: String = "My Household") {
        self.name = name
        self.createdAt = Date()
        self.uid = UUID()
    }
}
