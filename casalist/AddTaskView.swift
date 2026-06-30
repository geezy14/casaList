import SwiftUI
import CoreData

struct AddTaskView: View {
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("meUid") private var meUid: String = ""
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var members: FetchedResults<FamilyMember>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var households: FetchedResults<Household>

    private var me: FamilyMember? {
        FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)
    }
    private var canPickAnyAssignee: Bool { me?.canCreateTasksForOthers ?? true }

    @StateObject private var gameRules = GameRulesStore.shared

    @State private var taskName = ""
    @State private var assigneeName: String = ""
    @State private var category: String
    @State private var dueDate = Calendar.current.startOfDay(for: Date())
    @State private var hasDueDate: Bool = true
    @State private var hasTime: Bool = false
    @State private var points: Int = 10
    @State private var bonusPoints: Int = 0
    @State private var repeatKind: String = ""
    @State private var showCustomRepeat: Bool = false
    @State private var requiresProof: Bool = false

    /// Pretty label for the current `repeatKind`, matching the
    /// AddReminderView convention so the two screens read the same.
    private var repeatRowLabel: String {
        if repeatKind.isEmpty { return "Never" }
        if let rule = RepeatRule.decode(repeatKind) { return rule.label }
        if let rule = RepeatRule.fromLegacy(repeatKind) { return rule.label }
        return repeatKind.capitalized
    }

    // "task" or "bundle"
    @State private var mode: String

    // Bundle-specific fields
    @State private var bundleName: String = ""
    @State private var bundleAssignee: String = ""
    @State private var bundleBonus: Int = 25
    @State private var bundleCategory: String = "Chores"

    // Reminder-specific: notify routing ("" = everyone / member, "admins")
    @State private var reminderNotifyMode: String = ""

    init(defaultCategory: String = "Chores", startMode: String = "task") {
        _category = State(initialValue: defaultCategory)
        _points = State(initialValue: defaultCategory == "groceries" ? 0 : 10)
        _mode = State(initialValue: startMode)
    }

    private var isPointless: Bool {
        category.lowercased() == "groceries"
    }

    var body: some View {
        NavigationStack {
            Form {
                // Mode toggle — two pills at the very top
                Section {
                    HStack(spacing: 0) {
                        modeButton("New task",   value: "task")
                        modeButton("New bundle", value: "bundle")
                        modeButton("Reminder",   value: "reminder")
                    }
                    .padding(3)
                    .background(Capsule().fill(Color(.systemGray5)))
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                switch mode {
                case "bundle":   bundleForm
                case "reminder": reminderForm
                default:         taskForm
                }
            }
            .navigationTitle(mode == "task" ? "New task" : mode == "bundle" ? "New bundle" : "New reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    switch mode {
                    case "bundle":
                        Button("Save", action: saveBundle)
                            .disabled(bundleName.trimmingCharacters(in: .whitespaces).isEmpty)
                    case "reminder":
                        Button("Save", action: saveReminder)
                            .disabled(taskName.trimmingCharacters(in: .whitespaces).isEmpty)
                    default:
                        Button("Save", action: saveTask)
                            .disabled(taskName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            // Attach at the top level (not on a Section inside the
            // conditionally-rendered taskForm) — a Section anchor gets
            // re-identified when the Form re-renders, which dismissed the
            // sheet the instant it opened.
            .sheet(isPresented: $showCustomRepeat) {
                CustomRepeatPicker(encoded: $repeatKind)
            }
        }
    }

    @ViewBuilder private var taskForm: some View {
        Section("Task") {
            TextField("What needs to be done?", text: $taskName)
                .textInputAutocapitalization(.sentences)
        }
        Section("Assignee") {
            if members.isEmpty {
                TextField("Name", text: $assigneeName)
            } else if canPickAnyAssignee {
                Picker("Family member", selection: $assigneeName) {
                    Text("No one").tag("")
                    ForEach(members, id: \.uid) { m in Text(m.name).tag(m.name) }
                }
            } else {
                HStack {
                    Text("For"); Spacer()
                    Text(me?.name ?? userName).foregroundStyle(.secondary)
                }
            }
        }
        Section("Category") {
            Picker("Category", selection: $category) {
                ForEach(gameRules.rules.categoryRules) { rule in
                    Text("\(rule.emoji) \(rule.category)").tag(rule.category)
                }
                Text("🛒 Groceries").tag("groceries")
            }
            .pickerStyle(.menu)
            .onChange(of: category) { _, new in
                if new.lowercased() == "groceries" {
                    points = 0
                } else if let rule = gameRules.rule(for: new) {
                    points = rule.defaultPoints
                } else if points == 0 {
                    points = 10
                }
            }
        }
        if !isPointless {
            let lockedRule = gameRules.rule(for: category)
            let isPointLocked = lockedRule?.isLocked == true
            Section("Points") {
                HStack {
                    Stepper(value: $points, in: 0...500, step: 5) {
                        Text("\(points) pts")
                    }
                    .disabled(isPointLocked)
                    if isPointLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.orange.opacity(0.8))
                    }
                }
            }
            Section {
                Stepper(value: $bonusPoints, in: 0...500, step: 5) {
                    Text(bonusPoints > 0 ? "Bonus: \(bonusPoints) pts" : "Bonus: none")
                }
            } footer: {
                Text("Extra points awarded on top when this chore is completed.")
            }
            Section {
                Toggle("Requires photo proof", isOn: $requiresProof)
            } footer: {
                Text("Whoever completes this chore attaches a photo showing it's done. Admins see it in the chore detail.")
            }
        }
        Section("When") {
            HStack {
                Text("Date"); Spacer()
                if hasDueDate {
                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                        .datePickerStyle(.compact).labelsHidden()
                }
                Toggle("", isOn: $hasDueDate).labelsHidden()
                    .onChange(of: hasDueDate) { _, on in if !on { hasTime = false } }
            }
            if hasDueDate {
                HStack {
                    Text("Time").foregroundStyle(.secondary); Spacer()
                    if hasTime {
                        DatePicker("", selection: $dueDate, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact).labelsHidden()
                    }
                    Toggle("", isOn: $hasTime).labelsHidden()
                        .onChange(of: hasTime) { _, on in
                            if !on { dueDate = Calendar.current.startOfDay(for: dueDate) }
                            else if dueDate < Date() { dueDate = Date().addingTimeInterval(3600) }
                        }
                }
            }
        }
        Section("Repeat") {
            Button {
                showCustomRepeat = true
            } label: {
                HStack {
                    Text("Repeat").foregroundStyle(.primary)
                    Spacer()
                    Text(repeatRowLabel).foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            if !repeatKind.isEmpty {
                HStack {
                    Text(repeatFooter).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear") { repeatKind = "" }
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    /// Maps the Notify picker to (assignee + notifyMode), mirroring
    /// AddReminderView: "" = Everyone, "__admins__" = Admins only,
    /// "<name>" = that member.
    private var reminderNotifyBinding: Binding<String> {
        Binding(
            get: { reminderNotifyMode == "admins" ? "__admins__" : assigneeName },
            set: { v in
                if v == "__admins__" { assigneeName = ""; reminderNotifyMode = "admins" }
                else { assigneeName = v; reminderNotifyMode = "" }
            }
        )
    }

    @ViewBuilder private var reminderForm: some View {
        Section("Reminder") {
            TextField("What do you want to be reminded of?", text: $taskName)
                .textInputAutocapitalization(.sentences)
        }
        Section("Notify") {
            Picker("Notify", selection: reminderNotifyBinding) {
                Text("Everyone").tag("")
                Text("Admins only").tag("__admins__")
                ForEach(members, id: \.uid) { m in Text(m.name).tag(m.name) }
            }
            .pickerStyle(.menu)
        }
        Section {
            HStack {
                Text("Date"); Spacer()
                if hasDueDate {
                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                        .datePickerStyle(.compact).labelsHidden()
                }
                Toggle("", isOn: $hasDueDate).labelsHidden()
                    .onChange(of: hasDueDate) { _, on in if !on { hasTime = false } }
            }
            if hasDueDate {
                HStack {
                    Text("Time").foregroundStyle(.secondary); Spacer()
                    if hasTime {
                        DatePicker("", selection: $dueDate, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact).labelsHidden()
                    }
                    Toggle("", isOn: $hasTime).labelsHidden()
                        .onChange(of: hasTime) { _, on in
                            if !on { dueDate = Calendar.current.startOfDay(for: dueDate) }
                            else if dueDate < Date() { dueDate = Date().addingTimeInterval(3600) }
                        }
                }
            }
        } header: {
            Text("When")
        } footer: {
            Text(hasDueDate ? "Fires at the date/time set." : "No date — stays pinned in Reminders.")
        }
        Section("Repeat") {
            Button { showCustomRepeat = true } label: {
                HStack {
                    Text("Repeat").foregroundStyle(.primary)
                    Spacer()
                    Text(repeatRowLabel).foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            if !repeatKind.isEmpty {
                Button("Clear") { repeatKind = "" }
                    .font(.caption).foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder private var bundleForm: some View {
        Section("Bundle name") {
            TextField("Morning routine, Deep clean…", text: $bundleName)
                .textInputAutocapitalization(.sentences)
        }
        Section("Category") {
            Picker("Category", selection: $bundleCategory) {
                ForEach(gameRules.rules.categoryRules) { rule in
                    Text("\(rule.emoji) \(rule.category)").tag(rule.category)
                }
            }.pickerStyle(.menu)
        }
        Section("Assign to") {
            Picker("Assignee", selection: $bundleAssignee) {
                Text("Anyone").tag("")
                ForEach(members, id: \.uid) { m in Text(m.name).tag(m.name) }
            }
        }
        Section {
            Stepper("Bonus: \(bundleBonus) pts", value: $bundleBonus, in: 0...500, step: 5)
        } header: {
            Text("Completion bonus")
        } footer: {
            Text("Awarded on top of each chore's points when all chores are done. You'll add chores after saving.")
        }
    }

    private func modeButton(_ label: String, value: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { mode = value }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(mode == value ? Color(.systemBackground) : Color.clear)
                        .shadow(color: mode == value ? .black.opacity(0.15) : .clear, radius: 3, y: 1)
                )
                .foregroundStyle(mode == value ? .primary : .secondary)
        }
        .buttonStyle(.plain)
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

    private func saveBundle() {
        let bundle = TaskItem(
            context: moc,
            task: bundleName.trimmingCharacters(in: .whitespaces),
            dueDate: nil,
            category: bundleCategory,
            points: bundleBonus,
            createdBy: userName.trimmingCharacters(in: .whitespaces)
        )
        // "bundle-draft" = building state; appears in agenda until finalized
        bundle.repeatKind = "bundle-draft"
        bundle.assignee = bundleAssignee.isEmpty ? nil : bundleAssignee
        if let h = households.preferredTarget {
            moc.assign(bundle, toStoreOf: h)
            bundle.household = h
        }
        try? moc.save()
        dismiss()
    }

    private func saveReminder() {
        let trimmed = taskName.trimmingCharacters(in: .whitespaces)
        let item = TaskItem(
            context: moc,
            task: trimmed,
            assignee: assigneeName.isEmpty ? nil : assigneeName,
            dueDate: hasDueDate ? dueDate : nil,
            category: "reminders",
            isCompleted: false,
            points: 0,
            createdBy: userName.trimmingCharacters(in: .whitespaces),
            repeatHours: 0,
            repeatKind: repeatKind
        )
        item.notifyMode = reminderNotifyMode
        if let h = households.preferredTarget {
            moc.assign(item, toStoreOf: h)
            item.household = h
        }
        try? moc.save()
        Task { await NotificationsManager.scheduleNow(for: item) }
        dismiss()
    }

    private func saveTask() {
        // Force standard/kid creators to be the assignee.
        let resolvedAssignee: String
        if canPickAnyAssignee {
            resolvedAssignee = assigneeName
        } else {
            resolvedAssignee = (me?.name ?? userName).trimmingCharacters(in: .whitespaces)
        }
        let newTask = TaskItem(
            context: moc,
            task: taskName.trimmingCharacters(in: .whitespaces),
            assignee: resolvedAssignee.isEmpty ? nil : resolvedAssignee,
            dueDate: hasDueDate ? dueDate : nil,
            category: category,
            isCompleted: false,
            points: isPointless ? 0 : points,
            createdBy: userName.trimmingCharacters(in: .whitespaces),
            repeatHours: 0,
            repeatKind: repeatKind
        )
        newTask.bonusPoints = isPointless ? 0 : Int64(bonusPoints)
        newTask.requiresProof = isPointless ? false : requiresProof
        if let h = households.preferredTarget {
            moc.assign(newTask, toStoreOf: h)
            newTask.household = h
        }
        try? moc.save()
        Task { await NotificationsManager.scheduleNow(for: newTask) }
        QuickAddHistory.record(
            label: newTask.task,
            assignee: newTask.assignee,
            points: Int(newTask.points),
            category: newTask.category
        )
        dismiss()
    }
}
