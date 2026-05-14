import SwiftUI
import CoreData

struct AddEventView: View {
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName: String = ""
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)])
    private var members: FetchedResults<FamilyMember>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)])
    private var households: FetchedResults<Household>

    private let editing: FamilyEvent?

    @State private var title: String
    @State private var startDate: Date
    @State private var isAllDay: Bool
    @State private var location: String
    @State private var attendees: String
    @State private var notes: String
    @State private var repeatKind: String
    @State private var confirmDelete: Bool = false

    init(editing: FamilyEvent? = nil) {
        self.editing = editing
        _title = State(initialValue: editing?.title ?? "")
        _startDate = State(initialValue: editing?.startDate ?? Date())
        _isAllDay = State(initialValue: editing?.isAllDay ?? false)
        _location = State(initialValue: editing?.location ?? "")
        _attendees = State(initialValue: editing?.attendees ?? "")
        _notes = State(initialValue: editing?.notes ?? "")
        _repeatKind = State(initialValue: editing?.repeatKind ?? "")
    }

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
                    Toggle("All-day", isOn: $isAllDay)
                    DatePicker(
                        "Start",
                        selection: $startDate,
                        displayedComponents: isAllDay ? .date : [.date, .hourAndMinute]
                    )
                }
                Section("Repeat") {
                    Picker("Repeat", selection: $repeatKind) {
                        ForEach(repeatOptions, id: \.kind) { o in
                            Text(o.label).tag(o.kind)
                        }
                    }
                }
                Section("Where") {
                    TextField("Location (optional)", text: $location)
                        .textInputAutocapitalization(.words)
                }
                Section("Who") {
                    if members.isEmpty {
                        TextField("Whose event? (optional)", text: $attendees)
                    } else {
                        Picker("Attendees", selection: $attendees) {
                            Text("Everyone").tag("")
                            ForEach(members, id: \.uid) { m in
                                Text(m.name).tag(m.name)
                            }
                        }
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
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        if let editing {
            editing.title = trimmedTitle
            editing.startDate = startDate
            editing.isAllDay = isAllDay
            editing.location = location.trimmingCharacters(in: .whitespaces)
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
            event.household = households.first
        }
        try? moc.save()
        dismiss()
    }

    private func delete() {
        if let editing {
            moc.delete(editing)
            try? moc.save()
            dismiss()
        }
    }
}
