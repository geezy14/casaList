import SwiftUI
import CoreData

/// Admin-only household overview — the "Big Board". Surfaced in the
/// Reminders slot for admins. Two stacked sections:
///   • Calendar — where everyone is TODAY and THIS WEEK (family events,
///     with attendee avatars), so a parent can see the whole schedule.
///   • Chores — per-member completion (done / assigned + a progress bar),
///     so a parent can see who's on track and who's behind.
///
/// Read-only at-a-glance board; editing still happens in the dedicated
/// screens. Non-admins never see this (the Dashboard only routes admins here).
struct HouseholdBoardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var sys
    @Environment(\.managedObjectContext) private var moc
    var onHome: (() -> Void)? = nil

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)],
                  predicate: NSPredicate(format: "deletedAt == nil"))
    private var members: FetchedResults<FamilyMember>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyEvent.startDate, ascending: true)],
                  predicate: NSPredicate(format: "deletedAt == nil"))
    private var events: FetchedResults<FamilyEvent>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.dueDate, ascending: true)],
                  predicate: NSPredicate(format: "deletedAt == nil"))
    private var tasks: FetchedResults<TaskItem>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyGoal.createdAt, ascending: false)],
                  predicate: NSPredicate(format: "deletedAt == nil"))
    private var goals: FetchedResults<FamilyGoal>

    /// UID of the member whose chore list is currently expanded inline in
    /// the CHORES section. nil = all rows collapsed.
    @State private var expandedMemberUID: UUID? = nil

    private var P: CasalistCottage.Palette { CasalistCottage.Palette.resolve(sys == .dark) }
    private let cal = Calendar.current

    // MARK: - Date windows

    private var todayStart: Date { cal.startOfDay(for: Date()) }
    private var weekStart: Date {
        cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? todayStart
    }
    private var weekEnd: Date { cal.date(byAdding: .day, value: 7, to: weekStart) ?? Date() }

    /// Does a (possibly recurring) event land on the given day?
    private func event(_ e: FamilyEvent, occursOn day: Date) -> Bool {
        let start = cal.startOfDay(for: e.startDate)
        let target = cal.startOfDay(for: day)
        if cal.isDate(start, inSameDayAs: target) { return true }
        guard target > start else { return false }
        switch e.repeatKind.lowercased() {
        case "daily": return true
        case "weekly": return cal.component(.weekday, from: start) == cal.component(.weekday, from: target)
        case "weekdays":
            let wd = cal.component(.weekday, from: target)
            return wd >= 2 && wd <= 6
        case "monthly": return cal.component(.day, from: start) == cal.component(.day, from: target)
        case "yearly":
            return cal.component(.day, from: start) == cal.component(.day, from: target)
                && cal.component(.month, from: start) == cal.component(.month, from: target)
        default: return false   // custom rules: show on start day only for now
        }
    }

    private func events(on day: Date) -> [FamilyEvent] {
        events.filter { event($0, occursOn: day) }
            .sorted { $0.startDate < $1.startDate }
    }

    /// The next 7 days (today through +6) that actually have events.
    private var weekDaysWithEvents: [(day: Date, events: [FamilyEvent])] {
        (0..<7).compactMap { offset -> (Date, [FamilyEvent])? in
            guard let day = cal.date(byAdding: .day, value: offset, to: todayStart) else { return nil }
            let evs = events(on: day)
            return evs.isEmpty ? nil : (day, evs)
        }
    }

    // MARK: - Chore stats

    private let choreCategories: Set<String> = ["chores", "home", "maintenance"]

    private func choreStats(for m: FamilyMember) -> (assigned: Int, done: Int) {
        let mine = chores(for: m)
        return (mine.count, mine.filter(\.isCompleted).count)
    }

    /// Every chore-category task assigned to this member, open chores first
    /// then completed, each group sorted by due date (then created).
    private func chores(for m: FamilyMember) -> [TaskItem] {
        tasks
            .filter { t in
                guard choreCategories.contains(t.category.lowercased()) else { return false }
                return (t.assignee ?? "").lowercased() == m.name.lowercased()
            }
            .sorted { a, b in
                if a.isCompleted != b.isCompleted { return !a.isCompleted }
                let da = a.dueDate ?? .distantFuture
                let db = b.dueDate ?? .distantFuture
                if da != db { return da < db }
                return a.createdAt < b.createdAt
            }
    }

    private func isChore(_ t: TaskItem) -> Bool { choreCategories.contains(t.category.lowercased()) }

    // MARK: - Summary stats

    /// Chores due today across the household (done / total).
    private var choresToday: (done: Int, total: Int) {
        let due = tasks.filter { t in
            guard isChore(t), let d = t.dueDate else { return false }
            return cal.isDateInToday(d)
        }
        return (due.filter(\.isCompleted).count, due.count)
    }

    /// Non-recurring chores past their due date, still open, with an assignee.
    private var overdueChores: [TaskItem] {
        tasks.filter { t in
            guard isChore(t), !t.isCompleted, t.repeatKind.isEmpty,
                  let d = t.dueDate, !(t.assignee ?? "").isEmpty else { return false }
            return d < todayStart
        }
        .sorted { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) }
    }

    private var pendingApprovals: Int {
        goals.filter { GoalApproval.isPending($0) && !$0.isRedeemed }.count
    }

    /// Points earned across the household from chores completed this week.
    private var pointsThisWeek: Int {
        tasks.reduce(0) { sum, t in
            guard t.isCompleted, let c = t.completedAt, c >= weekStart, c < weekEnd else { return sum }
            return sum + Int(t.points) + Int(t.bonusPoints)
        }
    }

    /// All live reminders — the household's only browse spot now that the
    /// Reminders screen is gone. Open ones first, soonest fire date first.
    private var reminders: [TaskItem] {
        tasks.filter { $0.category.lowercased() == "reminders" && !$0.isCompleted }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    private func notifyLabel(for t: TaskItem) -> String {
        switch t.notifyMode.lowercased() {
        case "admins": return "Admins"
        case "everyone": return "Everyone"
        default:
            let a = (t.assignee ?? "").trimmingCharacters(in: .whitespaces)
            return a.isEmpty ? "Everyone" : a
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                P.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        summaryBand
                        todaySection
                        overdueSection
                        weekSection
                        remindersSection
                        choresSection
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    try? await Task.sleep(for: .seconds(1))
                    moc.refreshAllObjects()
                }
            }
            .navigationTitle("Household")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { if let onHome { onHome() } else { dismiss() } }
                }
            }
            .swipeBack { if let onHome { onHome() } else { dismiss() } }
        }
    }

    // MARK: - Sections

    private func sectionHeader(_ title: String, _ tint: Color) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .heavy)).tracking(1.2)
            .foregroundStyle(tint)
    }

    private var summaryBand: some View {
        let ct = choresToday
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            statChip(value: "\(ct.done)/\(ct.total)", label: "Chores today", tint: P.mint)
            statChip(value: "\(overdueChores.count)", label: "Overdue", tint: overdueChores.isEmpty ? P.mint : P.coral)
            statChip(value: "\(pendingApprovals)", label: "Approvals", tint: pendingApprovals > 0 ? P.peach : P.mint)
            statChip(value: "\(pointsThisWeek)", label: "Points this week", tint: P.lavender)
        }
    }

    private func statChip(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.system(size: 22, weight: .heavy)).foregroundStyle(tint).monospacedDigit()
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(P.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(P.border, lineWidth: 1))
    }

    private var overdueSection: some View {
        Group {
            if !overdueChores.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("OVERDUE CHORES", P.coral)
                    VStack(spacing: 8) {
                        ForEach(overdueChores, id: \.uid) { overdueRow($0) }
                    }
                }
            }
        }
    }

    private func overdueRow(_ t: TaskItem) -> some View {
        let daysLate = cal.dateComponents([.day], from: cal.startOfDay(for: t.dueDate ?? Date()), to: todayStart).day ?? 0
        return HStack(spacing: 12) {
            Text("⚠️").font(.system(size: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text(t.task).font(.system(size: 14, weight: .heavy)).lineLimit(1)
                Text(t.assignee ?? "Unassigned")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textMuted)
            }
            Spacer(minLength: 0)
            Text(daysLate <= 0 ? "Today" : "\(daysLate)d late")
                .font(.system(size: 11, weight: .heavy)).foregroundStyle(P.coral).monospacedDigit()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(P.coral.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(P.coral.opacity(0.3), lineWidth: 1))
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("TODAY", P.peach)
            let evs = events(on: todayStart)
            if evs.isEmpty {
                emptyCard("Nothing on the calendar today.")
            } else {
                VStack(spacing: 8) {
                    ForEach(evs, id: \.uid) { eventRow($0) }
                }
            }
        }
    }

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("THIS WEEK", P.mint)
            let upcoming = weekDaysWithEvents.filter { !cal.isDateInToday($0.day) }
            if upcoming.isEmpty {
                emptyCard("Nothing else scheduled this week.")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(upcoming, id: \.day) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(dayLabel(entry.day))
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(P.textDim)
                            VStack(spacing: 8) {
                                ForEach(entry.events, id: \.uid) { eventRow($0) }
                            }
                        }
                    }
                }
            }
        }
    }

    private var remindersSection: some View {
        Group {
            if !reminders.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("REMINDERS", P.lavender)
                    VStack(spacing: 8) {
                        ForEach(reminders, id: \.uid) { reminderRow($0) }
                    }
                }
            }
        }
    }

    private func reminderRow(_ t: TaskItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: t.dueDate == nil ? "pin.fill" : "bell.fill")
                .font(.system(size: 14)).foregroundStyle(P.lavender).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.task).font(.system(size: 14, weight: .heavy)).lineLimit(1)
                Text("Notifies \(notifyLabel(for: t))")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textMuted)
            }
            Spacer(minLength: 0)
            if let d = t.dueDate {
                Text(reminderWhen(d))
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(P.textDim).monospacedDigit()
            } else {
                Text("Pinned").font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textMuted)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(P.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(P.border, lineWidth: 1))
    }

    private func reminderWhen(_ d: Date) -> String {
        let f = DateFormatter()
        if cal.isDateInToday(d) { f.dateFormat = "h:mm a"; return "Today \(f.string(from: d))" }
        if cal.isDateInTomorrow(d) { f.dateFormat = "h:mm a"; return "Tmrw \(f.string(from: d))" }
        f.dateFormat = "MMM d"
        return f.string(from: d)
    }

    private var choresSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("CHORES", P.coral)
            VStack(spacing: 10) {
                ForEach(members, id: \.uid) { m in
                    memberChoreCard(m)
                }
                if members.isEmpty {
                    emptyCard("No family members yet.")
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18).fill(P.surface))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(P.border, lineWidth: 1))
        }
    }

    /// A single member card in the CHORES section. Always renders both the
    /// summary row (avatar/name/progress) AND the full list of that
    /// member's chores with per-chore done/open status — admin gets the
    /// "who has what, and what's done" view at a glance, no tapping.
    private func memberChoreCard(_ m: FamilyMember) -> some View {
        let mine = chores(for: m)
        let assigned = mine.count
        let done = mine.filter(\.isCompleted).count
        let rate = assigned > 0 ? Double(done) / Double(assigned) : 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                CLAvatar(m.asCLMember, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(m.name)
                        .font(.system(size: 14, weight: .heavy))
                        .lineLimit(1)
                    let streak = StreakTracker.effectiveCurrent(for: m.uid)
                    if streak > 0 {
                        Text("🔥\(streak)")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(P.peach)
                    }
                }
                .frame(width: 90, alignment: .leading)
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
                        .font(.system(size: 13, weight: .heavy)).monospacedDigit()
                        .foregroundStyle(P.textDim)
                    Text(assigned == 0 ? "—" : "\(Int((rate * 100).rounded()))%")
                        .font(.system(size: 10, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(rate >= 1.0 ? P.mint : P.textMuted)
                }
                .frame(width: 52, alignment: .trailing)
            }

            if mine.isEmpty {
                Text("No chores assigned.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(P.textMuted)
                    .padding(.leading, 40).padding(.bottom, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(mine, id: \.uid) { t in
                        choreLine(t)
                        if t != mine.last {
                            Rectangle().fill(P.border).frame(height: 1)
                                .padding(.leading, 40)
                        }
                    }
                }
                .padding(.leading, 4)
                .background(RoundedRectangle(cornerRadius: 12).fill(P.surfaceAlt.opacity(0.35)))
            }
        }
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) {
            if m != members.last {
                Rectangle().fill(P.border).frame(height: 1)
                    .padding(.top, 8)
            }
        }
    }

    /// One chore line under an expanded member row: status circle, title,
    /// due date subtitle, and a small overdue/done tag.
    private func choreLine(_ t: TaskItem) -> some View {
        let overdue: Bool = {
            guard !t.isCompleted, let d = t.dueDate else { return false }
            return d < Date()
        }()
        return HStack(spacing: 10) {
            Image(systemName: t.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 15))
                .foregroundStyle(t.isCompleted ? P.mint : (overdue ? P.coral : P.textMuted))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(t.task)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(t.isCompleted ? P.textMuted : P.text)
                    .strikethrough(t.isCompleted)
                    .lineLimit(1)
                if let d = t.dueDate {
                    Text(dueLabel(d))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(overdue ? P.coral : P.textMuted)
                }
            }
            Spacer(minLength: 0)
            if t.points > 0 {
                Text("\(t.points) pt\(t.points == 1 ? "" : "s")")
                    .font(.system(size: 10, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(P.textMuted)
            }
        }
        .padding(.vertical, 8)
    }

    /// Compact human label for a chore's due date — "Today", "Overdue",
    /// "Tomorrow", or a short date.
    private func dueLabel(_ d: Date) -> String {
        if cal.isDateInToday(d) { return "Today" }
        if cal.isDateInTomorrow(d) { return "Tomorrow" }
        if d < cal.startOfDay(for: Date()) {
            let f = DateFormatter(); f.dateFormat = "MMM d"
            return "Overdue \(f.string(from: d))"
        }
        let f = DateFormatter(); f.dateFormat = "EEE MMM d"
        return f.string(from: d)
    }

    // MARK: - Rows

    private func eventRow(_ e: FamilyEvent) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 1) {
                if e.isAllDay {
                    Text("All").font(.system(size: 11, weight: .heavy))
                    Text("day").font(.system(size: 9, weight: .semibold)).foregroundStyle(P.textMuted)
                } else {
                    Text(timeString(e.startDate)).font(.system(size: 12, weight: .heavy)).monospacedDigit()
                }
            }
            .frame(width: 52)
            Rectangle().fill(P.border).frame(width: 1, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.title).font(.system(size: 14, weight: .heavy)).lineLimit(1)
                let who = e.attendees.trimmingCharacters(in: .whitespaces)
                Text(who.isEmpty ? "Family-wide" : who)
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if !e.location.isEmpty {
                Image(systemName: "mappin.circle.fill").font(.system(size: 13)).foregroundStyle(P.textMuted)
            }
            if !e.repeatKind.isEmpty {
                Image(systemName: "repeat").font(.system(size: 11)).foregroundStyle(P.textMuted)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(P.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(P.border, lineWidth: 1))
    }

    private func emptyCard(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(P.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16).padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(P.surface.opacity(0.5)))
    }

    // MARK: - Formatting

    private func timeString(_ d: Date) -> String {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none
        return f.string(from: d)
    }
    private func dayLabel(_ d: Date) -> String {
        if cal.isDateInTomorrow(d) { return "Tomorrow" }
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"
        return f.string(from: d)
    }
}
