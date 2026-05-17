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
        return f.string(from: d).uppercased()
    }

    // ── Stat computations ─────────────────────────────────────────────────────

    private var myCompletedTasks: [TaskItem] {
        let name = myName.lowercased()
        return allTodos.filter {
            $0.completedAt != nil &&
            (($0.assignee ?? "").lowercased() == name || $0.createdBy.lowercased() == name)
        }
    }

    private var myAssignedTasks: [TaskItem] {
        let name = myName.lowercased()
        return allTodos.filter {
            ($0.assignee ?? "").lowercased() == name || $0.createdBy.lowercased() == name
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

    // Year splits
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

    // Projections
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
            heroBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.top, 56)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        photoAndName
                        heroStatRow
                        splitsCard
                        projectionsCard
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showEditPhoto) { ProfilePhotoSheet() }
        .sheet(isPresented: $showShareSheet) {
            if let img = shareImage {
                ShareSheet(items: [img])
            }
        }
    }

    // ── Top bar ───────────────────────────────────────────────────────────────

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer()
            Button { renderAndShare() } label: {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

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
            choреsDone: completedChores,
            avgRate: avgRate,
            mvpCategory: mvpCategory,
            currentYear: currentYear,
            thisYearTasks: thisYearCompleted.count,
            thisYearPoints: pointsThisYear,
            goalsRedeemed: goalsRedeemedThisYear,
            projectedTasks: projectedCompletions,
            projectedPoints: projectedPoints,
            palette: P
        )
        let renderer = ImageRenderer(content: snapshot.frame(width: 390, height: 760))
        renderer.scale = 3
        if let img = renderer.uiImage {
            shareImage = img
            showShareSheet = true
        }
    }

    // ── Hero background ───────────────────────────────────────────────────────

    @ViewBuilder
    private var heroBackground: some View {
        if let data = me?.photoBlob, let ui = UIImage(data: data) {
            GeometryReader { geo in
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .blur(radius: 28)
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.5), Color.black.opacity(0.82)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }
        } else {
            LinearGradient(
                colors: [P.peach.opacity(0.9), P.coral, Color(rgb: 0x12202E)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    // ── Photo + name header ───────────────────────────────────────────────────

    private var photoAndName: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 100, height: 100)
                    if let data = me?.photoBlob, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable().scaledToFill()
                            .frame(width: 98, height: 98)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 2.5))
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)

                Button { showEditPhoto = true } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.black.opacity(0.55)))
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                }
                .offset(x: 4, y: 4)
            }
            .padding(.top, 8)

            Text(myName.uppercased())
                .font(.system(size: 30, weight: .heavy))
                .tracking(2.5)
                .foregroundStyle(.white)

            Text("MEMBER SINCE \(memberSince)")
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // ── STATS & AWARDS card ───────────────────────────────────────────────────

    private var heroStatRow: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("STATS & AWARDS")
                .font(.system(size: 12, weight: .heavy))
                .tracking(1.8)
                .foregroundStyle(.white)

            HStack(spacing: 0) {
                awardsCol(
                    icon: "checkmark",
                    circleColor: P.sky,
                    value: "\(myCompletedTasks.count)",
                    line1: "ALL TIME",
                    line2: "TASKS DONE"
                )
                awardsCol(
                    icon: "sparkles",
                    circleColor: P.mint,
                    value: "\(completedChores)",
                    line1: "ALL TIME",
                    line2: "CHORES DONE"
                )
                awardsCol(
                    icon: "chart.bar.fill",
                    circleColor: P.butter,
                    value: "\(avgRate)%",
                    line1: "AVG",
                    line2: "COMPLETION"
                )
                awardsCol(
                    icon: "trophy.fill",
                    circleColor: P.coral,
                    value: mvpCategory,
                    line1: "MVP",
                    line2: "CATEGORY",
                    smallValue: true
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 18)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.white.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.18), lineWidth: 1))
    }

    private func awardsCol(
        icon: String,
        circleColor: Color,
        value: String,
        line1: String,
        line2: String,
        smallValue: Bool = false
    ) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(circleColor)
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text(value)
                .font(.system(size: smallValue ? 14 : 22, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            VStack(spacing: 1) {
                Text(line1)
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.45))
                Text(line2)
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.45))
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // ── Splits card ───────────────────────────────────────────────────────────

    private var splitsCard: some View {
        sectionCard(title: "\(currentYear) SPLITS") {
            statRow(label: "Tasks completed", value: "\(thisYearCompleted.count)")
            divider
            statRow(label: "Points earned", value: "\(pointsThisYear) pts")
            divider
            statRow(label: "Goals redeemed", value: "\(goalsRedeemedThisYear)")
        }
    }

    // ── Projections card ──────────────────────────────────────────────────────

    private var projectionsCard: some View {
        sectionCard(title: "YEAR-END PROJECTIONS") {
            statRow(label: "Tasks at current pace", value: "\(projectedCompletions)")
            divider
            statRow(label: "Points at current pace", value: "\(projectedPoints) pts")
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 12)
            content()
                .padding(.bottom, 8)
        }
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.white.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.18), lineWidth: 1))
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(height: 1)
            .padding(.horizontal, 18)
    }
}

