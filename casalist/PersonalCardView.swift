import SwiftUI
import CoreData

/// Baseball-card-style personal stats view.
/// Triggered by tapping the profile photo on the Home greeting card.
struct PersonalCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var sys
    @AppStorage("paletteName") private var paletteName: String = "vivid"
    @AppStorage("userName") private var userName: String = ""

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)],
        predicate: NSPredicate(format: "deletedAt == nil")
    ) private var members: FetchedResults<FamilyMember>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: true)],
        predicate: NSPredicate(format: "deletedAt == nil")
    ) private var allTodos: FetchedResults<TaskItem>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FamilyGoal.createdAt, ascending: false)],
        predicate: NSPredicate(format: "deletedAt == nil")
    ) private var allGoals: FetchedResults<FamilyGoal>

    @StateObject private var gameRules = GameRulesStore.shared

    @State private var showEditPhoto = false
    @State private var showShareSheet = false
    @State private var shareImage: UIImage? = nil

    private var P: CasalistCottage.Palette {
        CasalistCottage.Palette.resolveForPreview(paletteName, dark: sys == .dark)
    }

    // ── Identity ──────────────────────────────────────────────────────────────

    private var me: FamilyMember? {
        let trimmed = userName.trimmingCharacters(in: .whitespaces).lowercased()
        return members.first { $0.name.lowercased() == trimmed }
    }

    private var myName: String {
        (me?.name ?? userName).trimmingCharacters(in: .whitespaces)
    }

    private var memberSince: String {
        guard let d = me?.createdAt else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: d)
    }

    private var myLifetimePoints: Int {
        guard let m = me else { return 0 }
        return Int(max(m.lifetimePoints, m.points))
    }
    private var myRankLabel: String { levelLabel(for: myLifetimePoints) }
    private var myRankLevel: AvatarLevel { AvatarLevel(lifetimePoints: myLifetimePoints) }

    // ── Stat computations ─────────────────────────────────────────────────────

    private var myCompletedTasks: [TaskItem] {
        let name = myName.lowercased()
        return allTodos.filter {
            $0.completedAt != nil &&
            ($0.assignee ?? "").lowercased() == name
        }
    }

    private var myAssignedTasks: [TaskItem] {
        let name = myName.lowercased()
        return allTodos.filter {
            ($0.assignee ?? "").lowercased() == name
        }
    }

    private var completedChores: Int {
        myCompletedTasks.filter { $0.category.lowercased() == "chores" }.count
    }

    private var avgRate: Int {
        let total = myAssignedTasks.count
        guard total > 0 else { return 0 }
        return Int((Double(myCompletedTasks.count) / Double(total)) * 100)
    }

    private var mvpCategory: String {
        let cats = myCompletedTasks
            .map { $0.category.lowercased() }
            .filter { !["statusping", "reminders"].contains($0) }
        var counts: [String: Int] = [:]
        for c in cats { counts[c, default: 0] += 1 }
        guard let winner = counts.max(by: { $0.value < $1.value })?.key else { return "—" }
        return winner.capitalized
    }

    private var cal: Calendar { Calendar.current }
    private var currentYear: Int { cal.component(.year, from: Date()) }

    private var thisYearCompleted: [TaskItem] {
        myCompletedTasks.filter {
            guard let d = $0.completedAt else { return false }
            return cal.component(.year, from: d) == currentYear
        }
    }

    private var pointsThisYear: Int {
        thisYearCompleted.reduce(0) { $0 + Int($1.points) }
    }

    private var goalsRedeemedThisYear: Int {
        let name = myName.lowercased()
        return allGoals.filter {
            $0.isRedeemed &&
            $0.redeemedAt != nil &&
            GoalApproval.realOwnerName($0).lowercased() == name &&
            cal.component(.year, from: $0.redeemedAt!) == currentYear
        }.count
    }

    private var dayOfYear: Int { cal.ordinality(of: .day, in: .year, for: Date()) ?? 1 }
    private var daysInYear: Int { cal.range(of: .day, in: .year, for: Date())?.count ?? 365 }

    private var projectedCompletions: Int {
        guard dayOfYear > 0 else { return 0 }
        return Int((Double(thisYearCompleted.count) / Double(dayOfYear)) * Double(daysInYear))
    }

    private var projectedPoints: Int {
        guard dayOfYear > 0 else { return 0 }
        return Int((Double(pointsThisYear) / Double(dayOfYear)) * Double(daysInYear))
    }

    // ── Body ──────────────────────────────────────────────────────────────────

    var body: some View {
        ZStack(alignment: .top) {
            Color(rgb: 0x080808).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.top, 56)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        heroHeader
                        statsAwardsCard
                        splitsCard
                        tierProgressCard
                        projectionsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 48)
                }
            }
        }
        .sheet(isPresented: $showEditPhoto) { ProfilePhotoSheet() }
        .sheet(isPresented: $showShareSheet) {
            if let img = shareImage { ShareSheet(items: [img]) }
        }
        .swipeToDismiss()
    }

    // ── Top bar ───────────────────────────────────────────────────────────────

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            Button { renderAndShare() } label: {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    // ── Profile header (compact — no hero photo background) ──────────────────

    private var heroHeader: some View {
        HStack(spacing: 14) {
            // photo circle with pencil badge
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 66, height: 66)
                    if let data = me?.photoBlob, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable().scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1.5))

                Button { showEditPhoto = true } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.black.opacity(0.7)))
                        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                }
                .offset(x: 2, y: 2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(myName)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(.white)
                HStack(spacing: 5) {
                    if let emblem = myRankLevel.emblem {
                        Text(emblem).font(.system(size: 11))
                    }
                    Text(myRankLabel.uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(myRankLevel == .rookie
                            ? .white.opacity(0.5)
                            : myRankLevel.ringColor)
                }
                Text("MEMBER SINCE")
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 2)
                Text(memberSince)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(rgb: 0x1C1C1E)))
    }

    // ── SWEPT THE CHORES card ───────────────────────────────────────────────────

    private var statsAwardsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SWEPT THE CHORES")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(.white)

            HStack(spacing: 0) {
                awardCol(
                    icon: "checkmark.circle.fill",
                    color: P.sky,
                    value: "\(myCompletedTasks.count)",
                    line1: "ALL TIME",
                    line2: "TASKS DONE"
                )
                awardCol(
                    icon: "sparkles",
                    color: P.mint,
                    value: "\(completedChores)",
                    line1: "ALL TIME",
                    line2: "CHORES DONE"
                )
                awardCol(
                    icon: "chart.bar.fill",
                    color: P.butter,
                    value: "\(avgRate)%",
                    line1: "AVG",
                    line2: "\(myCompletedTasks.count) OF \(myAssignedTasks.count)"
                )
                awardCol(
                    icon: "trophy.fill",
                    color: P.lavender,
                    value: mvpCategory,
                    line1: "MVP",
                    line2: "CATEGORY",
                    smallValue: true
                )
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(rgb: 0x1C1C1E)))
    }

    private func awardCol(
        icon: String,
        color: Color,
        value: String,
        line1: String,
        line2: String,
        smallValue: Bool = false
    ) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(smallValue ? 0.5 : 1.0)
                .multilineTextAlignment(.center)

            VStack(spacing: 1) {
                Text(line1)
                    .font(.system(size: 7.5, weight: .heavy))
                    .tracking(0.4)
                    .foregroundStyle(.white.opacity(0.45))
                Text(line2)
                    .font(.system(size: 7.5, weight: .heavy))
                    .tracking(0.4)
                    .foregroundStyle(.white.opacity(0.45))
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // ── Splits card ───────────────────────────────────────────────────────────

    private var splitsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("CHORES & SCORES")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.5)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(String(currentYear)) · YOUR YEAR IN TASKS")
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.35))
            }

            Text(String(currentYear))
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(.white)

            HStack(spacing: 0) {
                splitCol(value: "\(thisYearCompleted.count)", label: "TASKS\nDONE")
                splitCol(value: "\(me?.points ?? 0)", label: "CURRENT\nPOINTS")
                splitCol(value: "\(goalsRedeemedThisYear)", label: "GOALS\nREDEEMED")
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(rgb: 0x1C1C1E)))
    }

    private func splitCol(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 7.5, weight: .heavy))
                .tracking(0.4)
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // ── Tier progress card ────────────────────────────────────────────────────

    private var tierProgressCard: some View {
        let pts = Int(me?.points ?? 0)
        let sorted = gameRules.rules.rewardTiers.sorted { $0.minPoints < $1.minPoints }
        let unlockedTier = sorted.last(where: { pts >= $0.minPoints })
        let nextTier = sorted.first(where: { pts < $0.minPoints })

        return VStack(alignment: .leading, spacing: 10) {
            Text("REWARD TIER")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(.white)

            HStack(alignment: .center, spacing: 10) {
                if let tier = unlockedTier {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tier.emoji + " " + tier.name)
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.white)
                        Text("UNLOCKED")
                            .font(.system(size: 8, weight: .heavy))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                } else {
                    Text("No tier yet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
                Text("\(pts) pts")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.7))
            }

            GeometryReader { geo in
                let progress: CGFloat = {
                    if let next = nextTier {
                        let base = unlockedTier?.minPoints ?? 0
                        let raw = CGFloat(pts - base) / CGFloat(next.minPoints - base)
                        return min(max(raw, 0), 1)
                    }
                    return 1.0
                }()
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(0.1))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(nextTier != nil ? Color(rgb: 0x7B5EA7) : Color.green)
                            .frame(width: geo.size.width * progress)
                    }
            }
            .frame(height: 8)

            if let next = nextTier {
                Text("\(next.minPoints - pts) pts to \(next.emoji) \(next.name)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            } else {
                Text("Max tier reached! 🏆")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.green)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(rgb: 0x1C1C1E)))
    }

    // ── Projections card ──────────────────────────────────────────────────────

    private var projectionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("KEEPING UP THE PACE")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.5)
                    .foregroundStyle(.white)
                Spacer()
                Text("YEAR END FORECAST")
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.35))
            }

            Text(String(currentYear))
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(.white)

            HStack(spacing: 0) {
                projCol(value: "\(projectedCompletions)", label: "TASKS", color: P.coral)
                projCol(value: "\(projectedPoints)", label: "POINTS", color: P.mint)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(rgb: 0x1C1C1E)))
    }

    private func projCol(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(.system(size: 7.5, weight: .heavy))
                .tracking(0.4)
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }

    // ── Share / render ────────────────────────────────────────────────────────

    private func renderAndShare() {
        let photo: UIImage? = {
            guard let data = me?.photoBlob else { return nil }
            return UIImage(data: data)
        }()
        let snapshot = CardSnapshotView(
            name: myName,
            memberSince: memberSince,
            photo: photo,
            tasksCompleted: myCompletedTasks.count,
            choresDone: completedChores,
            avgRate: avgRate,
            assignedCount: myAssignedTasks.count,
            mvpCategory: mvpCategory,
            currentYear: currentYear,
            thisYearTasks: thisYearCompleted.count,
            thisYearPoints: pointsThisYear,
            goalsRedeemed: goalsRedeemedThisYear,
            projectedTasks: projectedCompletions,
            projectedPoints: projectedPoints,
            palette: P
        )
        // ImageRenderer must run on the main actor. Capture image synchronously
        // here (we're already on main), then show the preview sheet.
        let renderer = ImageRenderer(content: snapshot.frame(width: 390, height: 780))
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = ProposedViewSize(width: 390, height: 780)
        if let img = renderer.uiImage {
            shareImage = img
            showShareSheet = true
        }
    }
}

