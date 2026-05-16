import SwiftUI
import CoreData

/// The "family wall" — a shared to-do where anyone in the household can drop
/// generic items (fix the faucet, pick up the cake, decide summer trip).
/// Items are TaskItems with category = "family" and assignee = nil.
/// Anyone can:
///   • Add a new item (everyone, including kids)
///   • Claim it → moves to their personal MyToDo (assignee = self)
///   • Mark it done directly from the list (no claim needed)
public struct FamilyListView: View {
    @Environment(\.colorScheme) private var sys
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("meUid") private var meUid: String = ""

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: false)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var allTasks: FetchedResults<TaskItem>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var members: FetchedResults<FamilyMember>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var households: FetchedResults<Household>

    @State private var darkOverride: Bool? = nil
    @State private var showAdd: Bool = false
    @State private var showSettings: Bool = false
    @State private var showInbox: Bool = false
    @State private var showStatusPing: Bool = false
    @State private var showFamilyMap: Bool = false
    @State private var celebrate: Bool = false
    @State private var celebrateLabel: String = ""
    @State private var newItem: String = ""
    @State private var newItemByTrip: [String: String] = [:]
    @State private var editingTask: TaskItem? = nil
    @State private var editingAnnouncement: TaskItem? = nil

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyGoal.createdAt, ascending: false)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var allGoals: FetchedResults<FamilyGoal>

    public var onHome: (() -> Void)?
    public init(onHome: (() -> Void)? = nil) { self.onHome = onHome }

    private var dark: Bool { darkOverride ?? (sys == .dark) }
    private var P: CasalistCottage.Palette { CasalistCottage.Palette.resolve(dark) }

    /// Trips are family tasks with a non-nil dueDate AND no parentUid.
    /// They act as containers — other items nest under them via parentUid.
    /// Trips themselves are never claimable, so we don't filter by assignee.
    private var trips: [TaskItem] {
        allTasks.filter {
            $0.category.lowercased() == "family"
                && $0.dueDate != nil
                && $0.parentUid.isEmpty
                && !$0.isCompleted
        }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }
    /// Items nested under a specific trip. Nested items aren't
    /// individually claimable — the family works the outing together —
    /// so we show them all regardless of assignee state.
    private func items(in trip: TaskItem) -> [TaskItem] {
        allTasks.filter {
            $0.category.lowercased() == "family"
                && $0.parentUid == trip.uid
                && !$0.isCompleted
        }.sorted { $0.createdAt < $1.createdAt }
    }
    /// Loose items — no trip parent, no dueDate, UNCLAIMED.
    private var looseItems: [TaskItem] {
        allTasks.filter {
            $0.category.lowercased() == "family"
                && $0.parentUid.isEmpty
                && $0.dueDate == nil
                && !$0.isCompleted
                && ($0.assignee ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        }.sorted { $0.createdAt > $1.createdAt }
    }
    /// Agenda: loose, unclaimed quick-add items only. Outings have
    /// their own internal task list inside the OUTINGS section, so we
    /// don't double-show their nested items here. Trips themselves are
    /// also excluded — they're plans, not chores.
    private var agendaItems: [TaskItem] {
        allTasks.filter {
            $0.category.lowercased() == "family"
                && !$0.isCompleted
                && $0.parentUid.isEmpty       // not nested in a trip
                && $0.dueDate == nil          // not a trip itself
                && ($0.assignee ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        }.sorted { $0.createdAt > $1.createdAt }
    }
    private func agendaSortDate(_ t: TaskItem) -> Date {
        if let d = t.dueDate { return d }
        // For nested items, sort under their trip.
        if !t.parentUid.isEmpty,
           let parent = allTasks.first(where: { $0.uid == t.parentUid }),
           let d = parent.dueDate {
            return d
        }
        return t.createdAt
    }
    /// Used by the hero badge "X up for grabs". Only counts loose,
    /// unclaimed quick-add items — the things that show as agenda
    /// tiles. Outings (trips) aren't claimable, and the items nested
    /// under an outing are collective work the family does together
    /// (also not individually claimable). So both are excluded from
    /// the badge count.
    private var openItems: [TaskItem] {
        agendaItems
    }
    private var recentlyDone: [TaskItem] {
        allTasks.filter { $0.category.lowercased() == "family" && $0.isCompleted }.prefix(6).map { $0 }
    }

    public var body: some View {
        ZStack {
            P.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                ScrollView { content }.scrollIndicators(.hidden)
            }
        }
        .foregroundStyle(P.text)
        .preferredColorScheme(dark ? .dark : .light)
        .sheet(isPresented: $showAdd) { AddFamilyTripView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showInbox) { InboxView() }
        .sheet(isPresented: $showStatusPing) { StatusPingSheet() }
        .sheet(isPresented: $showFamilyMap) { FamilyMapView() }
        .sheet(item: $editingTask) { t in TaskDetailView(task: t) }
        .sheet(item: $editingAnnouncement) { a in StatusPingSheet(editing: a) }
        .celebration(visible: $celebrate, label: celebrateLabel)
    }

    private var inboxBadgeCount: Int {
        let me = FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)
        let pending = allGoals.filter { GoalApproval.isPending($0) && !$0.isRedeemed }
        if me?.canManageFamily == true { return pending.count }
        let lc = (me?.name.lowercased() ?? userName.lowercased())
        return pending.filter { GoalApproval.realOwnerName($0).lowercased() == lc }.count
    }

    private var topBar: some View {
        HStack(spacing: 6) {
            Button { if let onHome { onHome() } else { dismiss() } } label: {
                Image(systemName: "house.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(P.text)
                    .frame(width: 36, height: 36).background(Circle().fill(P.surfaceAlt))
            }
            Spacer()
            Button { showStatusPing = true } label: {
                Image(systemName: "megaphone.fill").font(.system(size: 14)).foregroundStyle(P.text)
                    .frame(width: 36, height: 36).background(Circle().fill(P.surfaceAlt))
            }
            Button { showFamilyMap = true } label: {
                Image(systemName: "mappin.and.ellipse").font(.system(size: 14)).foregroundStyle(P.text)
                    .frame(width: 36, height: 36).background(Circle().fill(P.surfaceAlt))
            }
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 14)).foregroundStyle(P.text)
                    .frame(width: 36, height: 36).background(Circle().fill(P.surfaceAlt))
            }
            Button { showInbox = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "tray.full.fill").font(.system(size: 14)).foregroundStyle(P.text)
                        .frame(width: 36, height: 36).background(Circle().fill(P.surfaceAlt))
                    if inboxBadgeCount > 0 {
                        Text("\(inboxBadgeCount)").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(P.peach)).offset(x: 6, y: -2)
                    }
                }
            }
            Button { showAdd = true } label: {
                Image(systemName: "plus").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(P.peach))
                    .shadow(color: P.peach.opacity(0.4), radius: 8, y: 4)
            }
        }.padding(.horizontal, 16).padding(.bottom, 12)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !activeAnnouncements.isEmpty { announcementsBanner }
            hero
            quickAddBar
            if !agendaItems.isEmpty { agendaSection }
            if !trips.isEmpty { tripsSection }
            if !looseItems.isEmpty { looseSection }
            if agendaItems.isEmpty && trips.isEmpty && looseItems.isEmpty { emptyCard }
            if !recentlyDone.isEmpty { doneSection }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
    }

    /// Active custom announcements — status-ping records that have an
    /// expiry (`dueDate` field, reused as banner-expiration) still in
    /// the future. Newest first.
    private var activeAnnouncements: [TaskItem] {
        let now = Date()
        return allTasks.filter {
            $0.category == StatusPing.category
                && $0.deletedAtValue == nil
                && ($0.dueDate ?? .distantPast) > now
        }.sorted { $0.createdAt > $1.createdAt }
    }

    private var announcementsBanner: some View {
        VStack(spacing: 8) {
            ForEach(activeAnnouncements, id: \.uid) { a in
                announcementCard(a)
            }
        }
    }

    private func announcementCard(_ a: TaskItem) -> some View {
        let sender = a.createdBy.isEmpty ? "Someone" : a.createdBy
        let canEdit = (a.createdBy.lowercased()
                         == userName.trimmingCharacters(in: .whitespaces).lowercased())
        return Button {
            if canEdit { editingAnnouncement = a }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.25)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(sender.uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.6).opacity(0.85)
                    Text(a.task)
                        .font(.system(size: 18, weight: .heavy))
                        .multilineTextAlignment(.leading)
                    if let exp = a.dueDate {
                        Text("Expires \(expiryLabel(exp))")
                            .font(.system(size: 11, weight: .semibold))
                            .opacity(0.85)
                    }
                }
                Spacer(minLength: 0)
                if canEdit {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 22))
                        .opacity(0.85)
                }
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(
                LinearGradient(colors: [P.peach, P.coral],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: P.peach.opacity(0.35), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func expiryLabel(_ d: Date) -> String {
        let secs = d.timeIntervalSinceNow
        if secs < 60 { return "in a moment" }
        if secs < 3600 {
            let m = Int(secs / 60)
            return "in \(m) min"
        }
        if secs < 86400 {
            let h = Int(secs / 3600)
            return "in \(h) hour\(h == 1 ? "" : "s")"
        }
        let f = DateFormatter()
        f.dateStyle = .none; f.timeStyle = .short
        let day = Calendar.current.isDateInTomorrow(d) ? "tomorrow" : "later"
        return "\(day) at \(f.string(from: d))"
    }

    // MARK: – Quick-add bar (mirrors Grocery's inline TextField)

    private var quickAddBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle").font(.system(size: 18)).foregroundStyle(P.textDim)
            TextField("Add anything quick…", text: $newItem)
                .font(.system(size: 14, weight: .semibold))
                .submitLabel(.done)
                .onSubmit(addInlineItem)
            Button { addInlineItem() } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .heavy)).foregroundStyle(.white)
                    .frame(width: 32, height: 32).background(Circle().fill(P.peach))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 4).padding(.trailing, 4)
        .background(Capsule().fill(P.surface))
        .overlay(Capsule().stroke(P.border, lineWidth: 1.5))
    }

    private func addInlineItem() {
        let name = newItem.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let it = TaskItem(
            context: moc,
            task: name,
            category: "family",
            points: 0,
            createdBy: userName.trimmingCharacters(in: .whitespaces)
        )
        if let h = households.preferredTarget {
            moc.assign(it, toStoreOf: h)
            it.household = h
        }
        try? moc.save()
        newItem = ""
    }

    private func addItem(to trip: TaskItem) {
        let key = trip.uid
        let name = (newItemByTrip[key] ?? "").trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let it = TaskItem(
            context: moc,
            task: name,
            category: "family",
            points: 0,
            createdBy: userName.trimmingCharacters(in: .whitespaces),
            parentUid: trip.uid
        )
        if let h = trip.household {
            moc.assign(it, toStoreOf: h)
            it.household = h
        }
        try? moc.save()
        newItemByTrip[key] = ""
    }

    // MARK: – Agenda section

    private var agendaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AGENDA").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
            // Horizontal scrolling tiles matching the dashboard's stickyAgenda
            // pattern. Each tile = symbol in colored circle, title, subtitle.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(agendaItems.enumerated()), id: \.element.uid) { i, t in
                        agendaTile(t, index: i)
                    }
                }
                .padding(.vertical, 4)
            }
            .foregroundStyle(P.text)
        }
    }

    private func agendaTile(_ t: TaskItem, index: Int) -> some View {
        Button { editingTask = t } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(P.mint)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(P.mint.opacity(0.2)))
                Text(t.task).font(.system(size: 13, weight: .heavy)).lineLimit(2)
                Text(agendaSubtitle(t))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(P.textMuted)
                    .lineLimit(2)
            }
            .padding(14)
            .frame(width: 130, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20).fill(index % 2 == 0 ? P.surface : P.surfaceAlt))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(P.border, lineWidth: 1.5))
        }.buttonStyle(.plain)
    }

    private func agendaSubtitle(_ t: TaskItem) -> String {
        if let d = t.dueDate {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            return f.string(from: d)
        }
        if !t.parentUid.isEmpty,
           let parent = allTasks.first(where: { $0.uid == t.parentUid }),
           let d = parent.dueDate {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            return f.string(from: d)
        }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: t.createdAt)
    }

    // MARK: – Trips section

    private var tripsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OUTINGS").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
            VStack(spacing: 12) {
                ForEach(trips, id: \.uid) { trip in
                    tripCard(trip)
                }
            }
        }
    }

    private func tripCard(_ trip: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { editingTask = trip } label: {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trip.task).font(.system(size: 16, weight: .heavy)).foregroundStyle(P.text)
                        if let d = trip.dueDate {
                            Text(tripDateText(d)).font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textMuted)
                        }
                    }
                    Spacer()
                    Text("\(items(in: trip).count)").font(.system(size: 11, weight: .heavy))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(P.peach.opacity(0.25))).foregroundStyle(P.peach)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(P.textMuted)
                }
            }.buttonStyle(.plain)
            VStack(spacing: 6) {
                ForEach(items(in: trip), id: \.uid) { it in
                    Button { editingTask = it } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "circle").font(.system(size: 14)).foregroundStyle(P.textMuted)
                            Text(it.task).font(.system(size: 13, weight: .semibold)).foregroundStyle(P.text)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(P.textMuted)
                        }
                    }.buttonStyle(.plain)
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "plus.circle").font(.system(size: 14)).foregroundStyle(P.textDim)
                TextField("Add a task to this outing…", text: Binding(
                    get: { newItemByTrip[trip.uid] ?? "" },
                    set: { newItemByTrip[trip.uid] = $0 }
                ))
                .font(.system(size: 13, weight: .semibold))
                .submitLabel(.done)
                .onSubmit { addItem(to: trip) }
                Button { addItem(to: trip) } label: {
                    Image(systemName: "arrow.up").font(.system(size: 12, weight: .heavy)).foregroundStyle(.white)
                        .frame(width: 26, height: 26).background(Circle().fill(P.peach))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 3)
            .background(Capsule().fill(P.surfaceAlt))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
    }

    private func tripDateText(_ d: Date) -> String {
        let f = DateFormatter()
        if Calendar.current.isDateInToday(d) { f.dateFormat = "'Today' h:mm a" }
        else if Calendar.current.isDateInTomorrow(d) { f.dateFormat = "'Tmrw' h:mm a" }
        else { f.dateFormat = "EEE MMM d 'at' h:mm a" }
        return f.string(from: d)
    }

    // MARK: – Loose items (added via quick-add bar, no trip)

    private var looseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK ITEMS").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
            VStack(spacing: 8) {
                ForEach(looseItems, id: \.uid) { t in row(t) }
            }
        }
    }

    private var emptyCard: some View {
        Button { showAdd = true } label: {
            VStack(spacing: 8) {
                Text("🪴").font(.system(size: 38))
                Text("Nothing on the wall").font(.system(size: 14, weight: .heavy))
                Text("Tap + to plan an outing, or type above to drop a quick item").font(.system(size: 11, weight: .semibold)).opacity(0.7)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(P.text)
            .frame(maxWidth: .infinity).padding(24)
            .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
        }.buttonStyle(.plain)
    }

    private var hero: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.white.opacity(0.22)).frame(width: 76, height: 76)
                Image(systemName: "tray.full.fill").font(.system(size: 30)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("FAMILY LIST").font(.system(size: 11, weight: .heavy)).tracking(0.8).opacity(0.85)
                Text("\(openItems.count) up for grabs").font(.system(size: 22, weight: .heavy))
                Text(openItems.isEmpty ? "Add something the family can pick up" : "Tap Claim to make it yours")
                    .font(.system(size: 12, weight: .semibold)).opacity(0.85)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(P.lavender)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var openSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OPEN").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
            if openItems.isEmpty {
                Button { showAdd = true } label: {
                    VStack(spacing: 8) {
                        Text("🪴").font(.system(size: 38))
                        Text("Nothing on the wall").font(.system(size: 14, weight: .heavy))
                        Text("Tap + to drop something the family can do").font(.system(size: 11, weight: .semibold)).opacity(0.7)
                    }
                    .foregroundStyle(P.text)
                    .frame(maxWidth: .infinity).padding(24)
                    .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
                }.buttonStyle(.plain)
            } else {
                VStack(spacing: 8) {
                    ForEach(openItems, id: \.uid) { t in row(t) }
                }
            }
        }
    }

    private var doneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECENTLY DONE").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
            VStack(spacing: 6) {
                ForEach(recentlyDone, id: \.uid) { t in
                    Button { editingTask = t } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(P.mint).font(.system(size: 16))
                            Text(t.task).font(.system(size: 13, weight: .semibold)).strikethrough().foregroundStyle(P.textMuted).lineLimit(1)
                            Spacer()
                            if !(t.assignee ?? "").isEmpty {
                                Text(t.assignee!).font(.system(size: 10, weight: .heavy)).foregroundStyle(P.textMuted)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 16).fill(P.surface))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(P.border, lineWidth: 1))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func row(_ t: TaskItem) -> some View {
        HStack(spacing: 12) {
            Button { editingTask = t } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t.task).font(.system(size: 14, weight: .heavy)).lineLimit(2).foregroundStyle(P.text)
                    HStack(spacing: 6) {
                        if t.points > 0 {
                            Text("⭐ \(t.points)").font(.system(size: 10, weight: .heavy))
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Capsule().fill(P.butter))
                                .foregroundStyle(.white)
                        }
                        if !t.createdBy.isEmpty {
                            Text("added by \(t.createdBy)").font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }.buttonStyle(.plain)
            Button { claim(t) } label: {
                Text("Claim").font(.system(size: 12, weight: .heavy)).foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Capsule().fill(P.peach))
            }.buttonStyle(.plain)
            Button { markDone(t) } label: {
                Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy)).foregroundStyle(.white)
                    .frame(width: 32, height: 32).background(Circle().fill(P.mint))
            }.buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20).fill(P.surface))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(P.border, lineWidth: 1.5))
    }

    private func claim(_ t: TaskItem) {
        let me = userName.trimmingCharacters(in: .whitespaces)
        guard !me.isEmpty else { return }
        t.assignee = me
        try? moc.save()
    }

    private func markDone(_ t: TaskItem) {
        // If unclaimed, the marker takes credit so points (if any) go somewhere.
        if (t.assignee ?? "").isEmpty {
            t.assignee = userName.trimmingCharacters(in: .whitespaces)
        }
        let pts = Int(t.points)
        FamilyPoints.toggle(t, in: members)
        try? moc.save()
        celebrateLabel = pts > 0 ? "+\(pts) pts!" : "Done!"
        celebrate = true
    }
}

/// Sheet for dropping a new item onto the family wall.
struct AddFamilyListItemView: View {
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName: String = ""
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var households: FetchedResults<Household>

    @State private var label: String = ""
    @State private var points: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("What's it for?") {
                    TextField("e.g. Pick up the birthday cake", text: $label)
                        .textInputAutocapitalization(.sentences)
                }
                Section("Points") {
                    Stepper(value: $points, in: 0...200, step: 5) {
                        Text(points == 0 ? "No points" : "\(points) pts")
                    }
                    Text("Whoever claims and finishes the task earns the points.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add to family list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: save).disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let t = TaskItem(
            context: moc,
            task: label.trimmingCharacters(in: .whitespaces),
            assignee: nil,
            dueDate: nil,
            category: "family",
            isCompleted: false,
            points: points,
            createdBy: userName.trimmingCharacters(in: .whitespaces)
        )
        if let h = households.preferredTarget {
            moc.assign(t, toStoreOf: h)
            t.household = h
        }
        try? moc.save()
        dismiss()
    }
}
