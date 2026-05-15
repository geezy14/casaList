import SwiftUI
import CoreData

/// Read-only stats roll-up over existing TaskItem + FamilyMember + FamilyGoal
/// data. No state, no sync impact — just aggregations the family can scroll
/// through to see what they've accomplished together.
struct FamilyStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var sys
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)])
    private var members: FetchedResults<FamilyMember>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: true)])
    private var tasks: FetchedResults<TaskItem>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyGoal.createdAt, ascending: true)])
    private var goals: FetchedResults<FamilyGoal>

    private var P: CasalistCottage.Palette { CasalistCottage.Palette.resolve(sys == .dark) }

    var body: some View {
        NavigationStack {
            ZStack {
                P.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        heroCard
                        topRow
                        choreFavorites
                        weekdayHeatmap
                        goalsBreakdown
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                .scrollIndicators(.hidden)
            }
            .foregroundStyle(P.text)
            .navigationTitle("Family stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: – Numbers we'll quote in multiple places

    private var completedTasks: [TaskItem] {
        tasks.filter { $0.isCompleted }
    }
    private var totalPointsAwarded: Int {
        completedTasks.reduce(0) { $0 + Int($1.points) }
    }
    private var totalChoresCompleted: Int {
        completedTasks.filter { !["reminders", "groceries", "maintenance"].contains($0.category.lowercased()) }.count
    }
    private var redeemedGoals: [FamilyGoal] { goals.filter { $0.isRedeemed } }

    // MARK: – Sections

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ALL TIME").font(.system(size: 11, weight: .heavy)).tracking(1.4).foregroundStyle(.white.opacity(0.8))
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                statBigNumber(value: "\(totalChoresCompleted)", caption: "chores done")
                statBigNumber(value: "\(totalPointsAwarded)", caption: "points earned")
                statBigNumber(value: "\(redeemedGoals.count)", caption: "rewards 🏆")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28).fill(
                LinearGradient(colors: [P.peach, P.coral], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        )
    }

    private func statBigNumber(value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 32, weight: .heavy)).foregroundStyle(.white)
            Text(caption).font(.system(size: 10, weight: .heavy)).foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: – Top row

    private var topRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("TOP EARNER")
            if let top = members.max(by: { $0.points < $1.points }), top.points > 0 {
                HStack(spacing: 14) {
                    CLAvatar(top.asCLMember, size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(top.name).font(.system(size: 18, weight: .heavy))
                        Text("\(top.points) pts")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(P.textMuted)
                    }
                    Spacer()
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 20).fill(P.surface))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(P.border, lineWidth: 1.5))
            } else {
                emptyLine("No points earned yet")
            }
        }
    }

    // MARK: – Most-claimed chores

    private var choreFavorites: some View {
        let byLabel = Dictionary(grouping: completedTasks, by: { $0.task.lowercased() })
            .map { (label: $0.key, count: $0.value.count, sample: $0.value.first?.task ?? $0.key) }
            .sorted { $0.count > $1.count }
            .prefix(5)
        return VStack(alignment: .leading, spacing: 8) {
            sectionTitle("MOST-CLAIMED CHORES")
            if byLabel.isEmpty {
                emptyLine("Complete some chores and they'll show up here")
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(byLabel.enumerated()), id: \.offset) { _, entry in
                        HStack {
                            Text(entry.sample).font(.system(size: 13, weight: .heavy))
                            Spacer()
                            Text("\(entry.count)×").font(.system(size: 12, weight: .heavy)).foregroundStyle(P.peach)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 16).fill(P.surface))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(P.border, lineWidth: 1))
                    }
                }
            }
        }
    }

    // MARK: – Weekday heatmap (when does the family work most?)

    private var weekdayHeatmap: some View {
        let cal = Calendar.current
        var counts = Array(repeating: 0, count: 7)
        for t in completedTasks {
            // Use createdAt as a proxy for "when" since we don't store
            // completedAt. Close enough for "which day of the week sees
            // the most activity" trend.
            let day = cal.component(.weekday, from: t.createdAt) - 1 // 0=Sun
            counts[day] += 1
        }
        let max = counts.max() ?? 1
        let labels = ["S", "M", "T", "W", "T", "F", "S"]
        return VStack(alignment: .leading, spacing: 8) {
            sectionTitle("WHEN WE WORK")
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 6).fill(P.peach)
                            .frame(width: 28, height: CGFloat(max == 0 ? 4 : (10 + 70 * counts[i] / max)))
                            .opacity(counts[i] == 0 ? 0.25 : 1.0)
                        Text(labels[i]).font(.system(size: 10, weight: .heavy)).foregroundStyle(P.textMuted)
                        Text("\(counts[i])").font(.system(size: 9, weight: .semibold)).foregroundStyle(P.textDim)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 10).padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 18).fill(P.surface))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(P.border, lineWidth: 1))
        }
    }

    // MARK: – Goals breakdown

    private var goalsBreakdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("GOALS")
            HStack(spacing: 10) {
                miniStat("\(goals.filter { !$0.isRedeemed }.count)", caption: "in progress", tint: P.sky)
                miniStat("\(redeemedGoals.count)", caption: "redeemed", tint: P.butter)
                let totalSpent = redeemedGoals.reduce(0) { $0 + Int($1.targetPoints) }
                miniStat("\(totalSpent)", caption: "pts spent", tint: P.lavender)
            }
        }
    }

    private func miniStat(_ value: String, caption: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 22, weight: .heavy)).foregroundStyle(tint)
            Text(caption).font(.system(size: 10, weight: .heavy)).foregroundStyle(P.textMuted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 18).fill(tint.opacity(0.15)))
    }

    // MARK: – Building blocks

    private func sectionTitle(_ s: String) -> some View {
        Text(s).font(.system(size: 11, weight: .heavy)).tracking(1.4).foregroundStyle(P.textDim).padding(.leading, 4)
    }

    private func emptyLine(_ s: String) -> some View {
        Text(s).font(.system(size: 12, weight: .semibold)).foregroundStyle(P.textMuted)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 16).fill(P.surface))
    }
}
