import SwiftUI

/// A "level" derived from a member's current point total. Levels visually
/// upgrade a member's avatar with a colored ring + emblem so growth is
/// felt everywhere their face appears.
enum AvatarLevel: Int, CaseIterable {
    case rookie = 0    // 0–49 pts: no ring
    case bronze = 1    // 50–149 pts
    case silver = 2    // 150–299 pts
    case gold = 3      // 300–499 pts
    case platinum = 4  // 500+ pts

    init(points: Int) {
        switch points {
        case 0..<10:    self = .rookie
        case 10..<75:   self = .bronze
        case 75..<200:  self = .silver
        case 200..<400: self = .gold
        default:        self = .platinum
        }
    }

    var ringColor: Color {
        switch self {
        case .rookie:   return .clear
        case .bronze:   return Color(rgb: 0xC2823A)
        case .silver:   return Color(rgb: 0xB0B0B8)
        case .gold:     return Color(rgb: 0xE8B040)
        case .platinum: return Color(rgb: 0x9B7BD8)
        }
    }

    /// Secondary color for a gradient (platinum gets a multi-stop ring).
    var ringHighlight: Color {
        switch self {
        case .platinum: return Color(rgb: 0x6FA8D0)
        default:        return ringColor
        }
    }

    var emblem: String? {
        switch self {
        case .rookie:   return nil
        case .bronze:   return "🥉"
        case .silver:   return "🥈"
        case .gold:     return "🥇"
        case .platinum: return "👑"
        }
    }

    var label: String {
        switch self {
        case .rookie:   return "Rookie"
        case .bronze:   return "Bronze"
        case .silver:   return "Silver"
        case .gold:     return "Gold"
        case .platinum: return "Platinum"
        }
    }

    /// Lower bound of the *next* tier; nil if at top.
    var nextThreshold: Int? {
        switch self {
        case .rookie:   return 50
        case .bronze:   return 150
        case .silver:   return 300
        case .gold:     return 500
        case .platinum: return nil
        }
    }
}

/// A drop-in replacement for CLAvatar that adds a level ring + emblem
/// derived from the member's current points. Identical sizing/center.
struct LeveledAvatar: View {
    let member: FamilyMember
    let size: CGFloat

    private var level: AvatarLevel { AvatarLevel(points: Int(member.points)) }

    var body: some View {
        // Tier rings + emblems disabled for the initial ship. Keeping the
        // wrapper so callsites don't churn — un-comment the DEBUG branch when
        // the feature is ready.
    }
}
