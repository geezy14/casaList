import SwiftUI
import CoreData

struct MyToDoView: View {
    let personName: String
    @FetchRequest private var tasks: FetchedResults<TaskItem>

    init(personName: String) {
        self.personName = personName
        _tasks = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.dueDate, ascending: true)],
            predicate: NSPredicate(format: "assignee == %@", personName)
        )
    }

    var body: some View {
        NavigationStack {
            List(tasks, id: \.uid) { task in
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
