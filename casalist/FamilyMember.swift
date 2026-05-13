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
    @Attribute(.externalStorage) var photoData: Data? = nil

    init(name: String, role: String = "", colorHex: Int = 0xC97357, points: Int = 0, photoData: Data? = nil) {
        self.name = name
        self.role = role
        self.colorHex = colorHex
        self.points = points
        self.createdAt = Date()
        self.uid = UUID()
        self.photoData = photoData
    }

    var color: Color { Color(rgb: UInt32(colorHex)) }

    var asCLMember: CLFamilyMember {
        CLFamilyMember(id: uid.uuidString, label: name, role: role, color: color, points: points, photoData: photoData)
    }
}
