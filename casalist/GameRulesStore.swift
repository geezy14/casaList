import Foundation
import SwiftUI
import Combine
import CoreData

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
    var isLocked: Bool = false // if true, point value cannot be changed per-task
}

/// A pre-built, redeemable item kids tap to propose a goal at a
/// known point cost. Tapping creates a FamilyGoal that lands in the
/// admin inbox for approval (vs. a free-form goal where the kid
/// types their own label + the admin sets the price).
struct RedeemableItem: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var emoji: String
    var name: String
    var points: Int
    /// Grouping label so the catalog can be organized (e.g. "Screen
    /// time", "Privileges", "Treats", "Outings", "Family"). Free-form.
    var category: String
    /// Optional web link to the item (e.g. an Amazon product page) so an
    /// admin reviewing a request can see exactly what's being asked for.
    /// Empty = no link.
    var url: String = ""

    init(id: String = UUID().uuidString, emoji: String, name: String,
         points: Int, category: String, url: String = "") {
        self.id = id
        self.emoji = emoji
        self.name = name
        self.points = points
        self.category = category
        self.url = url
    }

    // Custom decoder so catalogs encoded before `url` existed still load
    // cleanly (missing key → ""), instead of failing the whole array
    // decode and silently emptying the catalog.
    private enum CodingKeys: String, CodingKey {
        case id, emoji, name, points, category, url
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.emoji = (try? c.decode(String.self, forKey: .emoji)) ?? "🎁"
        self.name = (try? c.decode(String.self, forKey: .name)) ?? ""
        self.points = (try? c.decode(Int.self, forKey: .points)) ?? 0
        self.category = (try? c.decode(String.self, forKey: .category)) ?? ""
        self.url = (try? c.decode(String.self, forKey: .url)) ?? ""
    }
}

struct GameRules: Codable {
    var rewardTiers: [RewardTier]
    var categoryRules: [CategoryPointRule]
    var pointsPerDollar: Int // global exchange rate: how many points = $1
    /// How many days after a chore's dueDate (or createdAt if no dueDate)
    /// before it counts as expired. 0 = never expire. Expired chores can
    /// still be completed but award 0 points instead of their configured
    /// value.
    var expirationWindowDays: Int = 0
    /// Pre-built catalog of redeemable items kids can tap to propose a
    /// goal at a known cost. Empty array = no curated catalog (kids
    /// fall back to free-form goals only).
    var redeemableItems: [RedeemableItem] = []

    // Custom decoder so legacy installs that don't have new fields
    // decode cleanly with default values.
    private enum CodingKeys: String, CodingKey {
        case rewardTiers, categoryRules, pointsPerDollar
        case expirationWindowDays, redeemableItems
    }
    init(rewardTiers: [RewardTier],
         categoryRules: [CategoryPointRule],
         pointsPerDollar: Int,
         expirationWindowDays: Int = 0,
         redeemableItems: [RedeemableItem] = []) {
        self.rewardTiers = rewardTiers
        self.categoryRules = categoryRules
        self.pointsPerDollar = pointsPerDollar
        self.expirationWindowDays = expirationWindowDays
        self.redeemableItems = redeemableItems
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.rewardTiers = try c.decode([RewardTier].self, forKey: .rewardTiers)
        self.categoryRules = try c.decode([CategoryPointRule].self, forKey: .categoryRules)
        self.pointsPerDollar = try c.decode(Int.self, forKey: .pointsPerDollar)
        self.expirationWindowDays = (try? c.decode(Int.self, forKey: .expirationWindowDays)) ?? 0
        self.redeemableItems = (try? c.decode([RedeemableItem].self, forKey: .redeemableItems)) ?? []
    }

    static let `default` = GameRules(
        rewardTiers: [
            RewardTier(name: "Small Reward",  minPoints: 50,  emoji: "🎁", description: "A small treat, snack, or privilege",  dollarValue: 10),
            RewardTier(name: "Medium Reward", minPoints: 150, emoji: "🎀", description: "A bigger outing or activity",          dollarValue: 30),
            RewardTier(name: "Large Reward",  minPoints: 375, emoji: "🏆", description: "A major experience or gift",           dollarValue: 75),
        ],
        categoryRules: [
            CategoryPointRule(category: "Chores",      emoji: "🧹", defaultPoints: 10, description: "Daily household chores"),
            CategoryPointRule(category: "Homework",    emoji: "📚", defaultPoints: 10, description: "School assignments and study time"),
            CategoryPointRule(category: "Home",        emoji: "🏠", defaultPoints: 15, description: "Home upkeep and repairs"),
            CategoryPointRule(category: "Maintenance", emoji: "🔧", defaultPoints: 15, description: "Larger maintenance tasks"),
            CategoryPointRule(category: "Family",      emoji: "👨‍👩‍👧", defaultPoints: 5,  description: "Family activities and errands"),
        ],
        pointsPerDollar: 5,
        expirationWindowDays: 0,
        redeemableItems: [
            RedeemableItem(emoji: "🎮", name: "30 min screen time",  points: 25,  category: "Screen time"),
            RedeemableItem(emoji: "🎮", name: "1 hour gaming",       points: 50,  category: "Screen time"),
            RedeemableItem(emoji: "🍿", name: "Pick the movie",      points: 40,  category: "Family"),
            RedeemableItem(emoji: "🍕", name: "Pick dinner",         points: 50,  category: "Family"),
            RedeemableItem(emoji: "🌅", name: "Stay up 30 min late", points: 25,  category: "Privileges"),
            RedeemableItem(emoji: "🛌", name: "Skip a chore",        points: 75,  category: "Privileges"),
            RedeemableItem(emoji: "🍦", name: "Ice cream trip",      points: 100, category: "Treats"),
            RedeemableItem(emoji: "🛒", name: "Trip to the store",   points: 100, category: "Outings"),
            RedeemableItem(emoji: "🎢", name: "Arcade day",          points: 250, category: "Outings"),
            RedeemableItem(emoji: "🎁", name: "Pick a small toy",    points: 125, category: "Treats"),
        ]
    )
}

