import SwiftUI
import CoreData
import MapKit

struct AddEventView: View {
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName: String = ""
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var members: FetchedResults<FamilyMember>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var households: FetchedResults<Household>

    private let editing: FamilyEvent?

    @State private var title: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay: Bool
    @State private var location: String
    @State private var latitude: Double
    @State private var longitude: Double
    @State private var attendees: String
    @State private var notes: String
    @State private var repeatKind: String
    @State private var confirmDelete: Bool = false
    @State private var showLocationPicker: Bool = false
    @State private var showCustomRepeat: Bool = false

    private var customRepeatRowLabel: String {
        if let rule = RepeatRule.decode(repeatKind) {
            return "Custom: \(rule.label)"
        }
        return "Custom…"
    }

    init(editing: FamilyEvent? = nil) {
        self.editing = editing
        _title = State(initialValue: editing?.title ?? "")
        _startDate = State(initialValue: editing?.startDate ?? Date())
        let start = editing?.startDate ?? Date()
        _endDate = State(initialValue: editing?.endDate ?? start.addingTimeInterval(3600))
        _isAllDay = State(initialValue: editing?.isAllDay ?? false)
        _location = State(initialValue: editing?.location ?? "")
        _latitude = State(initialValue: editing?.latitude ?? 0)
        _longitude = State(initialValue: editing?.longitude ?? 0)
        _attendees = State(initialValue: editing?.attendees ?? "")
        _notes = State(initialValue: editing?.notes ?? "")
        _repeatKind = State(initialValue: editing?.repeatKind ?? "")
    }

    private var hasCoordinates: Bool { latitude != 0 || longitude != 0 }

    private let repeatOptions: [(label: String, kind: String)] = [
        ("None",    ""),
        ("Daily",   "daily"),
        ("Weekly",  "weekly"),
        ("Monthly", "monthly"),
        ("Yearly",  "yearly"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    TextField("Soccer practice, dentist…", text: $title)
                        .textInputAutocapitalization(.sentences)
                }
                Section("When") {
                    Toggle("All-day", isOn: $isAllDay.animation())
                    DatePicker(
                        "Starts",
                        selection: $startDate,
                        displayedComponents: isAllDay ? .date : [.date, .hourAndMinute]
                    )
                    .onChange(of: startDate) { _, newStart in
                        if endDate <= newStart { endDate = newStart.addingTimeInterval(3600) }
                    }
                    DatePicker(
                        "Ends",
                        selection: $endDate,
                        in: startDate...,
                        displayedComponents: isAllDay ? .date : [.date, .hourAndMinute]
                    )
                }
                Section("Repeat") {
                    Picker("Repeat", selection: $repeatKind) {
                        ForEach(repeatOptions, id: \.kind) { o in
                            Text(o.label).tag(o.kind)
                        }
                        if let rule = RepeatRule.decode(repeatKind) {
                            Text(rule.label).tag(repeatKind)
                        }
                    }
                    Button {
                        showCustomRepeat = true
                    } label: {
                        Label(customRepeatRowLabel, systemImage: "slider.horizontal.3")
                            .foregroundStyle(.primary)
                    }
                }
                Section("Where") {
                    Button {
                        showLocationPicker = true
                    } label: {
                        HStack {
                            Image(systemName: hasCoordinates ? "mappin.circle.fill" : "mappin.circle")
                                .foregroundStyle(hasCoordinates ? .orange : .secondary)
                            if location.isEmpty {
                                Text("Pick a location").foregroundStyle(.secondary)
                            } else {
                                Text(location).foregroundStyle(.primary).lineLimit(1)
                            }
                            Spacer()
                            if !location.isEmpty {
                                Button {
                                    location = ""
                                    latitude = 0
                                    longitude = 0
                                } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                }
                                .buttonStyle(.row)
                            }
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary).font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .buttonStyle(.row)
                    if hasCoordinates {
                        LocationMiniMap(latitude: latitude, longitude: longitude, title: location)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    }
                }
                Section("Who") {
                    if members.isEmpty {
                        TextField("Whose event? (optional)", text: $attendees)
                    } else {
                        Picker(selection: $attendees) {
                            Label("Everyone", systemImage: "house.fill").tag("")
                            ForEach(members, id: \.uid) { m in
                                Label(m.name, systemImage: "person.fill").tag(m.name)
                            }
                        } label: {
                            Label("Attendees", systemImage: attendees.isEmpty ? "house.fill" : "person.fill")
                        }
                    }
                    if attendees.isEmpty {
                        Label("Notifies the whole household", systemImage: "megaphone.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                if editing != nil {
                    Section {
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Label("Delete event", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "New event" : "Edit event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Delete event?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { delete() }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerSheet { picked in
                    location = picked.displayName
                    latitude = picked.latitude
                    longitude = picked.longitude
                }
            }
            .sheet(isPresented: $showCustomRepeat) {
                CustomRepeatPicker(encoded: $repeatKind)
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        if let editing {
            editing.title = trimmedTitle
            editing.startDate = startDate
            editing.endDate = isAllDay ? nil : endDate
            editing.isAllDay = isAllDay
            editing.location = location.trimmingCharacters(in: .whitespaces)
            editing.latitude = latitude
            editing.longitude = longitude
            editing.attendees = attendees
            editing.notes = notes
            editing.repeatKind = repeatKind
        } else {
            let event = FamilyEvent(
                context: moc,
                title: trimmedTitle,
                startDate: startDate,
                isAllDay: isAllDay,
                location: location.trimmingCharacters(in: .whitespaces),
                attendees: attendees,
                notes: notes,
                repeatKind: repeatKind,
                createdBy: userName.trimmingCharacters(in: .whitespaces)
            )
            event.latitude = latitude
            event.longitude = longitude
            event.endDate = isAllDay ? nil : endDate
            if let h = households.preferredTarget {
                moc.assign(event, toStoreOf: h)
                event.household = h
            }
        }
        try? moc.save()
        // Schedule (or reschedule) the local push notification for this
        // event. Honors repeatKind so weekly events fire weekly, etc.
        let target = editing ?? households.preferredTarget?.events?.allObjects
            .compactMap { $0 as? FamilyEvent }
            .first { $0.title == trimmedTitle && $0.startDate == startDate }
        if let target {
            Task { await NotificationsManager.scheduleEvent(for: target) }
            // Mirror into the user's linked Apple Calendar (no-op when
            // nothing is linked or access wasn't granted). Per-device:
            // each device decides whether to mirror based on its own
            // CalendarLinkService.linkedCalendarID.
            CalendarLinkService.shared.mirror(target)
        }
        dismiss()
    }

    private func delete() {
        if let editing {
            Task { await NotificationsManager.cancelEvent(uid: editing.uid.uuidString) }
            CalendarLinkService.shared.unmirror(uid: editing.uid)
            editing.softDelete()
            try? moc.save()
            dismiss()
        }
    }
}
