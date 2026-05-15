import Foundation
import CoreData

/// A whole-family team goal is just a FamilyGoal whose ownerName matches the
/// sentinel below. Progress is the sum of all members' current points;
/// redemption is a milestone (no point deduction). This keeps the data model
/// unchanged — no new entity, no schema deploy.
enum TeamGoal {
    static let sentinel = "_family"
    static let displayName = "Whole family"

    static func isTeam(_ g: FamilyGoal) -> Bool {
        g.ownerName == sentinel
    }

    /// Sum of points across all family members in the same household as `g`.
    /// If the goal has no household (orphan), sums across the provided list.
    static func progress<S: Sequence>(for g: FamilyGoal, members: S) -> Int64 where S.Element == FamilyMember {
        if let household = g.household, let set = household.members as? Set<FamilyMember> {
            return set.reduce(0) { $0 + $1.points }
        }
        return members.reduce(0) { $0 + $1.points }
    }
}
