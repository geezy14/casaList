import SwiftUI
import SwiftData

struct RewardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TaskItem> { task in
        task.isCompleted == true
    }) private var completedTasks: [TaskItem]

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
    
    // Helper function to sum points by person
    private func groupedPoints() -> [String: Int] {
        var totals: [String: Int] = [:]
        
        for task in completedTasks {
            let name = task.assignee ?? "Unassigned"
            totals[name, default: 0] += task.points
        }
        
        return totals
    }
}
