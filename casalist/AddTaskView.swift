import SwiftUI
import CoreData

struct AddTaskView: View {
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName: String = ""
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)])
    private var members: FetchedResults<FamilyMember>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)])
    private var households: FetchedResults<Household>

    @State private var taskName = ""
    @State private var assigneeName: String = ""
    @State private var category: String
    @State private var dueDate = Date()
    @State private var hasDueDate: Bool = true
    @State private var points: Int = 10
    @State private var repeatKind: String = ""

    private let repeatOptions: [(label: String, kind: String)] = [
        ("None",     ""),
        ("Daily",    "daily"),
        ("Weekly",   "weekly"),
        ("Monthly",  "monthly"),
        ("Yearly",   "yearly"),
    ]

    init(defaultCategory: String = "Chores") {
        _category = State(initialValue: defaultCategory)
        _points = State(initialValue: (defaultCategory == "kitchen" || defaultCategory == "groceries") ? 0 : 10)
    }

    private var isPointless: Bool {
        category.lowercased() == "kitchen" || category.lowercased() == "groceries"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("What needs to be done?", text: $taskName)
                        .textInputAutocapitalization(.sentences)
                }

                Section("Assignee") {
                    if members.isEmpty {
                        TextField("Name", text: $assigneeName)
                    } else {
                        Picker("Family member", selection: $assigneeName) {
                            Text("No one").tag("")
                            ForEach(members, id: \.uid) { m in
                                Text(m.name).tag(m.name)
                            }
                        }
                    }
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        Text("Chores").tag("Chores")
                        Text("Kitchen").tag("kitchen")
                        Text("Groceries").tag("groceries")
                        Text("Maintenance").tag("Maintenance")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: category) { _, new in
                        if new.lowercased() == "kitchen" || new.lowercased() == "groceries" {
                            points = 0
                        } else if points == 0 {
                            points = 10
                        }
                    }
                }

                if !isPointless {
                    Section("Points") {
                        Stepper(value: $points, in: 0...500, step: 5) {
                            Text("\(points) pts")
                        }
                    }
                }

                Section("When") {
                    Toggle("Has a due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate)
                    }
                }

                Section("Repeat") {
                    Picker("Repeat", selection: $repeatKind) {
                        ForEach(repeatOptions, id: \.kind) { o in
                            Text(o.label).tag(o.kind)
                        }
                    }
                    if !repeatKind.isEmpty {
                        Text(repeatFooter).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveTask)
                        .disabled(taskName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var repeatFooter: String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d 'at' h:mm a"
        let dateStr = f.string(from: dueDate)
        switch repeatKind {
        case "daily":   return "Repeats every day. Completing rolls forward by one day."
        case "weekly":  return "Repeats every week on this weekday. Completing rolls forward 7 days."
        case "monthly": return "Repeats monthly. Completing rolls forward one month from \(dateStr)."
        case "yearly":  return "Repeats every year. Completing rolls forward one year."
        default: return ""
        }
    }

    private func saveTask() {
        let newTask = TaskItem(
            context: moc,
            task: taskName.trimmingCharacters(in: .whitespaces),
            assignee: assigneeName.isEmpty ? nil : assigneeName,
            dueDate: hasDueDate ? dueDate : nil,
            category: category,
            isCompleted: false,
            points: isPointless ? 0 : points,
            createdBy: userName.trimmingCharacters(in: .whitespaces),
            repeatHours: 0,
            repeatKind: repeatKind
        )
        if let h = households.first {
            moc.assign(newTask, toStoreOf: h)
            newTask.household = h
        }
        try? moc.save()
        Task { await NotificationsManager.scheduleNow(for: newTask) }
        dismiss()
    }
}
