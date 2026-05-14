import SwiftUI
import SwiftData

struct AddGroceryTripView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName: String = ""

    @State private var name: String = ""
    @State private var hasDate: Bool = true
    @State private var tripDate: Date = Date().addingTimeInterval(3600)

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip name") {
                    TextField("Trader Joe's run, Costco, etc.", text: $name)
                        .textInputAutocapitalization(.words)
                }
                Section("When") {
                    Toggle("Schedule this trip", isOn: $hasDate)
                    if hasDate {
                        DatePicker("Date & time", selection: $tripDate)
                    }
                }
                Section {
                    Text("After saving, you can add items to this trip in the Grocery tab.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New shopping trip")
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
        let trip = TaskItem(
            task: name.trimmingCharacters(in: .whitespaces),
            dueDate: hasDate ? tripDate : nil,
            category: "groceries",
            points: 0,
            createdBy: userName.trimmingCharacters(in: .whitespaces)
        )
        modelContext.insert(trip)
        try? modelContext.save()
        Task { await NotificationsManager.scheduleNow(for: trip) }
        dismiss()
    }
}
