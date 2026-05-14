import SwiftUI
import CoreData

struct AddGoalView: View {
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)])
    private var members: FetchedResults<FamilyMember>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)])
    private var households: FetchedResults<Household>

    @State private var ownerName: String = ""
    @State private var label: String = ""
    @State private var target: Int = 200

    var body: some View {
        NavigationStack {
            Form {
                Section("Saving for") {
                    TextField("Nintendo Switch game, art set…", text: $label)
                        .textInputAutocapitalization(.sentences)
                }
                Section("Who") {
                    Picker("Family member", selection: $ownerName) {
                        Text("Pick someone").tag("")
                        ForEach(members, id: \.uid) { m in
                            Text(m.name).tag(m.name)
                        }
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
                    Button("Save", action: save)
                        .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty || ownerName.isEmpty)
                }
            }
        }
    }

    private func save() {
        let g = FamilyGoal(
            context: moc,
            ownerName: ownerName,
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