// ── Snapshot view (pure data — no Core Data, safe for ImageRenderer) ──────────

private struct CardSnapshotView: View {
    let name: String
    let memberSince: String
    let photo: UIImage?
    let tasksCompleted: Int
    let choresDone: Int
    let avgRate: Int
    let assignedCount: Int
    let mvpCategory: String
    let currentYear: Int
    let thisYearTasks: Int
    let thisYearPoints: Int
    let goalsRedeemed: Int
    let projectedTasks: Int
    let projectedPoints: Int
    let palette: CasalistCottage.Palette

    var body: some View {
        ZStack(alignment: .top) {
            Color(rgb: 0x080808)

            VStack(spacing: 10) {
                // hero header
                ZStack(alignment: .bottomLeading) {
                    Group {
                        if let photo {
                            Image(uiImage: photo)
                                .resizable().scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .clipped()
                        } else {
                            LinearGradient(
                                colors: [palette.peach.opacity(0.9), palette.coral, Color(rgb: 0x12202E)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                            .frame(height: 200)
                        }
                    }

                    LinearGradient(
                        colors: [Color.black.opacity(0), Color.black.opacity(0.72)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 200)

                    HStack(alignment: .bottom, spacing: 14) {
                        ZStack {
                            Circle().fill(Color.white.opacity(0.15)).frame(width: 76, height: 76)
                            if let photo {
                                Image(uiImage: photo)
                                    .resizable().scaledToFill()
                                    .frame(width: 74, height: 74).clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 40)).foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(name)
                                .font(.system(size: 30, weight: .heavy)).foregroundStyle(.white)
                            Text("MEMBER SINCE")
                                .font(.system(size: 8, weight: .heavy)).tracking(1.4)
                                .foregroundStyle(.white.opacity(0.55))
                            Text(memberSince)
                                .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 18).padding(.bottom, 18)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                // SWEPT THE CHORES
                VStack(alignment: .leading, spacing: 14) {
                    Text("SWEPT THE CHORES")
                        .font(.system(size: 12, weight: .heavy)).foregroundStyle(.white)
                    HStack(spacing: 0) {
                        snapAwardCol(icon: "checkmark.circle.fill", color: palette.sky,
                                     value: "\(tasksCompleted)", line1: "ALL TIME", line2: "TASKS DONE")
                        snapAwardCol(icon: "sparkles", color: palette.mint,
                                     value: "\(choresDone)", line1: "ALL TIME", line2: "CHORES DONE")
                        snapAwardCol(icon: "chart.bar.fill", color: palette.butter,
                                     value: "\(avgRate)%", line1: "AVG",
                                     line2: "\(tasksCompleted) OF \(assignedCount)")
                        snapAwardCol(icon: "trophy.fill", color: palette.lavender,
                                     value: mvpCategory, line1: "MVP", line2: "CATEGORY", smallValue: true)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color(rgb: 0x1C1C1E)))

                // SPLITS
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("CHORES & SCORES").font(.system(size: 12, weight: .heavy)).foregroundStyle(.white)
                        Spacer()
                        Text("\(currentYear) · YOUR YEAR IN TASKS")
                            .font(.system(size: 8, weight: .heavy)).tracking(0.7)
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    Text(String(currentYear))
                        .font(.system(size: 22, weight: .heavy)).foregroundStyle(.white)
                    HStack(spacing: 0) {
                        snapSplitCol(value: "\(thisYearTasks)", label: "TASKS\nDONE")
                        snapSplitCol(value: "\(thisYearPoints)", label: "POINTS\nEARNED")
                        snapSplitCol(value: "\(goalsRedeemed)", label: "GOALS\nREDEEMED")
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color(rgb: 0x1C1C1E)))

                // PROJECTIONS
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("KEEPING UP THE PACE").font(.system(size: 12, weight: .heavy)).foregroundStyle(.white)
                        Spacer()
                        Text("YEAR END FORECAST")
                            .font(.system(size: 8, weight: .heavy)).tracking(0.7)
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    Text(String(currentYear))
                        .font(.system(size: 22, weight: .heavy)).foregroundStyle(.white)
                    HStack(spacing: 0) {
                        snapProjCol(value: "\(projectedTasks)", label: "TASKS", color: palette.coral)
                        snapProjCol(value: "\(projectedPoints)", label: "POINTS", color: palette.mint)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color(rgb: 0x1C1C1E)))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private func snapAwardCol(icon: String, color: Color, value: String,
                               line1: String, line2: String, smallValue: Bool = false) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 22, weight: .semibold)).foregroundStyle(color)
            Text(value)
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(.white).lineLimit(1)
                .minimumScaleFactor(smallValue ? 0.5 : 1.0)
                .multilineTextAlignment(.center)
            VStack(spacing: 1) {
                Text(line1).font(.system(size: 7, weight: .heavy)).tracking(0.5).foregroundStyle(.white.opacity(0.45))
                Text(line2).font(.system(size: 7, weight: .heavy)).tracking(0.5).foregroundStyle(.white.opacity(0.45))
            }.multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity)
    }

    private func snapSplitCol(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 24, weight: .heavy)).foregroundStyle(.white)
            Text(label).font(.system(size: 7, weight: .heavy)).tracking(0.5)
                .foregroundStyle(.white.opacity(0.45)).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity)
    }

    private func snapProjCol(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 30, weight: .heavy)).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.5)
            Text(label).font(.system(size: 8, weight: .heavy)).tracking(0.5)
                .foregroundStyle(.white.opacity(0.45))
        }.frame(maxWidth: .infinity)
    }
}

// ── Share preview sheet ───────────────────────────────────────────────────────

private struct SharePreviewSheet: View {
    let image: UIImage
    let onShare: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(rgb: 0x080808).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
                            .padding(.horizontal, 16)

                        Button(action: onShare) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 15, weight: .heavy))
                                Text("Share")
                                    .font(.system(size: 16, weight: .heavy))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Capsule().fill(Color(rgb: 0xF4845F)))
                            .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Your Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
}

// ── UIActivityViewController wrapper ─────────────────────────────────────────

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
