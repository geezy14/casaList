import SwiftUI
import SwiftData

struct MyToDoView: View {
    let personName: String
    
    // Dynamically filters tasks for a specific person
    @Query private var tasks: [TaskItem]
    
    init(personName: String) {
        self.personName = personName
        // Sets up the filter for the specific assignee
        _tasks = Query(filter: #Predicate<TaskItem> { task in
            task.assignee == personName
        })
    }

    var body: some View {
        NavigationStack {
            List(tasks) { task in
                HStack {
                    Text(task.task)
                    Spacer()
                    Text("\(task.points) pts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("\(personName)'s Tasks")
        }
    }
}
