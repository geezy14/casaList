import Foundation
import CoreData

@objc(Household)
public final class Household: NSManagedObject {
    @NSManaged public var uid: UUID
    @NSManaged public var name: String
    @NSManaged public var createdAt: Date
    @NSManaged public var deletedAt: Date?
    @NSManaged public var members: NSSet?

    var isLive: Bool { deletedAt == nil }
    @NSManaged public var tasks: NSSet?
    @NSManaged public var goals: NSSet?
    @NSManaged public var chores: NSSet?
    @NSManaged public var events: NSSet?
    @NSManaged public var routinesJSON: String

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "uid")
        setPrimitiveValue(Date(), forKey: "createdAt")
        setPrimitiveValue("My Household", forKey: "name")
    }

    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<Household> {
        NSFetchRequest<Household>(entityName: "Household")
    }
}
