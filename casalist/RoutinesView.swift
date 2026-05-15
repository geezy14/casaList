import SwiftUI
import CoreData

/// Manager UI for chore routines — list all routines, add new ones, tap to
/// spawn the tasks. Visible only to owner/admin (gated by caller).
struct RoutinesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var moc
    @AppStorage("userName") private var userName: String = ""

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)])
    private var households: FetchedResults<Household>

    @State private var routines: [ChoreRoutineTemplate] = ChoreRoutineStore.load()
    @State private var editing: ChoreRoutineTemplate? = nil
    @State private var showAdd: Bool = false
    @State private var spawning: ChoreRoutineTemplate? = nil
    @State private var lastMessage: String? = nil

    private var P: CasalistCottage.Palette { CasalistCottage.Palette.resolve(false) }

    var body: some View {
        NavigationStack {
            ZStack {
                P.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        if routines.isEmpty {
                            empty
                        } else {
                            ForEach(routines) { r in
                                routineCard(r)
                            }
                        }
                        if let lastMessage {
                            Text(lastMessage)
                                .font(.caption).foregroundStyle(P.peach)
                                .padding(.top, 8)
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Routines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddRoutineView(existing: nil) { saved in
                    if let s = saved {
                        routines.append(s)
                        ChoreRoutineStore.save(routines)
                    }
                }
            }
            .sheet(item: $editing) { r in
                AddRoutineView(existing: r) { saved in
                    if let s = saved, let idx = routines.firstIndex(where: { $0.id == r.id }) {
                        routines[idx] = s
                        ChoreRoutineStore.save(routines)
                    }
                }
            }
            .confirmationDialog(
                spawning.map { "Spawn \"\($0.name)\" for \($0.assigneeName)?" } ?? "",
                isPresented: Binding(
                    get: { spawning != nil },
                    set: { if !$0 { spawning = nil } }
                ),
                presenting: spawning
            ) { r in
                Button("Spawn for today") {
                    spawn(r, dueDate: Date())
                }
                Button("Spawn with no due date") {
                    spawn(r, dueDate: nil)
                }
                Button("Cancel", role: .cancel) {}
            } message: { r in
                Text("Creates \(r.items.count) task\(r.items.count == 1 ? "" : "s") worth \(r.totalPoints) pts total.")
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Text("⚡").font(.system(size: 44))
            Text("No routines yet").font(.system(size: 16, weight: .heavy))
            Text("Routines bundle a set of chores you assign together. Tap + to create one.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(P.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(24)
        .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
    }

    private func routineCard(_ r: ChoreRoutineTemplate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: r.symbol).font(.system(size: 20)).foregroundStyle(P.peach)
                    .frame(width: 44, height: 44).background(Circle().fill(P.peach.opacity(0.18)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.name).font(.system(size: 15, weight: .heavy))
                    Text("for \(r.assigneeName) · \(r.items.count) task\(r.items.count == 1 ? "" : "s") · \(r.totalPoints) pts")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textMuted)
                }
                Spacer()
                Menu {
                    Button { editing = r } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) {
                        routines.removeAll { $0.id == r.id }
                        ChoreRoutineStore.save(routines)
                    } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 14, weight: .heavy)).foregroundStyle(P.textMuted)
                        .frame(width: 30, height: 30)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(r.items) { it in
                    HStack {
                        Image(systemName: "circle").font(.system(size: 10)).foregroundStyle(P.textMuted)
                        Text(it.label).font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("\(it.points) pt").font(.system(size: 11, weight: .heavy)).foregroundStyle(P.peach)
                    }
                }
            }
            Button { spawning = r } label: {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars").font(.system(size: 12, weight: .heavy))
                    Text("Spawn now").font(.system(size: 13, weight: .heavy))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(Capsule().fill(P.peach))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(r.items.isEmpty)
            .padding(.top, 4)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
    }

    private func spawn(_ r: ChoreRoutineTemplate, dueDate: Date?) {
        let n = ChoreRoutineStore.spawn(
            r,
            creator: userName.trimmingCharacters(in: .whitespaces),
            dueDate: dueDate,
            in: moc,
            household: households.preferredTarget
        )
        lastMessage = "Spawned \(n) task\(n == 1 ? "" : "s") for \(r.assigneeName)."
    }
}

/// Create or edit a routine.
struct AddRoutineView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var sys
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)])
    private var members: FetchedResults<FamilyMember>

    let existing: ChoreRoutineTemplate?
    let onSave: (ChoreRoutineTemplate?) -> Void

    @State private var name: String = ""
    @State private var assignee: String = ""
    @State private var symbol: String = "sun.max.fill"
    @State private var items: [ChoreRoutineTemplate.Item] = []
    @State private var newItemLabel: String = ""
    @State private var newItemPoints: Int = 5

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && !assignee.isEmpty
        && !items.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Routine") {
                    TextField("Name (e.g. Morning Routine)", text: $name)
                        .textInputAutocapitalization(.words)
                    Picker("Icon", selection: $symbol) {
                        ForEach(RoutineSymbol.options, id: \.self) { s in
                            Label("", systemImage: s).tag(s)
                        }
                    }
                }
                Section("Assignee") {
                    if members.isEmpty {
                        Text("Add a family member first.").foregroundStyle(.secondary)
                    } else {
                        Picker("For", selection: $assignee) {
                            Text("Choose…").tag("")
                            ForEach(members, id: \.uid) { m in
                                Text(m.name).tag(m.name)
                            }
                        }
                    }
                }
                Section("Tasks (\(items.count))") {
                    ForEach(items) { it in
                        HStack {
                            Text(it.label)
                            Spacer()
                            Text("\(it.points) pt").foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { idx in items.remove(atOffsets: idx) }
                    HStack {
                        TextField("Task label", text: $newItemLabel)
                        Stepper("\(newItemPoints) pt", value: $newItemPoints, in: 0...500, step: 5)
                            .labelsHidden()
                        Text("\(newItemPoints)").frame(width: 30, alignment: .trailing)
                        Button {
                            let trimmed = newItemLabel.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            items.append(.init(label: trimmed, points: newItemPoints))
                            newItemLabel = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newItemLabel.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle(existing == nil ? "New routine" : "Edit routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onSave(nil); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let r = ChoreRoutineTemplate(
                            id: existing?.id ?? UUID(),
                            name: name.trimmingCharacters(in: .whitespaces),
                            assigneeName: assignee,
                            symbol: symbol,
                            items: items
                        )
                        onSave(r)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if let e = existing {
                    name = e.name
                    assignee = e.assigneeName
                    symbol = e.symbol
                    items = e.items
                }
            }
        }
    }
}
