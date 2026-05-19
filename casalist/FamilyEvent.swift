import Foundation
import CoreData

@objc(FamilyEvent)
public final class FamilyEvent: NSManagedObject {
    @NSManaged public var uid: UUID
    @NSManaged public var title: String
    @NSManaged public var startDate: Date
    @NSManaged public var isAllDay: Bool
    @NSManaged public var location: String
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var attendees: String
    @NSManaged public var notes: String

    /// Convenience — has a real picked location (not just typed text).
    var hasCoordinates: Bool { latitude != 0 || longitude != 0 }
    @NSManaged public var repeatKind: String
    @NSManaged public var createdAt: Date
    @NSManaged public var createdBy: String
    @NSManaged public var deletedAt: Date?
    /// Optional end time. nil when isAllDay or no end time was set.
    @NSManaged public var endDate: Date?
    /// When true, the notification body uses the household-wide broadcast
    /// prefix (📢) even if `attendees` is set to a single person. Lets
    /// admins say "this is Donovan's soccer practice" on the calendar
    /// while still pinging the whole family.
    @NSManaged public var announceHousehold: Bool
    @NSManaged public var household: Household?

    var isLive: Bool { deletedAt == nil }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "uid")
        setPrimitiveValue(Date(), forKey: "createdAt")
        setPrimitiveValue(Date(), forKey: "startDate")
    }

    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<FamilyEvent> {
        NSFetchRequest<FamilyEvent>(entityName: "FamilyEvent")
    }

    @discardableResult
    convenience init(
        context: NSManagedObjectContext,
        title: String = "",
        startDate: Date = Date(),
        isAllDay: Bool = false,
        location: String = "",
        attendees: String = "",
        notes: String = "",
        repeatKind: String = "",
        createdBy: String = ""
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "FamilyEvent", in: context)!
        self.init(entity: entity, insertInto: context)
        self.title = title
        self.startDate = startDate
        self.isAllDay = isAllDay
        self.location = location
        self.attendees = attendees
        self.notes = notes
        self.repeatKind = repeatKind
        self.createdBy = createdBy
    }
}
