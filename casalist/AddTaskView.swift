import SwiftUI
import SwiftData

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // State variables to hold form input
    @State private var taskName = ""
    @State private var assigneeName = ""
    @State private var category = "Chores"
    @State private var dueDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("What needs to be done?", text: $taskName)
                    TextField("Who is doing it? (Assignee)", text: $assigneeName)
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                }
                
                Section("Category") {
                    Picker("Select Category", selection: $category) {
                        Text("Chores").tag("Chores")
                        Text("Kitchen").tag("kitchen")
                        Text("Groceries").tag("groceries")
                        Text("Maintenance").tag("Maintenance")
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Add New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTask()
                    }
                    .disabled(taskName.isEmpty) // Prevent saving empty tasks
                }
            }
        }
    }
    
    private func saveTask() {
        // APPLYING YOUR NOTION POINT LOGIC [cite: 583, 619]
        // If category is kitchen or groceries, points = 0. Otherwise, points = 10.
        let calculatedPoints = (category == "kitchen" || category == "groceries") ? 0 : 10
        
        let newTask = TaskItem(
            task: taskName,
            assignee: assigneeName,
            dueDate: dueDate,
            category: category,
            isCompleted: false,
            points: calculatedPoints
        )
        
        modelContext.insert(newTask) // Saves to CloudKit/SwiftData [cite: 601, 611]
        dismiss()
    }
}
