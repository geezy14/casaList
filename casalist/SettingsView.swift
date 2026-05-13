import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("householdName") private var householdName: String = "My Household"

    @Query private var members: [FamilyMember]
    @Query private var tasks: [TaskItem]
    @Query private var households: [Household]

    @State private var confirmWipe: Bool = false
    @State private var wipeMessage: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Your profile") {
                    TextField("Your name", text: $userName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                }
                Section("Household") {
                    TextField("Household name", text: $householdName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                }
                Section("Developer") {
                    HStack {
                        Text("Family members"); Spacer()
                        Text("\(members.count)").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Tasks"); Spacer()
                        Text("\(tasks.count)").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Households"); Spacer()
                        Text("\(households.count)").foregroundStyle(.secondary)
                    }
                    Button(role: .destructive) { confirmWipe = true } label: {
                        Label("Clear all data", systemImage: "trash")
                    }
                    if let wipeMessage {
                        Text(wipeMessage).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Text("Casalist")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog(
                "Clear all data?",
                isPresented: $confirmWipe,
                titleVisibility: .visible
            ) {
                Button("Wipe everything", role: .destructive) { wipeAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Deletes all tasks, family members, and household data on this device. Resets your name and household name. Cannot be undone.")
            }
        }
    }

    private func wipeAll() {
        for t in tasks { modelContext.delete(t) }
        for m in members { modelContext.delete(m) }
        for h in households { modelContext.delete(h) }
        try? modelContext.save()
        userName = ""
        householdName = "My Household"
        wipeMessage = "Cleared \(tasks.count + members.count + households.count) records."
    }
}
