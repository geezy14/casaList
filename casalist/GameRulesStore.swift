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
    /// Economy version stamped into the synced envelope. Bumped whenever
    /// the built-in reward economy changes so `GameRulesStore.attach`
    /// can run a one-time rescale on existing households. Legacy
    /// envelopes (no field) decode as 0 and get migrated up.
    var rulesVersion: Int = 0

    /// Current economy version. v1 = the 15-pt-chore / 5-pts-per-$
    /// rescale (Legend at 1,300).
    static let economyVersion = 1

    // MARK: Seasonal ladder
    /// When the current 60-day season began (household-wide). nil = not
    /// initialized yet (first launch seeds it).
    var seasonStart: Date? = nil
    /// Per-member lifetimePoints snapshot at season start, keyed by member
    /// uid string. Season score = current lifetimePoints − this baseline,
    /// so the ladder resets without touching the wallet or prestige.
    var seasonBaselines: [String: Int] = [:]
    /// Increments each roll, for display ("Season 3").
    var seasonNumber: Int = 0
    /// Monotonic marker for a forced household-wide season reset shipped in
    /// code. When `GameRulesStore.seasonEpoch` is higher than the stored
    /// value, the app performs a one-time reset (snapshot lifetime as the
    /// baseline so every score returns to 0) and stamps this. Lets us push
    /// a clean reset without it flip-flopping on every launch.
    var seasonEpoch: Int = 0
    /// Season length.
    static let seasonLength: TimeInterval = 60 * 24 * 60 * 60  // 60 days

    init(routines: [ChoreRoutineTemplate], rules: GameRules, rulesVersion: Int = 0,
         seasonStart: Date? = nil, seasonBaselines: [String: Int] = [:], seasonNumber: Int = 0,
         seasonEpoch: Int = 0) {
        self.routines = routines
        self.rules = rules
        self.rulesVersion = rulesVersion
        self.seasonStart = seasonStart
        self.seasonBaselines = seasonBaselines
        self.seasonNumber = seasonNumber
        self.seasonEpoch = seasonEpoch
    }

    private enum CodingKeys: String, CodingKey {
        case routines, rules, rulesVersion, seasonStart, seasonBaselines, seasonNumber, seasonEpoch
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.routines = (try? c.decode([ChoreRoutineTemplate].self, forKey: .routines)) ?? []
        self.rules = (try? c.decode(GameRules.self, forKey: .rules)) ?? .default
        self.rulesVersion = (try? c.decode(Int.self, forKey: .rulesVersion)) ?? 0
        self.seasonStart = try? c.decode(Date.self, forKey: .seasonStart)
        self.seasonBaselines = (try? c.decode([String: Int].self, forKey: .seasonBaselines)) ?? [:]
        self.seasonNumber = (try? c.decode(Int.self, forKey: .seasonNumber)) ?? 0
        self.seasonEpoch = (try? c.decode(Int.self, forKey: .seasonEpoch)) ?? 0
    }

    static let `default` = HouseholdRulesEnvelope(
        routines: [],
        rules: .default,
        rulesVersion: economyVersion
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

    /// One-time rescale of an existing household's rules to the current
    /// economy: 5 pts per $1, reward tiers priced from their dollar value
    /// (or halved if none), redeem catalog halved, category points capped
    /// at 15. Preserves custom items/tiers — just rebalances the numbers.
    /// Deterministic, so two devices migrating the same v0 data land on
    /// the same result.
    static func rescaledToCurrentEconomy(_ rules: GameRules) -> GameRules {
        var r = rules
        r.pointsPerDollar = 5
        r.rewardTiers = r.rewardTiers.map { tier in
            var t = tier
            if let dollars = t.dollarValue, dollars > 0 {
                t.minPoints = Int((dollars * 5).rounded())
            } else {
                t.minPoints = max(5, Int((Double(t.minPoints) / 2).rounded()))
            }
            return t
        }
        r.redeemableItems = r.redeemableItems.map { item in
            var i = item
            i.points = max(5, Int((Double(i.points) / 2).rounded()))
            return i
        }
        r.categoryRules = r.categoryRules.map { rule in
            var c = rule
            if c.defaultPoints > 15 { c.defaultPoints = 15 }
            return c
        }
        return r
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

    /// Seasonal ladder state (mirrors the envelope). Published so the
    /// leaderboard / profile update when a season rolls.
    @Published private(set) var seasonStart: Date? = nil
    @Published private(set) var seasonNumber: Int = 0
    private var seasonBaselines: [String: Int] = [:]

    /// Bump to force a one-time household-wide season reset on the next
    /// launch (a clean Season 1, every score back to 0; admins re-grant
    /// from there). Stored per-household via
    /// `HouseholdRulesEnvelope.seasonEpoch`, so the reset runs once and
    /// never flip-flops.
    static let seasonEpoch = 3

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
        var env = HouseholdRulesEnvelope.decode(h.routinesJSON)
        // If the household has no rules saved yet AND we still have a
        // UserDefaults legacy blob, push the legacy blob up to the
        // household so it syncs to the rest of the family.
        let isLegacyDefault = h.routinesJSON.isEmpty
        if isLegacyDefault {
            let migrated = HouseholdRulesEnvelope(
                routines: env.routines, rules: rules,
                rulesVersion: HouseholdRulesEnvelope.economyVersion)
            h.routinesJSON = migrated.encodedJSON()
            try? context?.save()
            suppressSave = true
            rules = migrated.rules
            suppressSave = false
        } else {
            // One-time economy migration: rescale existing households to the
            // current reward economy, then stamp the version so it never
            // runs again (and other devices skip once it syncs).
            if env.rulesVersion < HouseholdRulesEnvelope.economyVersion {
                env.rules = HouseholdRulesEnvelope.rescaledToCurrentEconomy(env.rules)
                env.rulesVersion = HouseholdRulesEnvelope.economyVersion
                h.routinesJSON = env.encodedJSON()
                try? context?.save()
            }
            suppressSave = true
            rules = env.rules
            suppressSave = false
        }
        // Load season state into published mirror.
        loadSeasonState(from: HouseholdRulesEnvelope.decode(h.routinesJSON))
    }

    /// Re-read rules from the attached household. Call on remote-change
    /// notifications so settings edited on another device propagate.
    func refreshFromHousehold() {
        guard let h = household else { return }
        let env = HouseholdRulesEnvelope.decode(h.routinesJSON)
        loadSeasonState(from: env)
        guard env.rules != rules else { return }
        suppressSave = true
        rules = env.rules
        suppressSave = false
    }

    private func loadSeasonState(from env: HouseholdRulesEnvelope) {
        seasonStart = env.seasonStart
        seasonBaselines = env.seasonBaselines
        seasonNumber = env.seasonNumber
    }

    // MARK: - Seasonal ladder

    /// A member's CURRENT-season score = lifetime earned since the season
    /// baseline. Drives current level, tier badge, and the leaderboard.
    /// Never negative. The spendable wallet (`points`) is separate.
    func seasonPoints(for member: FamilyMember) -> Int {
        let base = seasonBaselines[member.uid.uuidString] ?? 0
        return max(0, Int(member.lifetimePoints) - base)
    }

    /// Whole days left in the current season (0 if not started).
    func seasonDaysRemaining() -> Int {
        guard let start = seasonStart else { return 0 }
        let end = start.addingTimeInterval(HouseholdRulesEnvelope.seasonLength)
        let secs = end.timeIntervalSinceNow
        return max(0, Int((secs / 86_400).rounded(.up)))
    }

    /// Initialize Season 1 (fresh — everyone's ladder starts at 0) or roll
    /// to the next season when 60 days elapse. Household-wide and guarded by
    /// `seasonStart`, so once it rolls and syncs, other devices skip it.
    /// Snapshots each member's lifetimePoints as the new baseline.
    func rollSeasonIfNeeded(members: [FamilyMember]) {
        guard let h = household else { return }
        var env = HouseholdRulesEnvelope.decode(h.routinesJSON)
        let now = Date()
        let needsInit = env.seasonStart == nil
        let elapsed = env.seasonStart.map { now.timeIntervalSince($0) >= HouseholdRulesEnvelope.seasonLength } ?? false
        // Snapshot every live member's lifetime as their baseline, so
        // season score (lifetime − baseline) starts at 0 for everyone.
        func snapshot() -> [String: Int] {
            var b: [String: Int] = [:]
            for m in members where m.deletedAt == nil { b[m.uid.uuidString] = Int(m.lifetimePoints) }
            return b
        }
        var changed = false
        if needsInit {
            env.seasonBaselines = snapshot()
            env.seasonStart = now
            env.seasonNumber = 1
            env.seasonEpoch = Self.seasonEpoch
            changed = true
        } else if elapsed {
            // Natural 60-day roll: fresh race, everyone back to 0.
            env.seasonBaselines = snapshot()
            env.seasonStart = now
            env.seasonNumber = env.seasonNumber + 1
            env.seasonEpoch = Self.seasonEpoch
            changed = true
        } else if env.seasonEpoch < Self.seasonEpoch {
            // Forced one-time reset shipped in code: a clean Season 1 with
            // every score back to 0 (snapshot lifetime as the baseline);
            // admins re-grant from there. Internal counter AND display are
            // both 1 — no offset, nothing mismatched. Latched by the epoch
            // so it runs once. NOTE: this is only safe once the older
            // builds (11/12) are off every family device — build 12 will
            // otherwise re-zero the baselines and re-inflate. See the ship
            // notes; all devices must update to this build.
            env.seasonBaselines = snapshot()
            env.seasonStart = now
            env.seasonNumber = 1
            env.seasonEpoch = Self.seasonEpoch
            changed = true
        } else {
            // Mid-season: backfill a baseline for any member missing one
            // (joined, or got a new uid via the dedupe/reconcile pipeline)
            // so they start at 0 this season, not their full lifetime.
            for m in members where m.deletedAt == nil && env.seasonBaselines[m.uid.uuidString] == nil {
                env.seasonBaselines[m.uid.uuidString] = Int(m.lifetimePoints)
                changed = true
            }
        }
        if changed {
            h.routinesJSON = env.encodedJSON()
            try? context?.save()
        }
        loadSeasonState(from: env)
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
