import SwiftUI
import CoreData

/// Mirrors `AddGroceryTripView` for the Family tab — creates a parent
/// TaskItem (category = "family") that other family-tab items can nest
/// under via `parentUid`. Title doubles as the "trip" or "outing"
/// label; optional date attaches the trip to a calendar moment.
struct AddFamilyTripView: View {
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName: String = ""
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)],
                  predicate: NSPredicate(format: "deletedAt == nil"))
    private var households: FetchedResults<Household>

    @State private var name: String = ""
    @State private var hasDate: Bool = true
    @State private var tripDate: Date = Date().addingTimeInterval(3600)

    var body: some View {
        NavigationStack {
            Form {
                Section("Outing name") {
                    TextField("Saturday yard work, soccer pickup, packing list…", text: $name)
                        .textInputAutocapitalization(.sentences)
                }
                Section("When") {
                    Toggle("Schedule this outing", isOn: $hasDate)
                    if hasDate {
                        DatePicker("Date & time", selection: $tripDate)
                    }
                }
                Section {
                    Text("After saving, add tasks under this outing in the Family tab.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New family outing")
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
            context: moc,
            task: name.trimmingCharacters(in: .whitespaces),
            dueDate: hasDate ? tripDate : nil,
            category: "family",
            points: 0,
            createdBy: userName.trimmingCharacters(in: .whitespaces)
        )
        if let h = households.preferredTarget {
            moc.assign(trip, toStoreOf: h)
            trip.household = h
        }
        try? moc.save()
        Task { await NotificationsManager.scheduleNow(for: trip) }
        dismiss()
    }
}
