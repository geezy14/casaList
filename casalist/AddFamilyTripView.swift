import SwiftUI
import CoreData

/// Mirrors `AddGroceryTripView` for the Family tab — creates a parent
/// TaskItem (category = "family") that other family-tab items can nest
/// under via `parentUid`. Title doubles as the "trip" or "outing"
/// label; optional date attaches the trip to a calendar moment.
///
/// Container sentinel: outings/trips are stamped with `points = -1`
/// so the family/grocery filters can recognize them as containers
/// regardless of whether a date was set. Without this marker, a
/// dateless outing falls through to the loose-items bucket and
/// can't have children nested under it. See `TaskItem.isContainer`.
struct AddFamilyTripView: View {
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName: String = ""
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)],
                  predicate: NSPredicate(format: "deletedAt == nil"))
    private var households: FetchedResults<Household>

    @State private var name: String = ""
    @State private var hasDate: Bool = true
    @State private var hasTime: Bool = false
    @State private var tripDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var tripEndDate: Date = Calendar.current.startOfDay(for: Date()).addingTimeInterval(3600)

    var body: some View {
        NavigationStack {
            Form {
                Section("Outing name") {
                    TextField("Saturday yard work, soccer pickup, packing list…", text: $name)
                        .textInputAutocapitalization(.sentences)
                }
                Section("When") {
                    Toggle("Schedule this outing", isOn: $hasDate)
                        .onChange(of: hasDate) { _, on in if !on { hasTime = false } }
                    if hasDate {
                        DatePicker("Date", selection: $tripDate, displayedComponents: .date)
                        Toggle("Specific time", isOn: $hasTime.animation())
                            .onChange(of: hasTime) { _, on in
                                if !on { tripDate = Calendar.current.startOfDay(for: tripDate) }
                                else { tripEndDate = tripDate.addingTimeInterval(3600) }
                            }
                        if hasTime {
                            DatePicker("Starts", selection: $tripDate, displayedComponents: .hourAndMinute)
                                .onChange(of: tripDate) { _, d in
                                    if tripEndDate <= d { tripEndDate = d.addingTimeInterval(3600) }
                                }
                            DatePicker("Ends", selection: $tripEndDate, in: tripDate..., displayedComponents: .hourAndMinute)
                        }
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
            dueDate: hasDate ? (hasTime ? tripDate : Calendar.current.startOfDay(for: tripDate)) : nil,
            category: "family",
            points: -1, // container sentinel — see TaskItem.isContainer
            createdBy: userName.trimmingCharacters(in: .whitespaces)
        )
        if hasDate && hasTime {
            trip.endDate = tripEndDate
        }
        if let h = households.preferredTarget {
            moc.assign(trip, toStoreOf: h)
            trip.household = h
        }
        try? moc.save()
        Task { await NotificationsManager.scheduleNow(for: trip) }
        dismiss()
    }
}
