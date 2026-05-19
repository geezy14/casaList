import Foundation
import CoreData

@objc(ChoreTemplate)
public final class ChoreTemplate: NSManagedObject {
    @NSManaged public var uid: UUID
    @NSManaged public var label: String
    @NSManaged public var points: Int64
    @NSManaged public var symbol: String
    @NSManaged public var createdAt: Date
    @NSManaged public var household: Household?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "uid")
        setPrimitiveValue(Date(), forKey: "createdAt")
        setPrimitiveValue(Int64(10), forKey: "points")
        setPrimitiveValue("checkmark.circle", forKey: "symbol")
    }

    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<ChoreTemplate> {
        NSFetchRequest<ChoreTemplate>(entityName: "ChoreTemplate")
    }

    @discardableResult
    convenience init(
        context: NSManagedObjectContext,
        label: String = "",
        points: Int = 10,
        symbol: String = "checkmark.circle"
    ) {
        let entity = CasaEntity.resolve("ChoreTemplate", in: context)
        self.init(entity: entity, insertInto: context)
        self.label = label
        self.points = Int64(points)
        self.symbol = symbol
    }
}
