import Foundation
import CoreData
import SwiftUI

@objc(FamilyMember)
public final class FamilyMember: NSManagedObject {
    @NSManaged public var uid: UUID
    @NSManaged public var name: String
    @NSManaged public var role: String
    @NSManaged public var colorHex: Int64
    @NSManaged public var points: Int64
    @NSManaged public var createdAt: Date
    @NSManaged public var roleLevel: String
    @NSManaged public var photoData: Data?
    @NSManaged public var household: Household?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "uid")
        setPrimitiveValue(Date(), forKey: "createdAt")
        setPrimitiveValue(Int64(0xC97357), forKey: "colorHex")
        setPrimitiveValue(FamilyRole.standard.rawValue, forKey: "roleLevel")
    }

    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<FamilyMember> {
        NSFetchRequest<FamilyMember>(entityName: "FamilyMember")
    }

    var color: Color { Color(rgb: UInt32(colorHex)) }

    var level: FamilyRole { FamilyRole(rawValue: roleLevel) ?? .standard }
    var isOwner: Bool { level == .owner }
    var isAdmin: Bool { level == .admin }
    var canManageFamily: Bool { level == .owner || level == .admin }

    var asCLMember: CLFamilyMember {
        CLFamilyMember(id: uid.uuidString, label: name, role: role, color: color, points: Int(points), photoData: photoData)
    }

    /// Convenience initializer that inserts into the given context and applies
    /// the same defaults the SwiftData version had.
    @discardableResult
    convenience init(
        context: NSManagedObjectContext,
        name: String,
        role: String = "",
        colorHex: Int = 0xC97357,
        points: Int = 0,
        photoData: Data? = nil,
        roleLevel: FamilyRole = .standard
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "FamilyMember", in: context)!
        self.init(entity: entity, insertInto: context)
        self.name = name
        self.role = role
        self.colorHex = Int64(colorHex)
        self.points = Int64(points)
        self.photoData = photoData
        self.roleLevel = roleLevel.rawValue
    }
}

enum FamilyRole: String, CaseIterable {
    case owner, admin, standard

    var label: String {
        switch self {
        case .owner: return "Owner"
        case .admin: return "Admin"
        case .standard: return "Member"
        }
    }

    var symbol: String {
        switch self {
        case .owner: return "crown.fill"
        case .admin: return "star.fill"
        case .standard: return "person.fill"
        }
    }
}
