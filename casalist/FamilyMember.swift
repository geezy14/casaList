import Foundation
import SwiftData
import SwiftUI

@Model
final class FamilyMember {
    var name: String = ""
    var role: String = ""
    var colorHex: Int = 0xC97357
    var points: Int = 0
    var createdAt: Date = Date()
    var uid: UUID = UUID()
    var roleLevel: String = FamilyRole.standard.rawValue
    @Attribute(.externalStorage) var photoData: Data? = nil

    init(name: String, role: String = "", colorHex: Int = 0xC97357, points: Int = 0, photoData: Data? = nil, roleLevel: FamilyRole = .standard) {
        self.name = name
        self.role = role
        self.colorHex = colorHex
        self.points = points
        self.createdAt = Date()
        self.uid = UUID()
        self.photoData = photoData
        self.roleLevel = roleLevel.rawValue
    }

    var color: Color { Color(rgb: UInt32(colorHex)) }

    var level: FamilyRole { FamilyRole(rawValue: roleLevel) ?? .standard }
    var isOwner: Bool { level == .owner }
    var isAdmin: Bool { level == .admin }
    var canManageFamily: Bool { level == .owner || level == .admin }

    var asCLMember: CLFamilyMember {
        CLFamilyMember(id: uid.uuidString, label: name, role: role, color: color, points: points, photoData: photoData)
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
