import SwiftUI
import CoreData

struct AddGroceryTripView: View {
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName: String = ""
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var households: FetchedResults<Household>

    private let editing: TaskItem?

    @State private var name: String
    @State private var hasDate: Bool
    @State private var hasTime: Bool
    @State private var tripDate: Date
    @State private var tripEndDate: Date

    init(editing: TaskItem? = nil) {
        self.editing = editing
        let cal = Calendar.current
        if let t = editing {
            _name = State(initialValue: t.task)
            let hasD = t.dueDate != nil
            _hasDate = State(initialValue: hasD)
            let d = t.dueDate ?? cal.startOfDay(for: Date())
            let comps = cal.dateComponents([.hour, .minute], from: d)
            let hasT = (comps.hour ?? 0) != 0 || (comps.minute ?? 0) != 0
            _hasTime = State(initialValue: hasT)
            _tripDate = State(initialValue: d)
            _tripEndDate = State(initialValue: t.endDate ?? d.addingTimeInterval(3600))
        } else {
            _name = State(initialValue: "")
            _hasDate = State(initialValue: true)
            _hasTime = State(initialValue: false)
            _tripDate = State(initialValue: cal.startOfDay(for: Date()))
            _tripEndDate = State(initialValue: cal.startOfDay(for: Date()).addingTimeInterval(3600))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip name") {
                    TextField("Trader Joe's run, Costco, etc.", text: $name)
                        .textInputAutocapitalization(.words)
                }
                Section("When") {
                    Toggle("Schedule this trip", isOn: $hasDate.animation())
                        .onChange(of: hasDate) { _, on in if !on { hasTime = false } }
                    if hasDate {
                        DatePicker("Date", selection: $tripDate, displayedComponents: .date)
                            .onChange(of: tripDate) { _, d in
                                if tripEndDate <= d { tripEndDate = d.addingTimeInterval(3600) }
                            }
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
                    Text("After saving, you can add items to this trip in the Grocery tab.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(editing == nil ? "New shopping trip" : "Edit trip")
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
        let resolvedDate: Date? = hasDate ? (hasTime ? tripDate : Calendar.current.startOfDay(for: tripDate)) : nil
        let resolvedEnd: Date? = (hasDate && hasTime) ? tripEndDate : nil

        if let existing = editing {
            existing.task = name.trimmingCharacters(in: .whitespaces)
            existing.dueDate = resolvedDate
            existing.endDate = resolvedEnd
            try? moc.save()
            Task { await NotificationsManager.scheduleNow(for: existing) }
        } else {
            let trip = TaskItem(
                context: moc,
                task: name.trimmingCharacters(in: .whitespaces),
                dueDate: resolvedDate,
                category: "groceries",
                points: -1, // container sentinel — see TaskItem.isContainer
                createdBy: userName.trimmingCharacters(in: .whitespaces)
            )
            trip.endDate = resolvedEnd
            if let h = households.preferredTarget {
                moc.assign(trip, toStoreOf: h)
                trip.household = h
            }
            try? moc.save()
            Task { await NotificationsManager.scheduleNow(for: trip) }
        }
        dismiss()
    }
}
