import Foundation
import SwiftUI
import Combine

// MARK: - Model

struct RewardTier: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var name: String        // "Small Reward", "Medium Reward", etc.
    var minPoints: Int      // minimum pts needed to unlock this tier
    var emoji: String
    var description: String // e.g. "A small treat or screen time"
    var dollarValue: Double? // optional dollar equivalent (e.g. $10)
}

struct CategoryPointRule: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var category: String    // "Chores", "Home", "Maintenance", "Family"
    var emoji: String
    var defaultPoints: Int  // suggested default when creating a task in this category
    var description: String // e.g. "Daily household chores"
}

struct GameRules: Codable {
    var rewardTiers: [RewardTier]
    var categoryRules: [CategoryPointRule]
    var pointsPerDollar: Int // global exchange rate: how many points = $1

    static let `default` = GameRules(
        rewardTiers: [
            RewardTier(name: "Small Reward",  minPoints: 150,  emoji: "🎁", description: "A small treat, snack, or privilege",  dollarValue: 10),
            RewardTier(name: "Medium Reward", minPoints: 500,  emoji: "🎀", description: "A bigger outing or activity",          dollarValue: 30),
            RewardTier(name: "Large Reward",  minPoints: 1000, emoji: "🏆", description: "A major experience or gift",           dollarValue: 75),
        ],
        categoryRules: [
            CategoryPointRule(category: "Chores",      emoji: "🧹", defaultPoints: 10, description: "Daily household chores"),
            CategoryPointRule(category: "Home",        emoji: "🏠", defaultPoints: 15, description: "Home upkeep and repairs"),
            CategoryPointRule(category: "Maintenance", emoji: "🔧", defaultPoints: 20, description: "Larger maintenance tasks"),
            CategoryPointRule(category: "Family",      emoji: "👨‍👩‍👧", defaultPoints: 5,  description: "Family activities and errands"),
        ],
        pointsPerDollar: 10
    )
}

// MARK: - Store

final class GameRulesStore: ObservableObject {
    static let shared = GameRulesStore()
    private let key = "gameRules_v1"

    @Published var rules: GameRules {
        didSet { save() }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(GameRules.self, from: data) {
            rules = decoded
        } else {
            rules = .default
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func reset() {
        rules = .default
    }
}
