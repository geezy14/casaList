import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var moc
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.dueDate, ascending: true)])
    private var tasks: FetchedResults<TaskItem>

    @State private var isShowingAddSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section("Casalist Modules") {
                    NavigationLink(destination: GroceryListView()) {
                        Label("Grocery List", systemImage: "cart")
                    }
                    NavigationLink(destination: MaintenanceView()) {
                        Label("Maintenance", systemImage: "wrench.adjustable")
                    }
                    NavigationLink(destination: MyToDoView(personName: "Justin")) {
                        Label("My To-Do", systemImage: "person.circle")
                    }
                    NavigationLink(destination: RewardsView()) {
                        Label("Chore Rewards", systemImage: "star.fill")
                    }
                }

                Section("All Family Tasks") {
                    if tasks.isEmpty {
                        Text("No tasks yet. Tap the + to start!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(tasks, id: \.uid) { task in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(task.task)
                                        .font(.headline)
                                    if let assignee = task.assignee {
                                        Text("Assigned to: \(assignee)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                if task.points > 0 {
                                    Text("\(task.points) pts")
                                        .font(.caption.bold())
                                        .padding(6)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            .navigationTitle("Casalist Dashboard")
            .toolbar {
                Button(action: { isShowingAddSheet = true }) {
                    Label("Add Task", systemImage: "plus")
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                AddTaskView()
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                moc.delete(tasks[index])
            }
            try? moc.save()
        }
    }
}
