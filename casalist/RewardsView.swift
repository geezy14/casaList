import SwiftUI
import CoreData

struct RewardsView: View {
    @Environment(\.managedObjectContext) private var moc
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: true)],
        predicate: NSPredicate(format: "isCompleted == YES")
    ) private var completedTasks: FetchedResults<TaskItem>

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Leaderboard")) {
                    ForEach(groupedPoints().sorted(by: { $0.value > $1.value }), id: \.key) { assignee, points in
                        HStack {
                            Text(assignee.isEmpty ? "Unassigned" : assignee)
                                .font(.headline)
                            Spacer()
                            Text("\(points) pts")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.purple)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Chore Rewards")
        }
    }

    private func groupedPoints() -> [String: Int] {
        var totals: [String: Int] = [:]
        for task in completedTasks {
            let name = task.assignee ?? "Unassigned"
            totals[name, default: 0] += Int(task.points)
        }
        return totals
    }
}
