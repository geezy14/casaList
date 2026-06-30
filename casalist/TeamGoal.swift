import Foundation
import CoreData

/// A whole-family team goal is just a FamilyGoal whose ownerName matches the
/// sentinel below. Progress is the sum of all members' current points;
/// redemption is a milestone (no point deduction). This keeps the data model
/// unchanged — no new entity, no schema deploy.
enum TeamGoal {
    static let sentinel = "_family"
    static let displayName = "Whole family"

    /// "Everyone" goals are the cooperation variant: instead of summing the
    /// family's points (the `_family` kind), the goal unlocks only when
    /// EVERY active member individually reaches `targetPoints`. Same
    /// sentinel-in-ownerName trick — no new entity, no schema deploy.
    static let everyoneSentinel = "_everyone"
    static let everyoneDisplayName = "Everyone pitches in"

    static func isTeam(_ g: FamilyGoal) -> Bool {
        g.ownerName == sentinel
    }

    static func isEveryone(_ g: FamilyGoal) -> Bool {
        g.ownerName == everyoneSentinel
    }

    /// Either group kind — sum-based or everyone-based.
    static func isGroup(_ g: FamilyGoal) -> Bool {
        isTeam(g) || isEveryone(g)
    }

    /// Sum of points across all family members in the same household as `g`.
    /// If the goal has no household (orphan), sums across the provided list.
    static func progress<S: Sequence>(for g: FamilyGoal, members: S) -> Int64 where S.Element == FamilyMember {
        if let household = g.household, let set = household.members as? Set<FamilyMember> {
            return set.reduce(0) { $0 + $1.points }
        }
        return members.reduce(0) { $0 + $1.points }
    }

    /// Members in scope for an "everyone" goal — the goal's household if
    /// linked, else the provided fallback list.
    static func scopedMembers<S: Sequence>(for g: FamilyGoal, fallback: S) -> [FamilyMember] where S.Element == FamilyMember {
        if let household = g.household, let set = household.members as? Set<FamilyMember>, !set.isEmpty {
            return set.filter { $0.deletedAt == nil }
        }
        return fallback.filter { $0.deletedAt == nil }
    }

    /// For "everyone" goals: (membersWhoHitTheTarget, totalMembers).
    /// targetPoints is the PER-MEMBER bar, not a household sum.
    static func everyoneProgress<S: Sequence>(for g: FamilyGoal, members: S) -> (hit: Int, total: Int) where S.Element == FamilyMember {
        let scoped = scopedMembers(for: g, fallback: members)
        let hit = scoped.filter { $0.points >= g.targetPoints }.count
        return (hit, scoped.count)
    }

    /// Unlocked = every member is at/over the per-member bar.
    static func everyoneUnlocked<S: Sequence>(for g: FamilyGoal, members: S) -> Bool where S.Element == FamilyMember {
        let (hit, total) = everyoneProgress(for: g, members: members)
        return total > 0 && hit == total
    }
}