// MARK: - Household-synced wrapper

/// On-disk shape for `Household.routinesJSON`. Wrapping the original
/// `[ChoreRoutineTemplate]` array inside a struct lets us also carry
/// GameRules (reward tiers, category point rules, expiration window)
/// without adding a new Core Data field. Decode is backward-compatible:
/// legacy installs that wrote the bare array still load (routines
/// preserved, rules default).
struct HouseholdRulesEnvelope: Codable {
    var routines: [ChoreRoutineTemplate]
    var rules: GameRules

    static let `default` = HouseholdRulesEnvelope(
        routines: [],
        rules: .default
    )

    /// Decode either the new wrapper object OR the legacy bare array.
    /// Used by both `ChoreRoutineStore.load` and `GameRulesStore`.
    static func decode(_ json: String) -> HouseholdRulesEnvelope {
        guard !json.isEmpty, let data = json.data(using: .utf8) else {
            return .default
        }
        // Try wrapper first
        if let env = try? JSONDecoder().decode(HouseholdRulesEnvelope.self, from: data) {
            return env
        }
        // Legacy: bare [ChoreRoutineTemplate]
        if let routines = try? JSONDecoder().decode([ChoreRoutineTemplate].self, from: data) {
            return HouseholdRulesEnvelope(routines: routines, rules: .default)
        }
        return .default
    }

    func encodedJSON() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let s = String(data: data, encoding: .utf8) else { return "" }
        return s
    }
}

// MARK: - Store

/// `GameRulesStore` is now backed by `Household.routinesJSON` (shared
/// envelope with chore routines). UserDefaults is the legacy fallback
/// for fresh launches and pre-sync installs; once a Household exists,
/// every write goes to the household record so settings sync across
/// devices.
final class GameRulesStore: ObservableObject {
    static let shared = GameRulesStore()
    private let legacyKey = "gameRules_v1"

    /// Set this once the Core Data stack + a Household is available
    /// (CasalistApp on first launch). All subsequent reads/writes go
    /// through this household.
    private weak var household: Household?
    private weak var context: NSManagedObjectContext?

    @Published var rules: GameRules {
        didSet { save() }
    }

    /// Toggle so the `didSet` doesn't loop when we reload from the
    /// household after a remote sync.
    private var suppressSave: Bool = false

    private init() {
        // Seed from UserDefaults legacy blob. Household will take over
        // once attached.
        if let data = UserDefaults.standard.data(forKey: legacyKey),
           var decoded = try? JSONDecoder().decode(GameRules.self, from: data) {
            // Append any default categories missing in the saved blob
            // (case-insensitive). New defaults like "Homework" reach
            // existing installs without wiping their customizations.
            let existing = Set(decoded.categoryRules.map { $0.category.lowercased() })
            for defaultRule in GameRules.default.categoryRules
            where !existing.contains(defaultRule.category.lowercased()) {
                decoded.categoryRules.append(defaultRule)
            }
            rules = decoded
        } else {
            rules = .default
        }
    }

    /// Wire the store to a Household. Reloads rules from the household's
    /// `routinesJSON` envelope; if the household has none yet but
    /// UserDefaults has a legacy blob, migrates it up. Safe to call
    /// repeatedly (e.g. after a remote-change refresh).
    func attach(to household: Household?, context: NSManagedObjectContext?) {
        self.household = household
        self.context = context
        guard let h = household else { return }
        let env = HouseholdRulesEnvelope.decode(h.routinesJSON)
        // If the household has no rules saved yet AND we still have a
        // UserDefaults legacy blob, push the legacy blob up to the
        // household so it syncs to the rest of the family.
        let isLegacyDefault = h.routinesJSON.isEmpty
        if isLegacyDefault {
            let migrated = HouseholdRulesEnvelope(routines: env.routines, rules: rules)
            h.routinesJSON = migrated.encodedJSON()
            try? context?.save()
        } else {
            suppressSave = true
            rules = env.rules
            suppressSave = false
        }
    }

    /// Re-read rules from the attached household. Call on remote-change
    /// notifications so settings edited on another device propagate.
    func refreshFromHousehold() {
        guard let h = household else { return }
        let env = HouseholdRulesEnvelope.decode(h.routinesJSON)
        guard env.rules != rules else { return }
        suppressSave = true
        rules = env.rules
        suppressSave = false
    }

    private func save() {
        if suppressSave { return }
        // Always mirror to UserDefaults as a device-local fallback.
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: legacyKey)
        }
        // If we have a household, write the merged envelope back so the
        // change syncs through CloudKit.
        guard let h = household else { return }
        var env = HouseholdRulesEnvelope.decode(h.routinesJSON)
        env.rules = rules
        h.routinesJSON = env.encodedJSON()
        try? context?.save()
    }

    func reset() {
        rules = .default
    }

    /// Returns the rule whose category name matches (case-insensitive), if any.
    func rule(for category: String) -> CategoryPointRule? {
        rules.categoryRules.first {
            $0.category.lowercased() == category.lowercased()
        }
    }
}

// `GameRules` needs to be Equatable so `refreshFromHousehold` can short-
// circuit on no-op syncs. The contents are all Codable/Equatable already.
extension GameRules: Equatable {}
extension RewardTier {}
extension CategoryPointRule {}
