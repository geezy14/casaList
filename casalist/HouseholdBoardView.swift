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
        let mine = tasks.filter { t in
            guard choreCategories.contains(t.category.lowercased()) else { return false }
            return (t.assignee ?? "").lowercased() == m.name.lowercased()
        }
        return (mine.count, mine.filter(\.isCompleted).count)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                P.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        todaySection
                        weekSection
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
        }
    }

    // MARK: - Sections

    private func sectionHeader(_ title: String, _ tint: Color) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .heavy)).tracking(1.2)
            .foregroundStyle(tint)
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

    private var choresSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("CHORES", P.coral)
            VStack(spacing: 12) {
                ForEach(members, id: \.uid) { m in
                    let (assigned, done) = choreStats(for: m)
                    let rate = assigned > 0 ? Double(done) / Double(assigned) : 0
                    HStack(spacing: 10) {
                        CLAvatar(m.asCLMember, size: 30)
                        Text(m.name)
                            .font(.system(size: 14, weight: .heavy))
                            .lineLimit(1)
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
