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
    /// All-time points ever earned — never decremented on redemption.
    /// Drives the level system so levels never regress.
    @NSManaged public var lifetimePoints: Int64
    @NSManaged public var createdAt: Date
    @NSManaged public var roleLevel: String
    @NSManaged public var photoBlob: Data?
    @NSManaged public var deletedAt: Date?
    /// CloudKit user record ID (stable across reinstall/device-change). Nil
    /// or empty when not yet stamped. Always read via `userID` which
    /// flattens nil → "" for predicate / comparison safety.
    @NSManaged public var cloudKitUserID: String?
    /// Last-known GPS coordinates if the user opted into location share.
    /// 0.0/0.0 when not sharing — check `locationUpdatedAt != nil` to
    /// differentiate "off" from "at the equator off Africa."
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var locationUpdatedAt: Date?
    @NSManaged public var isSharingLocation: Bool
    @NSManaged public var household: Household?

    /// Non-optional read accessor. Use everywhere we need to compare or
    /// pass the ID — keeps callers from each having to do their own
    /// nil-coalesce. Writers can assign directly to `cloudKitUserID`.
    var userID: String { cloudKitUserID ?? "" }

    /// True if the record is a live (not soft-deleted) member.
    var isLive: Bool { deletedAt == nil }

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
    var isKid: Bool { level == .kid }
    var canManageFamily: Bool { level == .owner || level == .admin }
    var canCreateTasksForOthers: Bool { level == .owner || level == .admin }
    var canEditOthersTasks: Bool { level == .owner || level == .admin }
    var canManageChoresAndGoals: Bool { level == .owner || level == .admin }
    var canAwardPoints: Bool { level == .owner || level == .admin }
    var canCreateEvents: Bool { level != .kid }
    var canDeleteOwnTasks: Bool { level != .kid }

    var asCLMember: CLFamilyMember {
        CLFamilyMember(id: uid.uuidString, label: name, role: role, color: color, points: Int(points), photoBlob: photoBlob)
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
        photoBlob: Data? = nil,
        roleLevel: FamilyRole = .standard
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "FamilyMember", in: context)!
        self.init(entity: entity, insertInto: context)
        self.name = name
        self.role = role
        self.colorHex = Int64(colorHex)
        self.points = Int64(points)
        self.photoBlob = photoBlob
        self.roleLevel = roleLevel.rawValue
    }
}

enum FamilyRole: String, CaseIterable {
    case owner, admin, standard, kid

    var label: String {
        switch self {
        case .owner: return "Owner"
        case .admin: return "Admin"
        case .standard: return "Standard"
        case .kid: return "Kid"
        }
    }

    var symbol: String {
        switch self {
        case .owner: return "crown.fill"
        case .admin: return "star.fill"
        case .standard: return "person.fill"
        case .kid: return "figure.child"
        }
    }

    /// Roles that an owner/admin can assign to another member.
    static var assignable: [FamilyRole] { [.admin, .standard, .kid] }
}
