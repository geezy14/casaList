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
    @State private var celebrate: Bool = false
    @State private var celebrateLabel: String = ""

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyGoal.createdAt, ascending: false)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var allGoals: FetchedResults<FamilyGoal>

    public var onHome: (() -> Void)?
    public init(onHome: (() -> Void)? = nil) { self.onHome = onHome }

    private var dark: Bool { darkOverride ?? (sys == .dark) }
    private var P: CasalistCottage.Palette { CasalistCottage.Palette.resolve(dark) }

    private var openItems: [TaskItem] {
        allTasks.filter { $0.category.lowercased() == "family" && !$0.isCompleted && ($0.assignee ?? "").isEmpty }
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
        .sheet(isPresented: $showAdd) { AddFamilyListItemView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showInbox) { InboxView() }
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
        HStack(spacing: 10) {
            Button { if let onHome { onHome() } else { dismiss() } } label: {
                Image(systemName: "house.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(P.text)
                    .frame(width: 38, height: 38).background(Circle().fill(P.surfaceAlt))
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 14)).foregroundStyle(P.text)
                    .frame(width: 38, height: 38).background(Circle().fill(P.surfaceAlt))
            }
            Button { showInbox = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "tray.full.fill").font(.system(size: 14)).foregroundStyle(P.text)
                        .frame(width: 38, height: 38).background(Circle().fill(P.surfaceAlt))
                    if inboxBadgeCount > 0 {
                        Text("\(inboxBadgeCount)").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(P.peach)).offset(x: 6, y: -2)
                    }
                }
            }
            Button { showAdd = true } label: {
                Image(systemName: "plus").font(.system(size: 19, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(P.peach))
                    .shadow(color: P.peach.opacity(0.4), radius: 8, y: 4)
            }
        }.padding(.horizontal, 16).padding(.bottom, 12)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            hero
            openSection
            if !recentlyDone.isEmpty { doneSection }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
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
                }
            }
        }
    }

    private func row(_ t: TaskItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t.task).font(.system(size: 14, weight: .heavy)).lineLimit(2)
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
            Spacer()
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
