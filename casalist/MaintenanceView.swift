import SwiftUI
import CoreData

struct MaintenanceView: View {
    @Environment(\.managedObjectContext) private var moc
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.task, ascending: true)],
        predicate: NSPredicate(format: "category == %@", "Maintenance")
    ) private var maintenanceTasks: FetchedResults<TaskItem>

    var body: some View {
        NavigationStack {
            List {
                ForEach(maintenanceTasks, id: \.uid) { task in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.task)
                                .font(.headline)
                            if let assignee = task.assignee, !assignee.isEmpty {
                                Text("Assignee: \(assignee)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Text(task.category)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Maintenance Tracker")
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                moc.delete(maintenanceTasks[index])
            }
            try? moc.save()
        }
    }
}
