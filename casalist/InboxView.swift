import SwiftUI
import CoreData

/// The "message box" inbox surfaced from the Home top-bar envelope icon.
/// For now it holds pending goal approvals + a short list of recently
/// approved goals so parents can see what they've decided.
struct InboxView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.colorScheme) private var sys
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("meUid") private var meUid: String = ""

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var members: FetchedResults<FamilyMember>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyGoal.createdAt, ascending: false)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var goals: FetchedResults<FamilyGoal>

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
    /// Recently approved (non-pending, non-redeemed) goals — newest first,
    /// capped to 10. Lets parents see "what I approved" lightly.
    private var recentlyApproved: [FamilyGoal] {
        goals.filter { !GoalApproval.isPending($0) && !$0.isRedeemed }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(10)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                P.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        if iAmAdmin {
                            parentSection
                        } else {
                            submitterSection
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    // Yank down → wait briefly so CloudKit's background pull
                    // has a chance to land any pending shared-zone changes,
                    // then drop cached objects so the @FetchRequests re-read
                    // the store. Doesn't bypass CloudKit latency, but cuts
                    // the "I know it's coming but my screen looks stale"
                    // perception.
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

    // MARK: – Parent view

    private var parentSection: some View {
        VStack(spacing: 14) {
            sectionHeader("AWAITING APPROVAL ⏳", tint: P.peach, count: pendingGoals.count)
            if pendingGoals.isEmpty {
                emptyCard("Nothing waiting on you.")
            } else {
                VStack(spacing: 8) {
                    ForEach(pendingGoals) { g in
                        parentApprovalRow(g)
                    }
                }
            }

            sectionHeader("RECENT APPROVALS", tint: P.mint, count: recentlyApproved.count)
            if recentlyApproved.isEmpty {
                emptyCard("Approved goals will show here.")
            } else {
                VStack(spacing: 6) {
                    ForEach(recentlyApproved) { g in
                        approvedRow(g)
                    }
                }
            }
        }
    }

    private func parentApprovalRow(_ g: FamilyGoal) -> some View {
        ApprovalRow(goal: g, members: Array(members), palette: P, moc: moc)
    }

    /// Pulled out into its own View so it can hold per-goal `@State`
    /// for the price stepper without leaking between rows.
    private struct ApprovalRow: View {
        let goal: FamilyGoal
        let members: [FamilyMember]
        let palette: CasalistCottage.Palette
        let moc: NSManagedObjectContext
        @State private var draftPrice: Int = 0
        @State private var initialized: Bool = false

        private var P: CasalistCottage.Palette { palette }
        private var realOwner: String { GoalApproval.realOwnerName(goal) }
        private var needsPrice: Bool { goal.targetPoints == 0 }

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    if let m = members.first(where: { $0.name.lowercased() == realOwner.lowercased() }) {
                        LeveledAvatar(member: m, size: 32)
                    } else {
                        ZStack {
                            Circle().fill(P.surfaceAlt).frame(width: 32, height: 32)
                            Image(systemName: "questionmark").font(.system(size: 12)).foregroundStyle(P.textMuted)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.label).font(.system(size: 14, weight: .heavy))
                        Text(needsPrice
                             ? "\(realOwner) · needs a price"
                             : "\(realOwner) · \(goal.targetPoints) pts")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textMuted)
                    }
                    Spacer()
                }
                if !goal.note.isEmpty {
                    Text("\u{201C}\(goal.note)\u{201D}")
                        .font(.system(size: 12, weight: .semibold).italic())
                        .foregroundStyle(P.textDim)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(P.surfaceAlt.opacity(0.4)))
                }
                if needsPrice {
                    HStack {
                        Text("Set price").font(.system(size: 11, weight: .heavy)).foregroundStyle(P.textMuted)
                        Spacer()
                        Text("\(draftPrice) pts").font(.system(size: 13, weight: .heavy)).foregroundStyle(P.peach)
                        Stepper("\(draftPrice) pts", value: $draftPrice, in: 10...10_000, step: 10)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 12).fill(P.surfaceAlt.opacity(0.5)))
                }
                HStack(spacing: 10) {
                    Button {
                        GoalApproval.deny(goal, in: moc)
                        try? moc.save()
                    } label: {
                        Text("Deny").font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Capsule().fill(Color.red.opacity(0.8)))
                    }.buttonStyle(.plain)
                    Button {
                        if needsPrice {
                            GoalApproval.approve(goal, targetPoints: draftPrice)
                        } else {
                            GoalApproval.approve(goal)
                        }
                        try? moc.save()
                    } label: {
                        Text(needsPrice ? "Approve · \(draftPrice) pts" : "Approve")
                            .font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Capsule().fill(P.mint))
                    }.buttonStyle(.plain)
                    .disabled(needsPrice && draftPrice < 10)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 20).fill(P.surface))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(P.border, lineWidth: 1.5))
            .onAppear {
                if !initialized {
                    draftPrice = Int(goal.targetPoints) > 0 ? Int(goal.targetPoints) : 50
                    initialized = true
                }
            }
        }
    }

    private func approvedRow(_ g: FamilyGoal) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16)).foregroundStyle(P.mint)
            VStack(alignment: .leading, spacing: 2) {
                Text(g.label).font(.system(size: 13, weight: .heavy))
                Text("\(g.ownerName) · \(g.targetPoints) pts")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted)
            }
            Spacer()
            Text(g.createdAt, style: .date).font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16).fill(P.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(P.border, lineWidth: 1))
    }

    // MARK: – Submitter view

    private var submitterSection: some View {
        VStack(spacing: 14) {
            sectionHeader("AWAITING PARENT APPROVAL", tint: P.peach, count: pendingForMe.count)
            if pendingForMe.isEmpty {
                emptyCard("Nothing waiting. Add a goal to ask your family for one.")
            } else {
                VStack(spacing: 8) {
                    ForEach(pendingForMe) { g in
                        submitterRow(g)
                    }
                }
            }
        }
    }

    private func submitterRow(_ g: FamilyGoal) -> some View {
        HStack(spacing: 12) {
            Text("⏳").font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text(g.label).font(.system(size: 14, weight: .heavy))
                Text("\(g.targetPoints) pts target")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textMuted)
            }
            Spacer()
            Button {
                GoalApproval.deny(g, in: moc)
                try? moc.save()
            } label: {
                Text("Cancel").font(.system(size: 12, weight: .heavy)).foregroundStyle(P.peach)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(P.peach.opacity(0.15)))
            }.buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20).fill(P.surface))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(P.border, lineWidth: 1.5))
    }

    // MARK: – Bits

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
            .frame(maxWidth: .infinity).padding(.vertical, 20).padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 16).fill(P.surface))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(P.border, lineWidth: 1))
    }
}
