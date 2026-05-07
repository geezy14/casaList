import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    // This fetches your tasks from the database and sorts them by date
    @Query(sort: \TaskItem.dueDate) private var tasks: [TaskItem]
    
    // Controls the visibility of the Add Task popup form
    @State private var isShowingAddSheet = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Casalist Modules
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
                
                // MARK: - All Family Tasks
                Section("All Family Tasks") {
                    if tasks.isEmpty {
                        Text("No tasks yet. Tap the + to start!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(tasks) { task in
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
                                
                                // Displays point value (0 for groceries/kitchen)
                                if task.points > 0 {
                                    Text("\(task.points) pts")
                                        .font(.caption.bold())
                                        .padding(6)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .onDelete(perform: deleteItems) // Swipe-to-delete
                    }
                }
            }
            .navigationTitle("Casalist Dashboard")
            // Adds the (+) Plus button in the top-right toolbar
            .toolbar {
                Button(action: { isShowingAddSheet = true }) {
                    Label("Add Task", systemImage: "plus")
                }
            }
            // Triggers the Add Task form popup sheet
            .sheet(isPresented: $isShowingAddSheet) {
                AddTaskView()
            }
        }
    }
    
    // Deletes tasks from the database
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(tasks[index])
            }
        }
    }
}
