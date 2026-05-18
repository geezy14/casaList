import SwiftUI
import CoreData

struct AddGoalView: View {
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("meUid") private var meUid: String = ""
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var members: FetchedResults<FamilyMember>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var households: FetchedResults<Household>

    @StateObject private var gameRules = GameRulesStore.shared

    @State private var ownerName: String = ""
    @State private var label: String = ""
    @State private var target: Int = 200
    @State private var note: String = ""

    private var me: FamilyMember? {
        FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)
    }
    private var iAmAdmin: Bool { me?.canManageFamily ?? false }
    /// When non-admin submits, the goal is created pending approval. The
    /// owner field is also locked to themselves — kids can't propose a goal
    /// for someone else.
    private var lockedOwnerForSubmitter: String? {
        iAmAdmin ? nil : (me?.name ?? userName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Saving for") {
                    TextField("Nintendo Switch game, art set…", text: $label)
                        .textInputAutocapitalization(.sentences)
                }
                Section("Who") {
                    if let locked = lockedOwnerForSubmitter {
                        HStack {
                            Text("For")
                            Spacer()
                            Text(locked).foregroundStyle(.secondary)
                        }
                        Text("Goals you add need a parent's approval before they go live.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Picker("Family member", selection: $ownerName) {
                            Text("Pick someone").tag("")
                            ForEach(members, id: \.uid) { m in
                                Text(m.name).tag(m.name)
                            }
                        }
                    }
                }
                // Tier chips — shown to everyone. Admins use it to set price;
                // standard users use it to suggest which tier they want.
                Section(header: Text("Pick a reward tier"),
                        footer: Text(iAmAdmin
                                     ? "Tap a tier to set the target points."
                                     : "Tap a tier to suggest what you're aiming for. A parent will set the final price.")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(gameRules.rules.rewardTiers.sorted { $0.minPoints < $1.minPoints }) { tier in
                                Button {
                                    target = tier.minPoints
                                } label: {
                                    VStack(spacing: 2) {
                                        Text(tier.emoji).font(.system(size: 18))
                                        Text(tier.name).font(.system(size: 11, weight: .heavy))
                                        Text("\(tier.minPoints) pts").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(target == tier.minPoints ? Color(rgb: 0x7B5EA7).opacity(0.2) : Color(.systemGray6)))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(target == tier.minPoints ? Color(rgb: 0x7B5EA7) : Color.clear, lineWidth: 1.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                if iAmAdmin {
                    Section("Target points") {
                        Stepper(value: $target, in: 10...10_000, step: 10) {
                            Text("\(target) pts")
                        }
                    }
                } else {
                    Section {
                        TextField("Why do you want it? (optional)", text: $note, axis: .vertical)
                            .lineLimit(2...4)
                            .textInputAutocapitalization(.sentences)
                            .onChange(of: note) { _, new in
                                if new.count > 120 { note = String(new.prefix(120)) }
                            }
                        Text("A parent decides the final points price when they approve.")
                            .font(.caption).foregroundStyle(.secondary)
                    } header: {
                        Text("Make your case (optional)")
                    }
                }
            }
            .navigationTitle(iAmAdmin ? "New goal" : "Ask for a reward")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(iAmAdmin ? "Save" : "Submit", action: save)
                        .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty || resolvedOwner.isEmpty)
                }
            }
            .onAppear {
                if let locked = lockedOwnerForSubmitter {
                    ownerName = locked
                }
            }
        }
    }

    private var resolvedOwner: String {
        lockedOwnerForSubmitter ?? ownerName
    }

    private func save() {
        let realOwner = resolvedOwner
        let storedOwner = iAmAdmin ? realOwner : GoalApproval.makePendingOwnerName(realOwner)
        // Non-admins suggest a price via tier selection; admin confirms at approval.
        // Store their suggestion (or 0 if they didn't pick) so the approval UI
        // shows "Suggested: X pts" when non-zero.
        let storedTarget = iAmAdmin ? target : (target > 0 ? target : 0)
        let g = FamilyGoal(
            context: moc,
            ownerName: storedOwner,
            label: label.trimmingCharacters(in: .whitespaces),
            targetPoints: storedTarget
        )
        if !iAmAdmin {
            g.note = note.trimmingCharacters(in: .whitespaces)
        }
        if let h = households.preferredTarget {
            moc.assign(g, toStoreOf: h)
            g.household = h
        }
        try? moc.save()
        dismiss()
    }
}
