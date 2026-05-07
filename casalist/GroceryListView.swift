import SwiftUI
import SwiftData

struct GroceryListView: View {
    // Filters tasks specifically for kitchen or groceries
    @Query(filter: #Predicate<TaskItem> { task in
        task.category == "kitchen" || task.category == "groceries"
    }) private var groceryItems: [TaskItem]

    var body: some View {
        List(groceryItems) { item in
            Text(item.task)
        }
        .navigationTitle("Grocery List")
    }
}
