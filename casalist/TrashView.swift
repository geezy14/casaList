import SwiftUI
import CoreData

/// The "trash bin" — surfaces soft-deleted FamilyMember / TaskItem /
/// FamilyGoal / FamilyEvent / Household records with a per-row Restore.
/// Records auto-purge after Trash.retentionDays (30 days).
struct TrashView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.colorScheme) private var sys

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: false)],
        predicate: NSPredicate(format: "deletedAt != nil")
    ) private var deletedMembers: FetchedResults<FamilyMember>
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: false)],
        predicate: NSPredicate(format: "deletedAt != nil")
    ) private var deletedTasks: FetchedResults<TaskItem>
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FamilyGoal.createdAt, ascending: false)],
        predicate: NSPredicate(format: "deletedAt != nil")
    ) private var deletedGoals: FetchedResults<FamilyGoal>
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FamilyEvent.startDate, ascending: false)],
        predicate: NSPredicate(format: "deletedAt != nil")
    ) private var deletedEvents: FetchedResults<FamilyEvent>

    @State private var confirmEmpty: Bool = false

    private var P: CasalistCottage.Palette { CasalistCottage.Palette.resolve(sys == .dark) }

    private var totalCount: Int {
        deletedMembers.count + deletedTasks.count + deletedGoals.count + deletedEvents.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                P.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        hero
                        if totalCount == 0 {
                            empty
                        } else {
                            section("FAMILY MEMBERS", items: Array(deletedMembers)) { m in
                                row(title: m.name, subtitle: "\(m.points) pts · \(m.role.isEmpty ? "Member" : m.role)", deletedAt: m.deletedAt) {
                                    m.restore()
                                    try? moc.save()
                                }
                            }
                            section("TASKS", items: Array(deletedTasks)) { t in
                                row(title: t.task, subtitle: "\(t.assignee ?? "Unassigned") · \(t.category)", deletedAt: t.deletedAt) {
                                    t.restore()
                                    try? moc.save()
                                }
                            }
                            section("GOALS", items: Array(deletedGoals)) { g in
                                row(title: g.label, subtitle: "\(g.ownerName) · \(g.targetPoints) pts", deletedAt: g.deletedAt) {
                                    g.restore()
                                    try? moc.save()
                                }
                            }
                            section("EVENTS", items: Array(deletedEvents)) { e in
                                row(title: e.title, subtitle: e.location.isEmpty ? "" : e.location, deletedAt: e.deletedAt) {
                                    e.restore()
                                    try? moc.save()
                                }
                            }
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
            .foregroundStyle(P.text)
            .navigationTitle("Trash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                if totalCount > 0 {
                    ToolbarItem(placement: .primaryAction) {
                        Button(role: .destructive) { confirmEmpty = true } label: {
                            Text("Empty").foregroundStyle(.red)
                        }
                    }
                }
            }
            .confirmationDialog("Empty Trash permanently?", isPresented: $confirmEmpty, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) { emptyTrash() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes \(totalCount) record\(totalCount == 1 ? "" : "s"). Cannot be undone.")
            }
        }
    }

    private var hero: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.white.opacity(0.22)).frame(width: 60, height: 60)
                Image(systemName: "trash.fill").font(.system(size: 24)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("RECENTLY DELETED").font(.system(size: 11, weight: .heavy)).tracking(0.8).opacity(0.85)
                Text("\(totalCount) item\(totalCount == 1 ? "" : "s")").font(.system(size: 22, weight: .heavy))
                Text("Auto-removed after \(Trash.retentionDays) days").font(.system(size: 11, weight: .semibold)).opacity(0.85)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white).padding(18)
        .background(P.coral)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Text("🗑️").font(.system(size: 44))
            Text("Trash is empty").font(.system(size: 16, weight: .heavy))
            Text("Deleted things go here for \(Trash.retentionDays) days before being removed for good.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(P.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(28)
        .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
    }

    @ViewBuilder
    private func section<T: Hashable, RowContent: View>(_ title: String, items: [T], @ViewBuilder row: @escaping (T) -> RowContent) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 11, weight: .heavy)).tracking(1.4).foregroundStyle(P.textDim).padding(.leading, 4)
                VStack(spacing: 6) {
                    ForEach(items, id: \.self) { item in
                        row(item)
                    }
                }
            }
        }
    }

    private func row(title: String, subtitle: String, deletedAt: Date?, onRestore: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .heavy)).lineLimit(1)
                HStack(spacing: 6) {
                    if !subtitle.isEmpty {
                        Text(subtitle).font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted).lineLimit(1)
                    }
                    if let d = deletedAt {
                        if !subtitle.isEmpty { Text("·").foregroundStyle(P.textMuted) }
                        Text("deleted \(d, style: .relative) ago").font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted)
                    }
                }
            }
            Spacer()
            Button {
                onRestore()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                    Text("Restore")
                }
                .font(.system(size: 12, weight: .heavy)).foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Capsule().fill(P.mint))
            }.buttonStyle(.row)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(P.surface))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(P.border, lineWidth: 1))
    }

    private func emptyTrash() {
        for m in deletedMembers { moc.delete(m) }
        for t in deletedTasks { moc.delete(t) }
        for g in deletedGoals { moc.delete(g) }
        for e in deletedEvents { moc.delete(e) }
        try? moc.save()
    }
}
