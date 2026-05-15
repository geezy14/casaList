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

    @State private var ownerName: String = ""
    @State private var label: String = ""
    @State private var target: Int = 200

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
                            #if DEBUG
                            Text("👨‍👩‍👧‍👦 Whole family").tag(TeamGoal.sentinel)
                            #endif
                            ForEach(members, id: \.uid) { m in
                                Text(m.name).tag(m.name)
                            }
                        }
                        #if DEBUG
                        if ownerName == TeamGoal.sentinel {
                            Text("Whole-family goals add together everyone's points. No points are spent when you redeem — it's a celebration milestone.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        #endif
                    }
                }
                Section("Target points") {
                    Stepper(value: $target, in: 10...10_000, step: 10) {
                        Text("\(target) pts")
                    }
                }
            }
            .navigationTitle("New goal")
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
        let g = FamilyGoal(
            context: moc,
            ownerName: storedOwner,
            label: label.trimmingCharacters(in: .whitespaces),
            targetPoints: target
        )
        if let h = households.preferredTarget {
            moc.assign(g, toStoreOf: h)
            g.household = h
        }
        try? moc.save()
        dismiss()
    }
}
