import SwiftUI
import CoreData

struct GroceryListView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: true)],
        predicate: NSPredicate(format: "category IN %@", ["kitchen", "groceries"])
    ) private var groceryItems: FetchedResults<TaskItem>

    var body: some View {
        List(groceryItems, id: \.uid) { item in
            Text(item.task)
        }
        .navigationTitle("Grocery List")
    }
}
