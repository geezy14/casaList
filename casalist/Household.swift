import Foundation
import CoreData

@objc(Household)
public final class Household: NSManagedObject {
    @NSManaged public var uid: UUID
    @NSManaged public var name: String
    @NSManaged public var createdAt: Date
    @NSManaged public var members: NSSet?
    @NSManaged public var tasks: NSSet?
    @NSManaged public var goals: NSSet?
    @NSManaged public var chores: NSSet?
    @NSManaged public var events: NSSet?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        let zero = UUID(uuidString: "00000000-0000-0000-0000-000000000000")
        setPrimitiveValue(uid == zero ? UUID() : uid, forKey: "uid")
        setPrimitiveValue(Date(), forKey: "createdAt")
        setPrimitiveValue("My Household", forKey: "name")
    }

    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<Household> {
        NSFetchRequest<Household>(entityName: "Household")
    }
}
