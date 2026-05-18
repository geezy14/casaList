import SwiftUI
import CoreData

struct AddChoreBundleView: View {
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName: String = ""
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)],
                  predicate: NSPredicate(format: "deletedAt == nil"))
    private var households: FetchedResults<Household>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)],
                  predicate: NSPredicate(format: "deletedAt == nil"))
    private var members: FetchedResults<FamilyMember>

    @State private var name: String = ""
    @State private var assignee: String = ""
    @State private var bonusPoints: Int = 25

    var body: some View {
        NavigationStack {
            Form {
                Section("Bundle name") {
                    TextField("Morning routine, Deep clean, Weekly chores...", text: $name)
                        .textInputAutocapitalization(.sentences)
                }
                Section("Assign to") {
                    Picker("Assignee", selection: $assignee) {
                        Text("Anyone").tag("")
                        ForEach(members, id: \.uid) { m in
                            Text(m.name).tag(m.name)
                        }
                    }
                }
                Section {
                    Stepper("Bonus: \(bonusPoints) pts", value: $bonusPoints, in: 0...500, step: 5)
                } header: {
                    Text("Completion bonus")
                } footer: {
                    Text("Awarded on top of individual chore points when all chores in the bundle are done.")
                }
                Section {
                    Text("After saving, add chores to this bundle from the task list.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New chore bundle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let bundle = TaskItem(
            context: moc,
            task: name.trimmingCharacters(in: .whitespaces),
            dueDate: nil,
            category: "chores",
            points: bonusPoints,
            createdBy: userName.trimmingCharacters(in: .whitespaces)
        )
        bundle.repeatKind = "bundle"
        bundle.assignee = assignee.isEmpty ? nil : assignee
        if let h = households.preferredTarget {
            moc.assign(bundle, toStoreOf: h)
            bundle.household = h
        }
        try? moc.save()
        dismiss()
    }
}
