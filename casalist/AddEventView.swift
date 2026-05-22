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
    /// Audience for the event's notification: "household" (everyone),
    /// "admins" (parents only), or "attendee" (just the named person).
    @State private var notifyMode: String
    @State private var notes: String
    @State private var repeatKind: String
    @State private var confirmDelete: Bool = false
    /// Re-entry guard. A fast double-tap on the Save button used to
    /// insert two FamilyEvent rows with two distinct uids — the user
    /// got two identical pushes when the event fired. Block re-entry.
    @State private var isSaving: Bool = false
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
        // Legacy events (no notifyMode) always notified everyone, so default
        // to "household". Honor an explicit stored mode otherwise.
        let storedMode = (editing?.notifyMode ?? "").lowercased()
        _notifyMode = State(initialValue: storedMode.isEmpty ? "household" : storedMode)
        _notes = State(initialValue: editing?.notes ?? "")
        _repeatKind = State(initialValue: editing?.repeatKind ?? "")
    }

    private var hasCoordinates: Bool { latitude != 0 || longitude != 0 }

    /// One-line explainer under the Notify picker.
    private var notifyHint: String {
        switch notifyMode {
        case "admins":
            return "Only admins (parents) get notified."
        case "attendee":
            return attendees.isEmpty
                ? "Notifies the whole household."
                : "Only \(attendees) (and admins) get notified."
        default:
            return "Everyone in the household gets notified."
        }
    }

    private let repeatOptions: [(label: String, kind: String)] = [
        ("None",          ""),
        ("Daily",         "daily"),
        ("Weekdays only", "weekdays"),
        ("Weekly",        "weekly"),
        ("Monthly",       "monthly"),
        ("Yearly",        "yearly"),
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
                        // For recurring events the date pickers always
                        // edit the SERIES root, not the occurrence the
                        // user tapped. Label them accordingly so
                        // "tap May 19, see May 18" stops being a wat.
                        repeatKind.isEmpty ? "Starts" : "Series starts",
                        selection: $startDate,
                        displayedComponents: isAllDay ? .date : [.date, .hourAndMinute]
                    )
                    .onChange(of: startDate) { _, newStart in
                        if endDate <= newStart { endDate = newStart.addingTimeInterval(3600) }
                    }
                    DatePicker(
                        repeatKind.isEmpty ? "Ends" : "First end",
                        selection: $endDate,
                        in: startDate...,
                        displayedComponents: isAllDay ? .date : [.date, .hourAndMinute]
                    )
                    if !repeatKind.isEmpty {
                        Label("Edits affect every occurrence.",
                              systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
                    // Who actually gets the notification (separate from the
                    // attendee label on the card). "Just <name>" only shows
                    // when a specific attendee is picked.
                    Picker(selection: $notifyMode) {
                        Label("Whole household", systemImage: "megaphone.fill").tag("household")
                        Label("Admins only", systemImage: "person.badge.key.fill").tag("admins")
                        if !attendees.isEmpty {
                            Label("Just \(attendees)", systemImage: "person.fill").tag("attendee")
                        }
                    } label: {
                        Label("Notify", systemImage: "bell.fill")
                    }
                    .onChange(of: attendees) { _, newValue in
                        // If the attendee is cleared, "Just <name>" is gone —
                        // fall back to notifying the whole household.
                        if newValue.isEmpty && notifyMode == "attendee" {
                            notifyMode = "household"
                        }
                    }
                    Label(notifyHint, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            // Each sheet on its own view host so stacked .sheet modifiers
            // don't make one flash open then dismiss instantly.
            .background(
                Color.clear.sheet(isPresented: $showLocationPicker) {
                    LocationPickerSheet { picked in
                        location = picked.displayName
                        latitude = picked.latitude
                        longitude = picked.longitude
                    }
                }
            )
            .background(
                Color.clear.sheet(isPresented: $showCustomRepeat) {
                    CustomRepeatPicker(encoded: $repeatKind)
                }
            )
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        // Normalize: "attendee" only valid when an attendee is set.
        let mode = (attendees.isEmpty && notifyMode == "attendee") ? "household" : notifyMode
        // Derive the legacy broadcast-wording flag from the audience: a
        // household event with a named attendee still pings everyone (📢)
        // but shows the attendee on the card.
        let announce = (mode == "household" && !attendees.isEmpty)
        if let editing {
            editing.title = trimmedTitle
            editing.startDate = startDate
            editing.endDate = isAllDay ? nil : endDate
            editing.isAllDay = isAllDay
            editing.location = location.trimmingCharacters(in: .whitespaces)
            editing.latitude = latitude
            editing.longitude = longitude
            editing.attendees = attendees
            editing.notifyMode = mode
            editing.announceHousehold = announce
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
                createdBy: userName.trimmingCharacters(in: .whitespaces),
                notifyMode: mode
            )
            event.latitude = latitude
            event.announceHousehold = announce
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
