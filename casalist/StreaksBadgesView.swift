import SwiftUI
import CoreData

/// Household streaks & badges overview — opened from the coral Dashboard
/// tile. Per-member current/best streak plus the badges they've earned,
/// with a legend of every badge available.
struct StreaksBadgesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var sys
    @Environment(\.managedObjectContext) private var moc
    var onHome: (() -> Void)? = nil

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)],
                  predicate: NSPredicate(format: "deletedAt == nil"))
    private var members: FetchedResults<FamilyMember>

    private var P: CasalistCottage.Palette { CasalistCottage.Palette.resolve(sys == .dark) }
    private let totalBadges = Badge.allCases.count

    var body: some View {
        NavigationStack {
            ZStack {
                P.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(members, id: \.uid) { memberCard($0) }
                        if members.isEmpty {
                            Text("No family members yet.")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(P.textMuted)
                        }
                        legendCard
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Streaks & Badges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { if let onHome { onHome() } else { dismiss() } }
                }
            }
        }
    }

    private func memberCard(_ m: FamilyMember) -> some View {
        let current = StreakTracker.effectiveCurrent(for: m.uid)
        let best = StreakTracker.load(for: m.uid).best
        let earned = AwardedBadgeStore.awarded(for: m.uid)
        let earnedSorted = Badge.allCases.filter { earned.contains($0) }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                CLAvatar(m.asCLMember, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.name).font(.system(size: 16, weight: .heavy))
                    Text("\(earned.count)/\(totalBadges) badges")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textMuted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("🔥 \(current)")
                        .font(.system(size: 16, weight: .heavy)).foregroundStyle(P.peach).monospacedDigit()
                    Text("best \(best)")
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted).monospacedDigit()
                }
            }
            if earnedSorted.isEmpty {
                Text("No badges yet — finish chores to start earning.")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(P.textMuted)
            } else {
                FlexibleBadgeRow(badges: earnedSorted)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(P.surface))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(P.border, lineWidth: 1))
    }

    private var legendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ALL BADGES")
                .font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim)
            ForEach(Badge.allCases, id: \.self) { b in
                HStack(spacing: 10) {
                    Text(b.emoji).font(.system(size: 18))
                    Text(b.label).font(.system(size: 13, weight: .heavy))
                    Spacer()
                    Text(badgeHint(b)).font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textMuted)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(P.surface.opacity(0.5)))
    }

    private func badgeHint(_ b: Badge) -> String {
        switch b {
        case .firstChore: return "1 chore"
        case .tenChores: return "10 chores"
        case .fiftyChores: return "50 chores"
        case .hundredPoints: return "100 pts"
        case .fiveHundredPoints: return "500 pts"
        case .threeDayStreak: return "3-day streak"
        case .sevenDayStreak: return "7-day streak"
        case .fourteenDayStreak: return "14-day streak"
        case .firstRedeem: return "1 reward"
        }
    }
}

/// Wrapping row of earned badge chips.
private struct FlexibleBadgeRow: View {
    let badges: [Badge]
    var body: some View {
        let cols = [GridItem(.adaptive(minimum: 64), spacing: 8)]
        LazyVGrid(columns: cols, alignment: .leading, spacing: 8) {
            ForEach(badges, id: \.self) { b in
                HStack(spacing: 4) {
                    Text(b.emoji).font(.system(size: 14))
                    Text(b.label).font(.system(size: 10, weight: .heavy)).lineLimit(1)
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Capsule().fill(Color.primary.opacity(0.06)))
            }
        }
    }
}
