import SwiftUI

/// Level thresholds keyed on LIFETIME points earned (never decremented on
/// redemption). Index = level number (1-based, so index 0 = lvl 1 starts at 0).
/// Aligned with the app's point economy:
///   quick task = 5 pts, normal = 10 pts, hard = 15 pts
///   small reward ≈ 150-300 pts, medium ≈ 500-800 pts, large ≈ 1000-2000 pts
private let levelThresholds: [Int] = [
    0,     // Lvl 1 — Rookie
    100,   // Lvl 2 — Learner
    250,   // Lvl 3 — Helper
    450,   // Lvl 4 — Doer
    700,   // Lvl 5 — Go-Getter
    1000,  // Lvl 6 — Achiever
    1350,  // Lvl 7 — Pro
    1750,  // Lvl 8 — Expert
    2200,  // Lvl 9 — Master
    2700,  // Lvl 10 — Legend
]

private let levelLabels: [String] = [
    "Rookie", "Broom Pilot", "Mop Jockey", "Chore Warrior", "Task Slayer",
    "Achiever", "Pro", "Expert", "Master", "Legend",
]

/// Returns the 1-based level number (1–10) for the given lifetime points.
func levelNumber(for lifetimePoints: Int) -> Int {
    var level = 1
    for (i, threshold) in levelThresholds.enumerated() {
        if lifetimePoints >= threshold { level = i + 1 }
    }
    return level
}

/// XP progress (0.0–1.0) toward the next level.
func xpProgress(for lifetimePoints: Int) -> CGFloat {
    let lvl = levelNumber(for: lifetimePoints)
    let current = levelThresholds[lvl - 1]
    let next = lvl < levelThresholds.count ? levelThresholds[lvl] : current + 1000
    guard next > current else { return 1.0 }
    return CGFloat(lifetimePoints - current) / CGFloat(next - current)
}

/// Points needed to reach the next level threshold (or nil at max level).
func nextLevelThreshold(for lifetimePoints: Int) -> Int? {
    let lvl = levelNumber(for: lifetimePoints)
    guard lvl < levelThresholds.count else { return nil }
    return levelThresholds[lvl]
}

func levelLabel(for lifetimePoints: Int) -> String {
    let idx = min(levelNumber(for: lifetimePoints) - 1, levelLabels.count - 1)
    return levelLabels[max(0, idx)]
}

/// Visual tier based on level bracket — drives ring color/emblem.
/// Three tiers across the 10 levels, with non-medal icons so they never
/// read as leaderboard placement (🥇🥈🥉 stay reserved for actual rank).
///   Sprout 🌱  Lvl 1-3   ·   Blaze 🔥  Lvl 4-7   ·   Gem 💎  Lvl 8-10
enum AvatarLevel: Int, CaseIterable {
    case sprout = 0   // Lvl 1-3
    case blaze = 1    // Lvl 4-7
    case gem = 2      // Lvl 8-10

    init(lifetimePoints: Int) {
        self = AvatarLevel(level: levelNumber(for: lifetimePoints))
    }

    /// Map a 1-based level number (1-10) to its tier.
    init(level lvl: Int) {
        switch lvl {
        case 1...3: self = .sprout
        case 4...7: self = .blaze
        default:    self = .gem
        }
    }

    var ringColor: Color {
        switch self {
        case .sprout: return Color(rgb: 0x5BBF77)   // green
        case .blaze:  return Color(rgb: 0xE8733A)   // fire orange
        case .gem:    return Color(rgb: 0x49C7E0)   // diamond cyan
        }
    }

    var ringHighlight: Color {
        switch self {
        case .sprout: return Color(rgb: 0x8FE0A0)
        case .blaze:  return Color(rgb: 0xF5A85A)
        case .gem:    return Color(rgb: 0x8FE6F2)
        }
    }

    var emblem: String? {
        switch self {
        case .sprout: return "🌱"
        case .blaze:  return "🔥"
        case .gem:    return "💎"
        }
    }

    var label: String {
        switch self {
        case .sprout: return "Sprout"
        case .blaze:  return "Blaze"
        case .gem:    return "Gem"
        }
    }
}

/// Drop-in replacement for CLAvatar with a level ring + emblem derived from
/// the member's lifetime points.
struct LeveledAvatar: View {
    let member: FamilyMember
    let size: CGFloat
    /// Whether to show the small medal emblem in the corner.
    var showEmblem: Bool = true
    /// Pass an explicit level number (1-10) from the caller to guarantee the
    /// ring always matches the displayed level. Falls back to computing from
    /// member data when nil.
    var overrideLevel: Int? = nil

    /// Effective lifetime pts — use whichever is higher so pre-migration members
    /// (lifetimePoints == 0) still get the right ring from their current balance.
    private var effectiveLifetime: Int {
        let lp = Int(member.lifetimePoints)
        let p  = Int(member.points)
        return lp > p ? lp : p
    }
    private var level: AvatarLevel {
        AvatarLevel(level: overrideLevel ?? levelNumber(for: effectiveLifetime))
    }

    var body: some View {
        let ringWidth: CGFloat = max(2, size * 0.07)
        let emblemSize: CGFloat = max(10, size * 0.32)
        ZStack {
            CLAvatar(member.asCLMember, size: size)
            // Every member now has a tier (Sprout from Lvl 1), so the ring
            // and emblem always show.
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [level.ringColor, level.ringHighlight, level.ringColor],
                        center: .center
                    ),
                    lineWidth: ringWidth
                )
                .frame(width: size + ringWidth, height: size + ringWidth)
            if showEmblem, let e = level.emblem {
                Text(e)
                    .font(.system(size: emblemSize))
                    .padding(2)
                    .background(Circle().fill(Color.white))
                    .overlay(Circle().stroke(level.ringColor, lineWidth: 1))
                    .offset(x: size * 0.32, y: -size * 0.32)
            }
        }
        .frame(width: size + ringWidth, height: size + ringWidth)
    }
}