// ── Snapshot view (pure data — no Core Data, safe for ImageRenderer) ──────────

private struct CardSnapshotView: View {
    let name: String
    let memberSince: String
    let photo: UIImage?
    let tasksCompleted: Int
    let choреsDone: Int
    let avgRate: Int
    let mvpCategory: String
    let currentYear: Int
    let thisYearTasks: Int
    let thisYearPoints: Int
    let goalsRedeemed: Int
    let projectedTasks: Int
    let projectedPoints: Int
    let palette: CasalistCottage.Palette

    var body: some View {
        ZStack {
            // Background
            if let photo {
                Image(uiImage: photo)
                    .resizable().scaledToFill()
                    .blur(radius: 28)
                    .overlay(LinearGradient(
                        colors: [Color.black.opacity(0.5), Color.black.opacity(0.82)],
                        startPoint: .top, endPoint: .bottom
                    ))
            } else {
                LinearGradient(
                    colors: [palette.peach.opacity(0.9), palette.coral, Color(rgb: 0x12202E)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }

            VStack(spacing: 16) {
                // Photo + name
                VStack(spacing: 8) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.12)).frame(width: 88, height: 88)
                        if let photo {
                            Image(uiImage: photo)
                                .resizable().scaledToFill()
                                .frame(width: 86, height: 86).clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 46)).foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 2.5))
                    .padding(.top, 24)

                    Text(name.uppercased())
                        .font(.system(size: 26, weight: .heavy)).tracking(2.5).foregroundStyle(.white)
                    Text("MEMBER SINCE \(memberSince)")
                        .font(.system(size: 10, weight: .heavy)).tracking(1.4).foregroundStyle(.white.opacity(0.5))
                }

                // STATS & AWARDS
                VStack(alignment: .leading, spacing: 12) {
                    Text("STATS & AWARDS")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.8)
                        .foregroundStyle(.white)
                    HStack(spacing: 0) {
                        snapAwardsCol(icon: "checkmark", circleColor: palette.sky, value: "\(tasksCompleted)", line1: "ALL TIME", line2: "TASKS DONE")
                        snapAwardsCol(icon: "sparkles", circleColor: palette.mint, value: "\(choреsDone)", line1: "ALL TIME", line2: "CHORES DONE")
                        snapAwardsCol(icon: "chart.bar.fill", circleColor: palette.butter, value: "\(avgRate)%", line1: "AVG", line2: "COMPLETION")
                        snapAwardsCol(icon: "trophy.fill", circleColor: palette.coral, value: mvpCategory, line1: "MVP", line2: "CATEGORY", smallValue: true)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 16)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.1)))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.18), lineWidth: 1))
                .padding(.horizontal, 20)

                // Splits
                snapCard(title: "\(currentYear) SPLITS") {
                    snapRow("Tasks completed", "\(thisYearTasks)")
                    snapDivider
                    snapRow("Points earned", "\(thisYearPoints) pts")
                    snapDivider
                    snapRow("Goals redeemed", "\(goalsRedeemed)")
                }.padding(.horizontal, 20)

                // Projections
                snapCard(title: "YEAR-END PROJECTIONS") {
                    snapRow("Tasks at current pace", "\(projectedTasks)")
                    snapDivider
                    snapRow("Points at current pace", "\(projectedPoints) pts")
                }.padding(.horizontal, 20)

                Spacer(minLength: 0)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private func snapAwardsCol(icon: String, circleColor: Color, value: String, line1: String, line2: String, smallValue: Bool = false) -> some View {
        VStack(spacing: 7) {
            ZStack {
                Circle().fill(circleColor).frame(width: 42, height: 42)
                Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
            }
            Text(value)
                .font(.system(size: smallValue ? 12 : 20, weight: .heavy))
                .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.5)
            VStack(spacing: 1) {
                Text(line1).font(.system(size: 7, weight: .heavy)).tracking(0.5).foregroundStyle(.white.opacity(0.45))
                Text(line2).font(.system(size: 7, weight: .heavy)).tracking(0.5).foregroundStyle(.white.opacity(0.45))
            }.multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity)
    }

    private func snapCard<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .heavy)).tracking(1.5)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)
            content().padding(.bottom, 8)
        }
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.18), lineWidth: 1))
    }

    private func snapRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
            Spacer()
            Text(value).font(.system(size: 14, weight: .heavy)).foregroundStyle(.white)
        }.padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var snapDivider: some View {
        Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1).padding(.horizontal, 16)
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
