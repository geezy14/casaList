import Foundation
import SwiftUI
import CoreData

enum FamilyPermissions {
    static func currentMember<S: Sequence>(members: S, userName: String, meUid: String) -> FamilyMember?
    where S.Element == FamilyMember {
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

    static func ensureOwner<S: Sequence>(members: S, context: NSManagedObjectContext)
    where S.Element == FamilyMember {
        let array = Array(members)
        guard array.contains(where: { $0.level == .owner }) == false,
              let first = array.sorted(by: { $0.createdAt < $1.createdAt }).first else { return }
        first.roleLevel = FamilyRole.owner.rawValue
        try? context.save()
    }

    static func adminCount<S: Sequence>(in members: S) -> Int
    where S.Element == FamilyMember {
        members.filter { $0.level == .admin }.count
    }
}
