import Foundation
import SwiftData

/// A scheduled family event — appointments, birthdays, school stuff, etc.
@Model
final class FamilyEvent {
    var title: String = ""
    var startDate: Date = Date()
    var isAllDay: Bool = false
    var location: String = ""
    var attendees: String = ""
    var notes: String = ""
    var repeatKind: String = ""
    var createdAt: Date = Date()
    var createdBy: String = ""
    var uid: UUID = UUID()

    init(
        title: String = "",
        startDate: Date = Date(),
        isAllDay: Bool = false,
        location: String = "",
        attendees: String = "",
        notes: String = "",
        repeatKind: String = "",
        createdBy: String = ""
    ) {
        self.title = title
        self.startDate = startDate
        self.isAllDay = isAllDay
        self.location = location
        self.attendees = attendees
        self.notes = notes
        self.repeatKind = repeatKind
        self.createdAt = Date()
        self.createdBy = createdBy
        self.uid = UUID()
    }
}
