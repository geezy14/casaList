import Foundation
import CoreData

/// Per-member streak + badge tracking. State lives in UserDefaults on each
/// device — no CloudKit entity (avoids schema redeploys). Streaks are
/// recorded forward from when this code first ships; we can't backfill from
/// existing TaskItems because they don't carry a completion timestamp.
///
/// Single-device limitation: if the same person uses two devices, their
/// streak/badges may diverge. Acceptable for v1 since each family member
/// typically has one primary phone.

// MARK: – Streak

struct StreakState: Codable, Equatable {
    var current: Int = 0
    var best: Int = 0
    var lastCompletionDay: Date? = nil
}

enum StreakTracker {
    private static func key(_ memberUid: UUID) -> String { "streak_\(memberUid.uuidString)" }

    static func load(for memberUid: UUID) -> StreakState {
        guard let data = UserDefaults.standard.data(forKey: key(memberUid)) else { return StreakState() }
        return (try? JSONDecoder().decode(StreakState.self, from: data)) ?? StreakState()
    }

    static func save(_ s: StreakState, for memberUid: UUID) {
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: key(memberUid))
        }
    }

    /// Called when a member completes a chore. Bumps streak if the previous
    /// completion was yesterday; resets to 1 if there's a gap; no-op if
    /// already counted today.
    static func recordCompletion(for memberUid: UUID, on day: Date = Date()) {
        var s = load(for: memberUid)
        let cal = Calendar.current
        let today = cal.startOfDay(for: day)
        if let last = s.lastCompletionDay, cal.isDate(last, inSameDayAs: today) {
            return // already counted today
        }
        if let last = s.lastCompletionDay,
           let diff = cal.dateComponents([.day], from: last, to: today).day,
           diff == 1 {
            s.current += 1
        } else {
            s.current = 1
        }
        s.best = max(s.best, s.current)
        s.lastCompletionDay = today
        save(s, for: memberUid)
    }

    /// Live current streak — returns the stored value only if the last
    /// completion was today or yesterday. Otherwise the streak has lapsed
    /// (display as 0) but we don't write zero — the stored "current" is
    /// preserved until the next completion resets it.
    static func effectiveCurrent(for memberUid: UUID) -> Int {
        let s = load(for: memberUid)
        guard let last = s.lastCompletionDay else { return 0 }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let days = cal.dateComponents([.day], from: last, to: today).day ?? 0
        return days <= 1 ? s.current : 0
    }
}

// MARK: – Badges

enum Badge: String, CaseIterable, Codable {
    case firstChore       // complete your first chore
    case tenChores        // 10 chores
    case fiftyChores      // 50 chores
    case hundredPoints    // earn 100 cumulative points
    case fiveHundredPoints // 500 points
    case threeDayStreak   // 3-day streak
    case sevenDayStreak   // 7-day streak
    case fourteenDayStreak // 14-day streak
    case firstRedeem      // first goal redeemed

    var label: String {
        switch self {
        case .firstChore: return "First chore"
        case .tenChores: return "Ten down"
        case .fiftyChores: return "Half-century"
        case .hundredPoints: return "100 club"
        case .fiveHundredPoints: return "500 club"
        case .threeDayStreak: return "3-day streak"
        case .sevenDayStreak: return "Week strong"
        case .fourteenDayStreak: return "Two-week wonder"
        case .firstRedeem: return "First reward"
        }
    }

    var emoji: String {
        switch self {
        case .firstChore: return "🎯"
        case .tenChores: return "🔟"
        case .fiftyChores: return "🥇"
        case .hundredPoints: return "💯"
        case .fiveHundredPoints: return "🚀"
        case .threeDayStreak: return "🔥"
        case .sevenDayStreak: return "📅"
        case .fourteenDayStreak: return "🏆"
        case .firstRedeem: return "🎁"
        }
    }
}

enum AwardedBadgeStore {
    private static func key(_ memberUid: UUID) -> String { "badges_\(memberUid.uuidString)" }

    static func awarded(for memberUid: UUID) -> Set<Badge> {
        guard let arr = UserDefaults.standard.stringArray(forKey: key(memberUid)) else { return [] }
        return Set(arr.compactMap { Badge(rawValue: $0) })
    }

    static func setAwarded(_ s: Set<Badge>, for memberUid: UUID) {
        let arr = s.map { $0.rawValue }
        UserDefaults.standard.set(arr, forKey: key(memberUid))
    }

    /// Re-evaluate which badges should be unlocked given current stats. Saves
    /// the resulting set and returns any newly-awarded ones (for celebration).
    @discardableResult
    static func recheck(
        memberUid: UUID,
        totalPoints: Int,
        completedCount: Int,
        redeemedCount: Int
    ) -> Set<Badge> {
        var computed: Set<Badge> = []
        if completedCount >= 1 { computed.insert(.firstChore) }
        if completedCount >= 10 { computed.insert(.tenChores) }
        if completedCount >= 50 { computed.insert(.fiftyChores) }
        if totalPoints >= 100 { computed.insert(.hundredPoints) }
        if totalPoints >= 500 { computed.insert(.fiveHundredPoints) }
        let best = StreakTracker.load(for: memberUid).best
        if best >= 3 { computed.insert(.threeDayStreak) }
        if best >= 7 { computed.insert(.sevenDayStreak) }
        if best >= 14 { computed.insert(.fourteenDayStreak) }
        if redeemedCount >= 1 { computed.insert(.firstRedeem) }
        let previous = awarded(for: memberUid)
        setAwarded(computed, for: memberUid)
        return computed.subtracting(previous)
    }
}

// MARK: – Convenience: count helpers for the recheck call

enum FamilyProgress {
    /// Called by FamilyPoints.award when a member completes a point-bearing
    /// task. Records the streak and re-checks badges.
    static func recordCompletion(member: FamilyMember, context: NSManagedObjectContext) {
        StreakTracker.recordCompletion(for: member.uid)
        let completedCount = countCompleted(for: member, in: context)
        let redeemedCount = countRedeemed(for: member, in: context)
        _ = AwardedBadgeStore.recheck(
            memberUid: member.uid,
            totalPoints: Int(member.points),
            completedCount: completedCount,
            redeemedCount: redeemedCount
        )
    }

    static func countCompleted(for member: FamilyMember, in context: NSManagedObjectContext) -> Int {
        let req: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        req.predicate = NSPredicate(format: "isCompleted == YES AND assignee ==[c] %@", member.name)
        return (try? context.count(for: req)) ?? 0
    }

    static func countRedeemed(for member: FamilyMember, in context: NSManagedObjectContext) -> Int {
        let req: NSFetchRequest<FamilyGoal> = FamilyGoal.fetchRequest()
        req.predicate = NSPredicate(format: "isRedeemed == YES AND ownerName ==[c] %@", member.name)
        return (try? context.count(for: req)) ?? 0
    }
}
