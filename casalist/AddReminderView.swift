import SwiftUI
import CoreData

struct AddReminderView: View {
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName: String = ""
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var households: FetchedResults<Household>

    private let editing: TaskItem?

    @State private var title: String
    @State private var repeatKind: String
    @State private var hasFireDate: Bool
    @State private var fireDate: Date
    /// Cadence-only stop-time-of-day. Off by default. When on, hourly /
    /// every2h / every4h / every8h / every12h reminders only fire within
    /// [fireDate.timeOfDay, stopDate.timeOfDay] each day.
    @State private var hasStopTime: Bool
    @State private var stopDate: Date
    @State private var confirmDelete: Bool = false

    init(editing: TaskItem? = nil) {
        self.editing = editing
        if let t = editing {
            _title = State(initialValue: t.task)
            _repeatKind = State(initialValue: t.effectiveRepeatKind)
            _hasFireDate = State(initialValue: t.dueDate != nil)
            _fireDate = State(initialValue: t.dueDate ?? Date().addingTimeInterval(3600))
            let mins = Int(t.repeatEndMinutes)
            _hasStopTime = State(initialValue: mins > 0)
            // Reconstitute a Date for the picker from minutes-since-midnight.
            let cal = Calendar.current
            let baseToday = cal.startOfDay(for: Date())
            let stopAnchor = cal.date(byAdding: .minute, value: mins > 0 ? mins : 22 * 60, to: baseToday) ?? baseToday
            _stopDate = State(initialValue: stopAnchor)
        } else {
            _title = State(initialValue: "")
            _repeatKind = State(initialValue: "")
            _hasFireDate = State(initialValue: false)
            _fireDate = State(initialValue: Date().addingTimeInterval(3600))
            _hasStopTime = State(initialValue: false)
            let cal = Calendar.current
            _stopDate = State(initialValue: cal.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date())
        }
    }

    private var isCadenceKind: Bool {
        ["hourly", "every2h", "every4h", "every8h", "every12h"].contains(repeatKind)
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
                if isCadenceKind {
                    Section("Stop time (optional)") {
                        Toggle("Stop firing after a time", isOn: $hasStopTime)
                        if hasStopTime {
                            DatePicker("Stop at", selection: $stopDate, displayedComponents: .hourAndMinute)
                            Text("Notifications only fire between the start time and the stop time each day. Set stop > start (overnight ranges aren't supported yet).")
                                .font(.caption).foregroundStyle(.secondary)
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

    /// Stop time as minutes-since-midnight, or 0 when no stop time set or
    /// when the cadence doesn't support it. Validates start < stop; returns
    /// 0 (no-op) when the user inverted them.
    private var stopMinutesValue: Int64 {
        guard isCadenceKind, hasStopTime else { return 0 }
        let cal = Calendar.current
        let stopMin = cal.component(.hour, from: stopDate) * 60 + cal.component(.minute, from: stopDate)
        let startMin = cal.component(.hour, from: fireDate) * 60 + cal.component(.minute, from: fireDate)
        guard stopMin > startMin else { return 0 }
        return Int64(stopMin)
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
            editing.repeatEndMinutes = stopMinutesValue
            target = editing
        } else {
            let item = TaskItem(
                context: moc,
                task: trimmedTitle,
                dueDate: storeDate,
                category: "reminders",
                points: 0,
                createdBy: userName.trimmingCharacters(in: .whitespaces),
                repeatHours: 0,
                repeatKind: repeatKind
            )
            item.repeatEndMinutes = stopMinutesValue
            if let h = households.preferredTarget {
                moc.assign(item, toStoreOf: h)
                item.household = h
            }
            target = item
        }
        try? moc.save()
        Task { await NotificationsManager.scheduleNow(for: target) }
        dismiss()
    }

    private func deleteReminder() {
        if let editing {
            editing.softDelete()
            try? moc.save()
            let ctx = moc
            Task { await NotificationsManager.syncFromContext(ctx) }
            dismiss()
        }
    }
}
