import SwiftUI
import CoreData

/// Creator + editor for chore bundles. Pass `editing:` to update an
/// existing bundle in place; omit it for the standard creator flow.
struct AddChoreBundleView: View {
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName: String = ""
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)],
                  predicate: NSPredicate(format: "deletedAt == nil"))
    private var households: FetchedResults<Household>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)],
                  predicate: NSPredicate(format: "deletedAt == nil"))
    private var members: FetchedResults<FamilyMember>

    let editing: TaskItem?

    @State private var name: String
    @State private var assignee: String
    @State private var bonusPoints: Int
    @State private var category: String

    init(editing: TaskItem? = nil) {
        self.editing = editing
        if let editing {
            _name = State(initialValue: editing.task)
            _assignee = State(initialValue: editing.assignee ?? "")
            _bonusPoints = State(initialValue: Int(editing.points))
            _category = State(initialValue: editing.category.isEmpty ? "chores" : editing.category)
        } else {
            _name = State(initialValue: "")
            _assignee = State(initialValue: "")
            _bonusPoints = State(initialValue: 25)
            _category = State(initialValue: "chores")
        }
    }

    /// Built-in categories the bundle can live under. Mirrors the
    /// kindIcon mapping in CasalistCottage so the category change
    /// flows through to the dashboard tile + the bundle header icon.
    private let categoryOptions: [(label: String, value: String)] = [
        ("Chores", "chores"),
        ("Homework", "homework"),
        ("Home", "home"),
        ("Maintenance", "maintenance"),
        ("Family", "family"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Bundle name") {
                    TextField("Morning routine, Deep clean, Weekly chores...", text: $name)
                        .textInputAutocapitalization(.sentences)
                }
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(categoryOptions, id: \.value) { opt in
                            Text(opt.label).tag(opt.value)
                        }
                    }
                }
                Section("Assign to") {
                    Picker("Assignee", selection: $assignee) {
                        Text("Anyone").tag("")
                        ForEach(members, id: \.uid) { m in
                            Text(m.name).tag(m.name)
                        }
                    }
                }
                Section {
                    Stepper("Bonus: \(bonusPoints) pts", value: $bonusPoints, in: 0...500, step: 5)
                } header: {
                    Text("Completion bonus")
                } footer: {
                    Text("Awarded on top of individual chore points when all chores in the bundle are done.")
                }
                if editing == nil {
                    Section {
                        Text("After saving, add chores to this bundle from the task list.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(editing == nil ? "New chore bundle" : "Edit bundle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editing == nil ? "Save" : "Done", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedAssignee = assignee.trimmingCharacters(in: .whitespaces)
        if let bundle = editing {
            bundle.task = trimmedName
            bundle.assignee = trimmedAssignee.isEmpty ? nil : trimmedAssignee
            bundle.points = Int64(bonusPoints)
            bundle.category = category
            // Cascade the new category onto the bundle's children so
            // their card stripes + icons stay consistent with the
            // parent.
            let childReq = TaskItem.fetchRequest()
            childReq.predicate = NSPredicate(format: "parentUid == %@ AND deletedAt == nil", bundle.uid)
            if let children = try? moc.fetch(childReq) {
                for child in children {
                    child.category = category
                }
            }
        } else {
            let bundle = TaskItem(
                context: moc,
                task: trimmedName,
                dueDate: nil,
                category: category,
                points: bonusPoints,
                createdBy: userName.trimmingCharacters(in: .whitespaces)
            )
            bundle.repeatKind = "bundle"
            bundle.assignee = trimmedAssignee.isEmpty ? nil : trimmedAssignee
            if let h = households.preferredTarget {
                moc.assign(bundle, toStoreOf: h)
                bundle.household = h
            }
        }
        try? moc.save()
        dismiss()
    }
}
