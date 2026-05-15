import Foundation
import CoreData

@objc(FamilyGoal)
public final class FamilyGoal: NSManagedObject {
    @NSManaged public var uid: UUID
    @NSManaged public var ownerName: String
    @NSManaged public var label: String
    @NSManaged public var targetPoints: Int64
    @NSManaged public var createdAt: Date
    @NSManaged public var isRedeemed: Bool
    @NSManaged public var redeemedAt: Date?
    @NSManaged public var deletedAt: Date?
    @NSManaged public var note: String
    @NSManaged public var household: Household?

    var isLive: Bool { deletedAt == nil }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "uid")
        setPrimitiveValue(Date(), forKey: "createdAt")
        setPrimitiveValue(Int64(100), forKey: "targetPoints")
    }

    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<FamilyGoal> {
        NSFetchRequest<FamilyGoal>(entityName: "FamilyGoal")
    }

    @discardableResult
    convenience init(
        context: NSManagedObjectContext,
        ownerName: String = "",
        label: String = "",
        targetPoints: Int = 100
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "FamilyGoal", in: context)!
        self.init(entity: entity, insertInto: context)
        self.ownerName = ownerName
        self.label = label
        self.targetPoints = Int64(targetPoints)
    }
}
