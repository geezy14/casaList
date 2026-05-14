import SwiftUI
import SwiftData

struct AddReminderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName: String = ""

    private let editing: TaskItem?

    @State private var title: String
    @State private var repeatKind: String
    @State private var hasFireDate: Bool
    @State private var fireDate: Date
    @State private var confirmDelete: Bool = false

    init(editing: TaskItem? = nil) {
        self.editing = editing
        if let t = editing {
            _title = State(initialValue: t.task)
            _repeatKind = State(initialValue: t.effectiveRepeatKind)
            _hasFireDate = State(initialValue: t.dueDate != nil)
            _fireDate = State(initialValue: t.dueDate ?? Date().addingTimeInterval(3600))
        } else {
            _title = State(initialValue: "")
            _repeatKind = State(initialValue: "")
            _hasFireDate = State(initialValue: false)
            _fireDate = State(initialValue: Date().addingTimeInterval(3600))
        }
    }

    private let repeatOptions: [(label: String, kind: String)] = [
        ("None",          ""),
        ("Every hour",    "hourly"),
        ("Every 2 hours", "every2h"),
        ("Every 4 hours", "every4h"),
        ("Every 8 hours", "every8h"),
        ("Every 12 hours","every12h"),
        ("Daily",         "daily"),
        ("Weekly",        "weekly"),
        ("Monthly",       "monthly"),
        ("Yearly",        "yearly"),
    ]

    private var isPinned: Bool { repeatKind.isEmpty && !hasFireDate }
    private var showsDatePicker: Bool { !isPinned }
    private var dailyOnlyTime: Bool { repeatKind == "daily" }

    private var datePickerLabel: String {
        switch repeatKind {
        case "":         return "Remind me at"
        case "hourly":   return "Start at this minute"
        case "every2h", "every4h", "every8h", "every12h":
            return "Anchor day & time"
        case "daily":    return "Time of day"
        case "weekly":   return "First fire (sets weekday + time)"
        case "monthly":  return "First fire (sets day of month + time)"
        case "yearly":   return "First fire (sets month + day + time)"
        default:         return "Date & time"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reminder") {
                    TextField("What do you want to remember?", text: $title)
                        .textInputAutocapitalization(.sentences)
                }
                Section("Repeat") {
                    Picker("How often", selection: $repeatKind) {
                        ForEach(repeatOptions, id: \.kind) { o in
                            Text(o.label).tag(o.kind)
                        }
                    }
                    if repeatKind.isEmpty {
                        Toggle("Schedule a time", isOn: $hasFireDate)
                    }
                }
                if showsDatePicker {
                    Section(datePickerLabel) {
                        if dailyOnlyTime {
                            DatePicker("Time", selection: $fireDate, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                        } else {
                            DatePicker("Date", selection: $fireDate, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                            DatePicker("Time", selection: $fireDate, displayedComponents: .hourAndMinute)
                        }
                    }
                }
                Section {
                    Text(footerText).font(.caption).foregroundStyle(.secondary)
                }
                if editing != nil {
                    Section {
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Label("Delete reminder", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "New reminder" : "Edit reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog(
                "Delete reminder?",
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteReminder() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var footerText: String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d 'at' h:mm a"
        let dateStr = f.string(from: fireDate)
        switch repeatKind {
        case "":
            if hasFireDate { return "Fires once on \(dateStr)." }
            return "Pinned reminder — no notifications, just visible on Home."
        case "hourly":
            return "Fires every hour at minute \(Calendar.current.component(.minute, from: fireDate))."
        case "every2h":  return "Fires every 2 hours, anchored to the chosen time of day."
        case "every4h":  return "Fires every 4 hours, anchored to the chosen time of day."
        case "every8h":  return "Fires every 8 hours, anchored to the chosen time of day."
        case "every12h": return "Fires every 12 hours, anchored to the chosen time of day."
        case "daily":
            f.dateFormat = "h:mm a"
            return "Fires every day at \(f.string(from: fireDate))."
        case "weekly":
            f.dateFormat = "EEEE 'at' h:mm a"
            return "Fires every \(f.string(from: fireDate))."
        case "monthly":
            f.dateFormat = "h:mm a"
            let day = Calendar.current.component(.day, from: fireDate)
            return "Fires every month on day \(day) at \(f.string(from: fireDate))."
        case "yearly":
            f.dateFormat = "MMM d 'at' h:mm a"
            return "Fires every year on \(f.string(from: fireDate))."
        default: return ""
        }
    }

    private func save() {
        let storeDate: Date? = isPinned ? nil : fireDate
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let target: TaskItem
        if let editing {
            editing.task = trimmedTitle
            editing.dueDate = storeDate
            editing.repeatKind = repeatKind
            editing.repeatHours = 0
            target = editing
        } else {
            let item = TaskItem(
                task: trimmedTitle,
                dueDate: storeDate,
                category: "reminders",
                points: 0,
                createdBy: userName.trimmingCharacters(in: .whitespaces),
                repeatHours: 0,
                repeatKind: repeatKind
            )
            modelContext.insert(item)
            target = item
        }
        try? modelContext.save()
        Task { await NotificationsManager.scheduleNow(for: target) }
        dismiss()
    }

    private func deleteReminder() {
        if let editing {
            modelContext.delete(editing)
            let ctx = modelContext
            Task { await NotificationsManager.syncFromContext(ctx) }
            dismiss()
        }
    }
}
