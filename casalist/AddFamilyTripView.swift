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
    /// When ON and a date is set, the outing also creates a paired
    /// FamilyEvent so it shows on the Schedule tab (and flows through
    /// CalendarLinkService to Apple Calendar if a calendar is linked).
    @State private var addToSchedule: Bool = true

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
                        // Start day. End day independently so outings can span
                        // multiple days (weekend trips, camping, etc.).
                        DatePicker("Starts", selection: $tripDate, displayedComponents: .date)
                            .onChange(of: tripDate) { _, d in
                                if tripEndDate < d { tripEndDate = d }
                            }
                        DatePicker("Ends", selection: $tripEndDate, in: tripDate..., displayedComponents: .date)
                        Toggle("Specific time", isOn: $hasTime.animation())
                            .onChange(of: hasTime) { _, on in
                                if !on {
                                    tripDate = Calendar.current.startOfDay(for: tripDate)
                                    tripEndDate = Calendar.current.startOfDay(for: tripEndDate)
                                } else {
                                    // Default to 9 AM start, 1 hour later on the same day.
                                    let cal = Calendar.current
                                    tripDate = cal.date(bySettingHour: 9, minute: 0, second: 0, of: tripDate) ?? tripDate
                                    if tripEndDate < tripDate.addingTimeInterval(3600) {
                                        tripEndDate = tripDate.addingTimeInterval(3600)
                                    }
                                }
                            }
                        if hasTime {
                            DatePicker("Start time", selection: $tripDate, displayedComponents: .hourAndMinute)
                                .onChange(of: tripDate) { _, d in
                                    if tripEndDate <= d { tripEndDate = d.addingTimeInterval(3600) }
                                }
                            DatePicker("End time", selection: $tripEndDate, in: tripDate..., displayedComponents: .hourAndMinute)
                        }
                    }
                }
                if hasDate {
                    Section {
                        Toggle("Add to Schedule", isOn: $addToSchedule)
                    } footer: {
                        Text("Also creates a calendar event so the outing shows on the Schedule tab and (if you've linked one) syncs to Apple Calendar.")
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
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedUser = userName.trimmingCharacters(in: .whitespaces)
        let cal = Calendar.current
        // Normalize start/end. For all-day outings, anchor on startOfDay so
        // a multi-day all-day outing reads correctly downstream.
        let startResolved = hasDate
            ? (hasTime ? tripDate : cal.startOfDay(for: tripDate))
            : nil
        let endResolved: Date? = {
            guard hasDate else { return nil }
            if hasTime { return tripEndDate }
            // All-day end: keep only when it spans multiple days, otherwise nil.
            return cal.isDate(tripEndDate, inSameDayAs: tripDate)
                ? nil
                : cal.startOfDay(for: tripEndDate)
        }()
        let trip = TaskItem(
            context: moc,
            task: trimmedName,
            dueDate: startResolved,
            category: "family",
            points: -1, // container sentinel — see TaskItem.isContainer
            createdBy: trimmedUser
        )
        trip.endDate = endResolved
        let household = households.preferredTarget
        if let h = household {
            moc.assign(trip, toStoreOf: h)
            trip.household = h
        }

        // Pair-create a FamilyEvent so the outing shows on the Schedule
        // tab and flows through CalendarLinkService to Apple Calendar.
        // The event's notes carry a sentinel tag linking back to the
        // outing's TaskItem.uid — no schema change required.
        var pairedEvent: FamilyEvent?
        if hasDate && addToSchedule {
            let isAllDay = !hasTime
            let start = startResolved ?? tripDate
            let event = FamilyEvent(
                context: moc,
                title: trimmedName,
                startDate: start,
                isAllDay: isAllDay,
                location: "",
                attendees: "",
                notes: "casalist-outing-uid:\(trip.uid)",
                repeatKind: "",
                createdBy: trimmedUser,
                notifyMode: "household"
            )
            // Multi-day spans: set endDate even for all-day so the Schedule
            // tab and Apple Calendar show the full range. Single-day all-day
            // leaves endDate nil (legacy single-day behavior).
            event.endDate = endResolved
            event.announceHousehold = true
            if let h = household {
                moc.assign(event, toStoreOf: h)
                event.household = h
            }
            pairedEvent = event
        }

        try? moc.save()
        Task { await NotificationsManager.scheduleNow(for: trip) }
        if let pairedEvent {
            Task { await NotificationsManager.scheduleEvent(for: pairedEvent) }
            CalendarLinkService.shared.mirror(pairedEvent)
        }
        dismiss()
    }
}
