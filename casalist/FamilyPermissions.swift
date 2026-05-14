import Foundation
import SwiftUI
import SwiftData

enum FamilyPermissions {
    static func currentMember(members: [FamilyMember], userName: String, meUid: String) -> FamilyMember? {
        if !meUid.isEmpty, let u = UUID(uuidString: meUid),
           let m = members.first(where: { $0.uid == u }) {
            return m
        }
        let trimmed = userName.trimmingCharacters(in: .whitespaces).lowercased()
        if !trimmed.isEmpty,
           let m = members.first(where: { $0.name.lowercased() == trimmed }) {
            return m
        }
        return nil
    }

    static func ensureOwner(members: [FamilyMember], context: ModelContext) {
        guard members.contains(where: { $0.level == .owner }) == false,
              let first = members.sorted(by: { $0.createdAt < $1.createdAt }).first else { return }
        first.roleLevel = FamilyRole.owner.rawValue
        try? context.save()
    }

    static func adminCount(in members: [FamilyMember]) -> Int {
        members.filter { $0.level == .admin }.count
    }
}
