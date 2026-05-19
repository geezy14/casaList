import SwiftUI
import CoreData

/// Rewards-tab specific inbox. Replaces the generic InboxView when
/// surfaced from the Rewards top-bar tray icon. Three shapes available
/// via a segmented picker — Geezy decides which one stays.
///
///   • Activity — pending approvals + a chronological feed of
///                completions, redemptions, and recent approvals
///   • Standings — "on top right now" header + pending approvals +
///                 a weekly-race bar chart per member + recent
///                 redemptions
///   • Goals — pending approvals + every member's in-flight goals
///             with progress bars + recently redeemed
///
/// Picker state lives in `rewardsInboxShape` AppStorage so the
/// selection survives navigation.
struct LeaderboardInboxView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.colorScheme) private var sys
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("meUid") private var meUid: String = ""
    @AppStorage("rewardsInboxShape") private var shape: String = "activity"

    @StateObject private var gameRules = GameRulesStore.shared

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var members: FetchedResults<FamilyMember>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyGoal.createdAt, ascending: false)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var goals: FetchedResults<FamilyGoal>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.completedAt, ascending: false)], predicate: NSPredicate(format: "deletedAt == nil AND isCompleted == YES"))
    private var completedTasks: FetchedResults<TaskItem>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: false)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var allTasks: FetchedResults<TaskItem>

    private var P: CasalistCottage.Palette { CasalistCottage.Palette.resolve(sys == .dark) }

    private var me: FamilyMember? {
        FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)
    }
    private var iAmAdmin: Bool { me?.canManageFamily ?? false }

    private var pendingGoals: [FamilyGoal] {
        goals.filter { GoalApproval.isPending($0) && !$0.isRedeemed }
    }
    private var pendingForMe: [FamilyGoal] {
        let myName = me?.name.lowercased() ?? userName.lowercased()
        return pendingGoals.filter { GoalApproval.realOwnerName($0).lowercased() == myName }
    }
    private var redeemedGoals: [FamilyGoal] {
        goals.filter { $0.isRedeemed }
            .sorted { ($0.redeemedAt ?? .distantPast) > ($1.redeemedAt ?? .distantPast) }
    }
    private var approvedNotRedeemed: [FamilyGoal] {
        goals.filter { !GoalApproval.isPending($0) && !$0.isRedeemed }
    }
    private var sortedMembers: [FamilyMember] {
        members.sorted { $0.points > $1.points }
    }
    private func member(named n: String) -> FamilyMember? {
        members.first { $0.name.lowercased() == n.lowercased() }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                P.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        shapePicker
                            .padding(.top, 4)
                        Group {
                            switch shape {
                            case "standings": standingsShape
                            case "goals":     goalsShape
                            default:          activityShape
                            }
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    try? await Task.sleep(for: .seconds(2))
                    moc.refreshAllObjects()
                }
            }
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .foregroundStyle(P.text)
        }
    }

    private var shapePicker: some View {
        Picker("Shape", selection: $shape) {
            Text("Activity").tag("activity")
            Text("Standings").tag("standings")
            Text("Goals").tag("goals")
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Shape A: Activity feed

    private struct ActivityEvent: Identifiable {
        enum Kind { case completion, redemption, approval }
        let id = UUID()
        let kind: Kind
        let date: Date
        let actorName: String
        let title: String
        let detail: String
        let pointsDelta: Int
        let tint: Color
        let symbol: String
    }

    private var activityFeed: [ActivityEvent] {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -14, to: Date()) ?? Date.distantPast

        var events: [ActivityEvent] = []
        for t in completedTasks where (t.completedAt ?? t.createdAt) >= cutoff {
            events.append(ActivityEvent(
                kind: .completion,
                date: t.completedAt ?? t.createdAt,
                actorName: t.assignee ?? "Someone",
                title: t.task,
                detail: t.category.capitalized,
                pointsDelta: Int(t.points),
                tint: P.mint,
                symbol: "checkmark.circle.fill"
            ))
        }
        for g in redeemedGoals where (g.redeemedAt ?? g.createdAt) >= cutoff {
            events.append(ActivityEvent(
                kind: .redemption,
                date: g.redeemedAt ?? g.createdAt,
                actorName: g.ownerName,
                title: g.label,
                detail: "Redeemed",
                pointsDelta: -Int(g.targetPoints),
                tint: P.peach,
                symbol: "gift.fill"
            ))
        }
        for g in approvedNotRedeemed where g.createdAt >= cutoff {
            events.append(ActivityEvent(
                kind: .approval,
                date: g.createdAt,
                actorName: GoalApproval.realOwnerName(g),
                title: g.label,
                detail: "Goal approved",
                pointsDelta: 0,
                tint: P.lavender,
                symbol: "checkmark.seal.fill"
            ))
        }
        return events.sorted { $0.date > $1.date }.prefix(50).map { $0 }
    }

    private var activityShape: some View {
        VStack(spacing: 14) {
            if iAmAdmin && !pendingGoals.isEmpty {
                sectionHeader("AWAITING APPROVAL", tint: P.peach, count: pendingGoals.count)
                ForEach(pendingGoals) { g in compactApprovalRow(g) }
            } else if !iAmAdmin && !pendingForMe.isEmpty {
                sectionHeader("AWAITING PARENT APPROVAL", tint: P.peach, count: pendingForMe.count)
                ForEach(pendingForMe) { g in submitterRow(g) }
            }

            sectionHeader("ACTIVITY", tint: P.mint, count: activityFeed.count)
            if activityFeed.isEmpty {
                emptyCard("Nothing's happened in the last 2 weeks.")
            } else {
                VStack(spacing: 8) {
                    ForEach(activityFeed) { e in activityRow(e) }
                }
            }
        }
    }

    private func activityRow(_ e: ActivityEvent) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(e.tint.opacity(0.18)).frame(width: 32, height: 32)
                Image(systemName: e.symbol).font(.system(size: 13, weight: .bold)).foregroundStyle(e.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(e.title).font(.system(size: 14, weight: .heavy)).lineLimit(1)
                HStack(spacing: 4) {
                    if let m = member(named: e.actorName) {
                        CLAvatar(m.asCLMember, size: 14)
                    }
                    Text("\(e.actorName) · \(e.detail)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(P.textMuted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                if e.pointsDelta != 0 {
                    Text("\(e.pointsDelta > 0 ? "+" : "")\(e.pointsDelta)")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(e.pointsDelta > 0 ? P.mint : P.peach)
                        .monospacedDigit()
                }
                Text(relativeDate(e.date))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(P.textMuted)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16).fill(P.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(P.border, lineWidth: 1))
    }

    // MARK: - Shape B: Standings

    /// Points this member has earned via completed tasks in the last 7 days.
    private func pointsThisWeek(for m: FamilyMember) -> Int {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return completedTasks
            .filter { (($0.assignee ?? "").lowercased() == m.name.lowercased())
                   && (($0.completedAt ?? .distantPast) >= start) }
            .reduce(0) { $0 + Int($1.points) }
    }

    private var standingsShape: some View {
        VStack(spacing: 14) {
            standingsLeaderCard
            if iAmAdmin {
                sectionHeader("AWAITING APPROVAL", tint: P.peach, count: pendingGoals.count)
                if pendingGoals.isEmpty {
                    emptyCard("All caught up.")
                } else {
                    ForEach(pendingGoals) { g in compactApprovalRow(g) }
                }
            } else if !pendingForMe.isEmpty {
                sectionHeader("AWAITING PARENT APPROVAL", tint: P.peach, count: pendingForMe.count)
                ForEach(pendingForMe) { g in submitterRow(g) }
            }

            sectionHeader("THIS WEEK'S RACE", tint: P.mint, count: members.count)
            weeklyRaceCard

            if iAmAdmin {
                sectionHeader("CHORE STATS", tint: P.coral, count: members.count)
                adminChoreStatsCard
            }

            sectionHeader("RECENT REDEMPTIONS", tint: P.lavender, count: redeemedGoals.count)
            if redeemedGoals.isEmpty {
                emptyCard("Nothing redeemed yet.")
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(redeemedGoals.prefix(8))) { g in redemptionRow(g) }
                }
            }
        }
    }

    // MARK: - Admin chore stats

    /// Categories that count as "chores" for the admin stats — excludes
    /// reminders, events, and category-less items so admins see real
    /// chore throughput, not pinned-info noise.
    private let choreCategories: Set<String> = ["chores", "home", "maintenance"]

    private func choreStats(for m: FamilyMember) -> (assigned: Int, done: Int) {
        let mine = allTasks.filter { t in
            let cat = t.category.lowercased()
            guard choreCategories.contains(cat) else { return false }
            return (t.assignee ?? "").lowercased() == m.name.lowercased()
        }
        let done = mine.filter(\.isCompleted).count
        return (mine.count, done)
    }

    private var adminChoreStatsCard: some View {
        VStack(spacing: 10) {
            ForEach(members, id: \.uid) { m in
                let (assigned, done) = choreStats(for: m)
                let rate = assigned > 0 ? Double(done) / Double(assigned) : 0
                HStack(spacing: 10) {
                    CLAvatar(m.asCLMember, size: 22)
                    Text(m.name)
                        .font(.system(size: 13, weight: .heavy))
                        .lineLimit(1)
                        .frame(width: 84, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(P.surfaceAlt.opacity(0.6))
                            Capsule().fill(rate >= 1.0 ? P.mint : P.coral)
                                .frame(width: geo.size.width * CGFloat(rate))
                        }
                    }
                    .frame(height: 10)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(done)/\(assigned)")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(P.textDim)
                            .monospacedDigit()
                        Text(assigned == 0 ? "—" : "\(Int((rate * 100).rounded()))%")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(rate >= 1.0 ? P.mint : P.textMuted)
                            .monospacedDigit()
                    }
                    .frame(width: 56, alignment: .trailing)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(P.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(P.border, lineWidth: 1))
    }

    private var standingsLeaderCard: some View {
        Group {
            if let top = sortedMembers.first {
                let runner = sortedMembers.dropFirst().first
                let lead = Int(top.points - (runner?.points ?? 0))
                HStack(spacing: 14) {
                    LeveledAvatar(member: top, size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ON TOP")
                            .font(.system(size: 10, weight: .heavy)).tracking(1.2)
                            .foregroundStyle(.white.opacity(0.85))
                        Text(top.name)
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundStyle(.white)
                        if let r = runner, lead > 0 {
                            Text("\(top.points) pts · \(lead) ahead of \(r.name)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(1)
                        } else {
                            Text("\(top.points) pts")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    Spacer()
                    Text("🏆").font(.system(size: 36))
                }
                .padding(18)
                .background(P.peach)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                emptyCard("No family members yet.")
            }
        }
    }

    private var weeklyRaceCard: some View {
        let scores: [(FamilyMember, Int)] = members.map { ($0, pointsThisWeek(for: $0)) }
            .sorted { $0.1 > $1.1 }
        let max = scores.first?.1 ?? 0
        return VStack(spacing: 10) {
            ForEach(scores, id: \.0.uid) { entry in
                let (m, pts) = entry
                let frac = max > 0 ? Double(pts) / Double(max) : 0
                HStack(spacing: 10) {
                    CLAvatar(m.asCLMember, size: 22)
                    Text(m.name)
                        .font(.system(size: 13, weight: .heavy))
                        .lineLimit(1)
                        .frame(width: 84, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(P.surfaceAlt.opacity(0.6))
                            Capsule().fill(P.mint)
                                .frame(width: geo.size.width * CGFloat(frac))
                        }
                    }
                    .frame(height: 10)
                    Text("\(pts)")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(P.textDim)
                        .monospacedDigit()
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(P.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(P.border, lineWidth: 1))
    }

    private func redemptionRow(_ g: FamilyGoal) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "gift.fill").font(.system(size: 14)).foregroundStyle(P.peach)
            VStack(alignment: .leading, spacing: 2) {
                Text(g.label).font(.system(size: 13, weight: .heavy))
                Text("\(g.ownerName) · \(g.targetPoints) pts")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted)
            }
            Spacer()
            if let d = g.redeemedAt {
                Text(relativeDate(d)).font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14).fill(P.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(P.border, lineWidth: 1))
    }

    // MARK: - Shape C: Goals-focused

    private var goalsShape: some View {
        VStack(spacing: 14) {
            if iAmAdmin {
                sectionHeader("AWAITING APPROVAL", tint: P.peach, count: pendingGoals.count)
                if pendingGoals.isEmpty {
                    emptyCard("All caught up.")
                } else {
                    ForEach(pendingGoals) { g in compactApprovalRow(g) }
                }
            } else if !pendingForMe.isEmpty {
                sectionHeader("AWAITING PARENT APPROVAL", tint: P.peach, count: pendingForMe.count)
                ForEach(pendingForMe) { g in submitterRow(g) }
            }

            sectionHeader("IN FLIGHT", tint: P.mint, count: approvedNotRedeemed.count)
            if approvedNotRedeemed.isEmpty {
                emptyCard("No goals in flight.")
            } else {
                VStack(spacing: 8) {
                    ForEach(approvedNotRedeemed) { g in inFlightRow(g) }
                }
            }

            sectionHeader("RECENTLY REDEEMED", tint: P.lavender, count: redeemedGoals.count)
            if redeemedGoals.isEmpty {
                emptyCard("Nothing redeemed yet.")
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(redeemedGoals.prefix(8))) { g in redemptionRow(g) }
                }
            }
        }
    }

    private func inFlightRow(_ g: FamilyGoal) -> some View {
        let owner = member(named: g.ownerName)
        let balance = Int(owner?.points ?? 0)
        let target = Int(g.targetPoints)
        let progress = target > 0 ? min(1.0, Double(balance) / Double(target)) : 0
        let remaining = max(0, target - balance)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                if let m = owner { LeveledAvatar(member: m, size: 32) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(g.label).font(.system(size: 14, weight: .heavy))
                    Text("\(g.ownerName) · \(balance)/\(target) pts")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(P.textMuted)
                }
                Spacer()
                Text(remaining == 0 ? "Ready" : "\(remaining) to go")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(remaining == 0 ? P.mint : P.peach)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(P.surfaceAlt.opacity(0.6))
                    Capsule().fill(remaining == 0 ? P.mint : P.peach)
                        .frame(width: geo.size.width * CGFloat(progress))
                }
            }
            .frame(height: 8)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(P.surface))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(P.border, lineWidth: 1))
    }

    // MARK: - Shared rows

    /// Compact admin approval row — single-line + Deny/Approve. Tap
    /// expands? Leave full-form for the original InboxView. This is
    /// meant to live in a leaderboard summary, not be the main editor.
    private func compactApprovalRow(_ g: FamilyGoal) -> some View {
        let owner = member(named: GoalApproval.realOwnerName(g))
        let needsPrice = g.targetPoints == 0
        return HStack(spacing: 10) {
            if let m = owner {
                LeveledAvatar(member: m, size: 28)
            } else {
                ZStack {
                    Circle().fill(P.surfaceAlt).frame(width: 28, height: 28)
                    Image(systemName: "questionmark").font(.system(size: 11)).foregroundStyle(P.textMuted)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(g.label).font(.system(size: 13, weight: .heavy)).lineLimit(1)
                Text(needsPrice
                     ? "\(GoalApproval.realOwnerName(g)) · needs a price"
                     : "\(GoalApproval.realOwnerName(g)) · \(g.targetPoints) pts")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Button {
                GoalApproval.deny(g, in: moc); try? moc.save()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
                    .frame(width: 30, height: 30).background(Circle().fill(Color.red.opacity(0.8)))
            }.buttonStyle(.row)
            Button {
                if needsPrice {
                    GoalApproval.approve(g, targetPoints: 50)  // fallback price; full editor in classic InboxView
                } else {
                    GoalApproval.approve(g)
                }
                try? moc.save()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
                    .frame(width: 30, height: 30).background(Circle().fill(P.mint))
            }.buttonStyle(.row)
            .disabled(needsPrice)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14).fill(P.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(P.border, lineWidth: 1))
    }

    private func submitterRow(_ g: FamilyGoal) -> some View {
        HStack(spacing: 10) {
            Text("⏳").font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text(g.label).font(.system(size: 13, weight: .heavy))
                Text("\(g.targetPoints) pts target")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textMuted)
            }
            Spacer()
            Button {
                GoalApproval.deny(g, in: moc); try? moc.save()
            } label: {
                Text("Cancel").font(.system(size: 11, weight: .heavy)).foregroundStyle(P.peach)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(P.peach.opacity(0.15)))
            }.buttonStyle(.row)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14).fill(P.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(P.border, lineWidth: 1))
    }

    // MARK: - Bits

    private func sectionHeader(_ s: String, tint: Color, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(s).font(.system(size: 11, weight: .heavy)).tracking(1.4).foregroundStyle(tint)
            if count > 0 {
                Text("\(count)").font(.system(size: 10, weight: .heavy))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(tint.opacity(0.2)))
                    .foregroundStyle(tint)
            }
            Spacer()
        }
        .padding(.leading, 4)
    }

    private func emptyCard(_ msg: String) -> some View {
        Text(msg).font(.system(size: 13, weight: .semibold)).foregroundStyle(P.textMuted)
            .frame(maxWidth: .infinity).padding(.vertical, 16).padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(P.surface))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(P.border, lineWidth: 1))
    }

    private func relativeDate(_ d: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: d, relativeTo: Date())
    }
}
