import SwiftUI
import CoreData

/// Sheet that opens when you tap a chore in the dashboard's agenda strip
/// (or any other "show me this task" entry point). Shows the task's name,
/// assignee, due date, category, points, and a recurring badge — with quick
/// actions to complete, edit (owner/admin), or delete (owner/admin or
/// assignee).
struct TaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.colorScheme) private var sys
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("meUid") private var meUid: String = ""

    let task: TaskItem

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var members: FetchedResults<FamilyMember>

    @State private var editing: Bool = false
    @State private var editName: String = ""
    @State private var editAssignee: String = ""
    @State private var editCategory: String = "Chores"
    @State private var editPoints: Int = 10
    @State private var editDueDate: Date = Date()
    @State private var editHasDueDate: Bool = true
    @State private var confirmDelete: Bool = false
    @State private var celebrate: Bool = false
    @State private var celebrateLabel: String = ""

    private var P: CasalistCottage.Palette { CasalistCottage.Palette.resolve(sys == .dark) }

    private var me: FamilyMember? {
        FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)
    }
    private var iAmAdmin: Bool { me?.canManageFamily ?? false }
    private var isMine: Bool {
        let lc = (me?.name ?? userName).trimmingCharacters(in: .whitespaces).lowercased()
        return (task.assignee ?? "").lowercased() == lc
    }
    /// True when this user created the task (added it themselves).
    private var iAddedIt: Bool {
        let lc = (me?.name ?? userName).trimmingCharacters(in: .whitespaces).lowercased()
        return task.createdBy.lowercased() == lc
    }
    /// Owners + admins can delete anything. Standard members and kids
    /// can only delete what they added themselves.
    private var canDelete: Bool { iAmAdmin || iAddedIt }
    /// Trip-style containers (family-category items with a dueDate and
    /// no parent) aren't claimable — they're outings, not chores.
    private var isTripContainer: Bool {
        task.category.lowercased() == "family"
            && task.dueDate != nil
            && task.parentUid.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                P.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        header
                        if editing && iAmAdmin {
                            editForm
                        } else {
                            infoCard
                        }
                        actions
                        Spacer(minLength: 30)
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
            .foregroundStyle(P.text)
            .navigationTitle(task.task)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(editing ? "Cancel" : "Done") {
                        if editing { editing = false } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if iAmAdmin {
                        if editing {
                            Button("Save", action: saveEdits)
                                .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty)
                        } else {
                            Button("Edit") { startEditing() }
                        }
                    }
                }
            }
            .celebration(visible: $celebrate, label: celebrateLabel)
            .confirmationDialog("Delete this task?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    task.softDelete()
                    try? moc.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Removes \"\(task.task)\" for everyone.")
            }
        }
    }

    // MARK: – Display

    private var header: some View {
        VStack(spacing: 8) {
            Text(categoryEmoji(task.category)).font(.system(size: 40))
            Text(task.task).font(.system(size: 22, weight: .heavy)).multilineTextAlignment(.center)
            HStack(spacing: 8) {
                if task.points > 0 {
                    Text("⭐ \(task.points) pts")
                        .font(.system(size: 12, weight: .heavy))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(P.butter))
                        .foregroundStyle(.white)
                }
                if canClaim {
                    Button(action: claim) {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.raised.fill").font(.system(size: 10, weight: .heavy))
                            Text("Claim").font(.system(size: 12, weight: .heavy))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(P.mint))
                        .foregroundStyle(.white)
                    }.buttonStyle(.row)
                }
            }
        }
        .frame(maxWidth: .infinity).padding(24)
        .background(RoundedRectangle(cornerRadius: 24).fill(P.surfaceAlt))
    }

    /// True when the task is unassigned (or assigned to nobody) AND the
    /// current user has a FamilyMember record to claim it for.
    private var canClaim: Bool {
        guard !task.isCompleted else { return false }
        guard !isTripContainer else { return false }
        // Nested items belong collectively to their outing — no
        // individual claim, the family works the outing together.
        guard task.parentUid.isEmpty else { return false }
        let isUnassigned = (task.assignee ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        guard isUnassigned else { return false }
        return FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid) != nil
    }

    private func claim() {
        guard let me = FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid) else { return }
        task.assignee = me.name
        try? moc.save()
    }

    private var infoCard: some View {
        VStack(spacing: 0) {
            row(label: "Assigned to", value: task.assignee?.isEmpty == false ? task.assignee! : "Unassigned",
                tint: task.assignee?.isEmpty == false ? P.peach : P.textMuted)
            divider
            row(label: "Category", value: task.category.capitalized, tint: P.sky)
            divider
            row(label: "Due", value: dueText, tint: dueOverdue ? .red : P.text)
            if !task.effectiveRepeatKind.isEmpty {
                divider
                row(label: "Repeats", value: task.effectiveRepeatKind.capitalized, tint: P.lavender)
            }
            if !task.createdBy.isEmpty {
                divider
                row(label: "Added by", value: task.createdBy, tint: P.textMuted)
            }
            divider
            row(label: "Status", value: task.isCompleted ? "Completed" : "Open",
                tint: task.isCompleted ? P.mint : P.peach)
        }
        .background(RoundedRectangle(cornerRadius: 20).fill(P.surface))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(P.border, lineWidth: 1.5))
    }

    private func row(label: String, value: String, tint: Color) -> some View {
        HStack {
            Text(label).font(.system(size: 13, weight: .semibold)).foregroundStyle(P.textMuted)
            Spacer()
            Text(value).font(.system(size: 14, weight: .heavy)).foregroundStyle(tint)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
    private var divider: some View { Rectangle().fill(P.border).frame(height: 1) }

    private var dueText: String {
        guard let d = task.dueDate else { return "No due date" }
        let f = DateFormatter()
        f.dateFormat = Calendar.current.isDateInToday(d) ? "'Today' h:mm a" : "EEE MMM d 'at' h:mm a"
        return f.string(from: d)
    }
    private var dueOverdue: Bool {
        guard !task.isCompleted, let d = task.dueDate else { return false }
        return d < Date()
    }

    // MARK: – Actions

    private var actions: some View {
        VStack(spacing: 10) {
            if isMine || iAmAdmin {
                Button {
                    let willComplete = !task.isCompleted
                    let pts = Int(task.points)
                    FamilyPoints.toggle(task, in: members)
                    try? moc.save()
                    if willComplete {
                        celebrateLabel = pts > 0 ? "+\(pts) pts!" : "Done!"
                        celebrate = true
                        // Let the burst play before dismissing the sheet.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            dismiss()
                        }
                    } else {
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
                        Text(task.isCompleted ? "Mark not done" : "Mark done").font(.system(size: 14, weight: .heavy))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Capsule().fill(task.isCompleted ? P.surfaceAlt : P.mint))
                    .foregroundStyle(task.isCompleted ? P.text : .white)
                }.buttonStyle(.row)
            }
            if canDelete {
                Button(role: .destructive) { confirmDelete = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                        Text("Delete").font(.system(size: 14, weight: .heavy))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Capsule().fill(Color.red.opacity(0.85)))
                    .foregroundStyle(.white)
                }.buttonStyle(.row)
            }
        }
    }

    // MARK: – Edit form

    private var editForm: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                fieldRow("Name") {
                    TextField("Name", text: $editName)
                        .textInputAutocapitalization(.sentences)
                        .multilineTextAlignment(.trailing)
                }
                divider
                fieldRow("Assigned to") {
                    Picker("", selection: $editAssignee) {
                        Text("No one").tag("")
                        ForEach(members, id: \.uid) { m in
                            Text(m.name).tag(m.name)
                        }
                    }.pickerStyle(.menu).labelsHidden()
                }
                divider
                fieldRow("Category") {
                    Picker("", selection: $editCategory) {
                        Text("Chores").tag("Chores")
                        Text("Home").tag("home")
                        Text("Maintenance").tag("Maintenance")
                        Text("Family").tag("family")
                    }.pickerStyle(.menu).labelsHidden()
                }
                divider
                fieldRow("Points") {
                    Stepper(value: $editPoints, in: 0...500, step: 5) {
                        Text("\(editPoints) pts").font(.system(size: 14, weight: .heavy))
                    }
                }
                divider
                fieldRow("Has due date") {
                    Toggle("", isOn: $editHasDueDate).labelsHidden().tint(P.peach)
                }
                if editHasDueDate {
                    divider
                    fieldRow("Due") {
                        DatePicker("", selection: $editDueDate).labelsHidden()
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 20).fill(P.surface))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(P.border, lineWidth: 1.5))
        }
    }

    private func fieldRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label).font(.system(size: 13, weight: .semibold)).foregroundStyle(P.textMuted)
            Spacer()
            content()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func startEditing() {
        editName = task.task
        editAssignee = task.assignee ?? ""
        editCategory = task.category
        editPoints = Int(task.points)
        editHasDueDate = task.dueDate != nil
        editDueDate = task.dueDate ?? Date()
        editing = true
    }

    private func saveEdits() {
        task.task = editName.trimmingCharacters(in: .whitespaces)
        task.assignee = editAssignee.isEmpty ? nil : editAssignee
        task.category = editCategory
        task.points = Int64(editPoints)
        task.dueDate = editHasDueDate ? editDueDate : nil
        try? moc.save()
        editing = false
    }

    private func categoryEmoji(_ c: String) -> String {
        switch c.lowercased() {
        case "chores":      return "🧹"
        case "home":        return "🏠"
        case "groceries":   return "🛒"
        case "maintenance": return "🔧"
        case "reminders":   return "📌"
        case "family":      return "🪴"
        default:            return "✏️"
        }
    }
}
