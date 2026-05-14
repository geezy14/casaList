import Foundation
import CoreData

@objc(FamilyEvent)
public final class FamilyEvent: NSManagedObject {
    @NSManaged public var uid: UUID
    @NSManaged public var title: String
    @NSManaged public var startDate: Date
    @NSManaged public var isAllDay: Bool
    @NSManaged public var location: String
    @NSManaged public var attendees: String
    @NSManaged public var notes: String
    @NSManaged public var repeatKind: String
    @NSManaged public var createdAt: Date
    @NSManaged public var createdBy: String
    @NSManaged public var household: Household?

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
