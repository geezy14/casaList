import SwiftUI
import CoreData

struct AddGroceryTripView: View {
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName: String = ""
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var households: FetchedResults<Household>

    @State private var name: String = ""
    @State private var hasDate: Bool = true
    @State private var hasTime: Bool = false
    @State private var tripDate: Date = Calendar.current.startOfDay(for: Date())

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip name") {
                    TextField("Trader Joe's run, Costco, etc.", text: $name)
                        .textInputAutocapitalization(.words)
                }
                Section("When") {
                    Toggle("Schedule this trip", isOn: $hasDate)
                        .onChange(of: hasDate) { _, on in if !on { hasTime = false } }
                    if hasDate {
                        DatePicker("Date", selection: $tripDate, displayedComponents: .date)
                        Toggle("Specific time", isOn: $hasTime)
                            .onChange(of: hasTime) { _, on in
                                if !on { tripDate = Calendar.current.startOfDay(for: tripDate) }
                            }
                        if hasTime {
                            DatePicker("Time", selection: $tripDate, displayedComponents: .hourAndMinute)
                        }
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
            context: moc,
            task: name.trimmingCharacters(in: .whitespaces),
            dueDate: hasDate ? (hasTime ? tripDate : Calendar.current.startOfDay(for: tripDate)) : nil,
            category: "groceries",
            points: -1, // container sentinel — see TaskItem.isContainer

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
