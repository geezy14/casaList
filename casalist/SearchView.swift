import SwiftUI
import CoreData

/// Universal search across the household. Surfaces tasks, reminders,
/// events, family members, and goals in grouped sections. Tap a result
/// to open the relevant editor.
///
/// Behavior:
///   • Empty query → empty state with a list of what's searchable
///   • Typing → live, in-memory filtering over already-fetched results
///     (cheap; no per-keystroke Core Data round-trip)
///   • Tap → opens the appropriate editor sheet (TaskDetail, AddReminder,
///     AddEvent, etc.)
///   • Searching for a person's name surfaces everything assigned to them
///     because we match on assignee / ownerName / attendees fields too
struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.colorScheme) private var sys
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("meUid") private var meUid: String = ""

    @State private var query: String = ""
    @State private var editingTask: TaskItem? = nil
    @State private var editingReminder: TaskItem? = nil
    @State private var editingEvent: FamilyEvent? = nil

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: false)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var tasks: FetchedResults<TaskItem>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var members: FetchedResults<FamilyMember>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyEvent.startDate, ascending: false)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var events: FetchedResults<FamilyEvent>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyGoal.createdAt, ascending: false)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var goals: FetchedResults<FamilyGoal>

    private var P: CasalistCottage.Palette { CasalistCottage.Palette.resolve(sys == .dark) }

    /// Trimmed, case-insensitive query. Returns nil when the search bar is empty.
    private var needle: String? {
        let t = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return t.isEmpty ? nil : t
    }

    /// Categories that mean "this is a reminder, not a task." Drives which
    /// editor opens when a result is tapped.
    private let reminderCategories: Set<String> = ["reminders"]

    // MARK: - Filtered results

    private var matchingChores: [TaskItem] {
        guard let n = needle else { return [] }
        return tasks.filter { t in
            guard !reminderCategories.contains(t.category.lowercased()) else { return false }
            return t.task.lowercased().contains(n)
                || t.category.lowercased().contains(n)
                || (t.assignee ?? "").lowercased().contains(n)
        }
    }

    private var matchingReminders: [TaskItem] {
        guard let n = needle else { return [] }
        return tasks.filter { t in
            guard reminderCategories.contains(t.category.lowercased()) else { return false }
            return t.task.lowercased().contains(n)
                || t.locationName.lowercased().contains(n)
                || (t.assignee ?? "").lowercased().contains(n)
        }
    }

    private var matchingEvents: [FamilyEvent] {
        guard let n = needle else { return [] }
        return events.filter { e in
            e.title.lowercased().contains(n)
                || e.location.lowercased().contains(n)
                || e.notes.lowercased().contains(n)
                || e.attendees.lowercased().contains(n)
        }
    }

    private var matchingMembers: [FamilyMember] {
        guard let n = needle else { return [] }
        return members.filter { $0.name.lowercased().contains(n) }
    }

    private var matchingGoals: [FamilyGoal] {
        guard let n = needle else { return [] }
        return goals.filter { g in
            g.label.lowercased().contains(n)
                || g.ownerName.lowercased().contains(n)
                || GoalLink.note(from: g.note).lowercased().contains(n)
        }
    }

    private var totalCount: Int {
        matchingChores.count
            + matchingReminders.count
            + matchingEvents.count
            + matchingMembers.count
            + matchingGoals.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                P.bg.ignoresSafeArea()
                VStack(spacing: 12) {
                    searchBar
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                    if needle == nil {
                        emptyState
                    } else if totalCount == 0 {
                        noResultsState
                    } else {
                        ScrollView {
                            VStack(spacing: 14) {
                                if !matchingMembers.isEmpty { membersSection }
                                if !matchingChores.isEmpty   { choresSection }
                                if !matchingReminders.isEmpty { remindersSection }
                                if !matchingEvents.isEmpty   { eventsSection }
                                if !matchingGoals.isEmpty    { goalsSection }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 28)
                        }
                        .scrollIndicators(.hidden)
                    }
                }
            }
            .foregroundStyle(P.text)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(item: $editingTask) { t in TaskDetailView(task: t) }
        .sheet(item: $editingReminder) { t in AddReminderView(editing: t) }
        .sheet(item: $editingEvent) { e in AddEventView(editing: e) }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(P.textDim)
            TextField("Search tasks, reminders, events, family…", text: $query)
                .font(.system(size: 14, weight: .semibold))
                .submitLabel(.search)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(P.textMuted)
                }.buttonStyle(.row)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Capsule().fill(P.surface))
        .overlay(Capsule().stroke(P.border, lineWidth: 1.5))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Searches everything")
                .font(.system(size: 14, weight: .heavy)).tracking(0.8)
                .foregroundStyle(P.textDim)
            VStack(alignment: .leading, spacing: 8) {
                hintRow(icon: "checkmark.circle.fill",     label: "Tasks · chores, home, maintenance")
                hintRow(icon: "pin.fill",                  label: "Reminders")
                hintRow(icon: "calendar",                  label: "Schedule events")
                hintRow(icon: "person.crop.circle.fill",   label: "Family members (taps surface their stuff)")
                hintRow(icon: "target",                    label: "Goals · in-flight + redeemed")
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hintRow(icon: String, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(P.textDim)
                .frame(width: 22)
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(P.textDim)
        }
    }

    private var noResultsState: some View {
        VStack(spacing: 8) {
            Text("🔍").font(.system(size: 40))
            Text("Nothing matches “\(query)”")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(P.text)
            Text("Try a different word or a person's name.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(P.textDim)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - Sections

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("FAMILY", count: matchingMembers.count, tint: P.lavender)
            VStack(spacing: 6) {
                ForEach(matchingMembers, id: \.uid) { m in
                    Button { tapMember(m) } label: { memberRow(m) }.buttonStyle(.row)
                }
            }
        }
    }

    private var choresSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("TASKS", count: matchingChores.count, tint: P.peach)
            VStack(spacing: 6) {
                ForEach(matchingChores, id: \.objectID) { t in
                    Button { editingTask = t } label: { taskRow(t) }.buttonStyle(.row)
                }
            }
        }
    }

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("REMINDERS", count: matchingReminders.count, tint: P.coral)
            VStack(spacing: 6) {
                ForEach(matchingReminders, id: \.objectID) { t in
                    Button { editingReminder = t } label: { taskRow(t, icon: "pin.fill") }.buttonStyle(.row)
                }
            }
        }
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("SCHEDULE", count: matchingEvents.count, tint: P.sky)
            VStack(spacing: 6) {
                ForEach(matchingEvents, id: \.objectID) { e in
                    Button { editingEvent = e } label: { eventRow(e) }.buttonStyle(.row)
                }
            }
        }
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("GOALS", count: matchingGoals.count, tint: P.mint)
            VStack(spacing: 6) {
                ForEach(matchingGoals, id: \.objectID) { g in
                    goalRow(g)
                }
            }
        }
    }

    // MARK: - Rows

    private func taskRow(_ t: TaskItem, icon: String = "checkmark.circle.fill") -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(t.isCompleted ? P.textMuted : P.text)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.task)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .strikethrough(t.isCompleted)
                    .foregroundStyle(t.isCompleted ? P.textDim : P.text)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(t.category.capitalized)
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted)
                    if let a = t.assignee, !a.isEmpty {
                        Text("·").foregroundStyle(P.textMuted)
                        Text(a).font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted)
                    }
                    if t.points > 0 {
                        Text("·").foregroundStyle(P.textMuted)
                        Text("\(t.points) pts").font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted)
                    }
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .heavy)).foregroundStyle(P.textMuted)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(P.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(P.border, lineWidth: 1))
    }

    private func eventRow(_ e: FamilyEvent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 14))
                .foregroundStyle(P.sky)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.title)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(P.text)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(e.startDate.formatted(date: .abbreviated, time: e.isAllDay ? .omitted : .shortened))
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted)
                    if !e.attendees.isEmpty {
                        Text("·").foregroundStyle(P.textMuted)
                        Text(e.attendees).font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted)
                    }
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.system(size: 10, weight: .heavy)).foregroundStyle(P.textMuted)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(P.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(P.border, lineWidth: 1))
    }

    private func memberRow(_ m: FamilyMember) -> some View {
        HStack(spacing: 12) {
            CLAvatar(m.asCLMember, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(m.name).font(.system(size: 14, weight: .heavy, design: .rounded))
                Text("\(m.points) pts · tap to filter")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted)
            }
            Spacer(minLength: 4)
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(P.textMuted)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14).fill(P.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(P.border, lineWidth: 1))
    }

    private func goalRow(_ g: FamilyGoal) -> some View {
        HStack(spacing: 12) {
            Image(systemName: g.isRedeemed ? "gift.fill" : "target")
                .font(.system(size: 14))
                .foregroundStyle(g.isRedeemed ? P.peach : P.mint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(g.label)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(P.text)
                    .lineLimit(1)
                Text("\(g.ownerName) · \(g.targetPoints) pts\(g.isRedeemed ? " · redeemed" : "")")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted)
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(P.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(P.border, lineWidth: 1))
    }

    // MARK: - Bits

    private func sectionHeader(_ s: String, count: Int, tint: Color) -> some View {
        HStack(spacing: 6) {
            Text(s).font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(tint)
            Text("\(count)")
                .font(.system(size: 10, weight: .heavy))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(tint.opacity(0.2)))
                .foregroundStyle(tint)
            Spacer()
        }
        .padding(.leading, 4)
    }

    /// Tap on a member → set the search box to their name so the
    /// other sections refilter to "everything for X". One-tap "show me
    /// Donovan's stuff".
    private func tapMember(_ m: FamilyMember) {
        query = m.name
    }
}
