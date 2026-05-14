import SwiftUI
import SwiftData

struct AddGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FamilyMember.createdAt) private var members: [FamilyMember]

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
                        ForEach(members) { m in
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
        modelContext.insert(FamilyGoal(
            ownerName: ownerName,
            label: label.trimmingCharacters(in: .whitespaces),
            targetPoints: target
        ))
        try? modelContext.save()
        dismiss()
    }
}
