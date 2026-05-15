import SwiftUI
import CoreData

struct AddFamilyMemberView: View {
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var households: FetchedResults<Household>

    @State private var name = ""
    @State private var role = ""
    @State private var colorHex: Int = 0xC97357

    private let presets: [Int] = [
        0xC97357, 0x7A9070, 0xE8A857, 0x6FB0CC,
        0xA892D8, 0xE47A82, 0x527E45, 0x5A3F8A,
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Family member") {
                    TextField("Name", text: $name)
                    TextField("Role (Mom, Son, Daughter…)", text: $role)
                }
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                        ForEach(presets, id: \.self) { hex in
                            ZStack {
                                Circle().fill(Color(rgb: UInt32(hex))).frame(width: 44, height: 44)
                                if colorHex == hex {
                                    Image(systemName: "checkmark").foregroundStyle(.white).fontWeight(.bold)
                                }
                            }
                            .contentShape(Circle())
                            .onTapGesture { colorHex = hex }
                        }
                    }.padding(.vertical, 6)
                }
            }
            .navigationTitle("Add Family")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let m = FamilyMember(context: moc, name: name.trimmingCharacters(in: .whitespaces), role: role, colorHex: colorHex)
                        if let h = households.preferredTarget {
                            moc.assign(m, toStoreOf: h)
                            m.household = h
                        }
                        try? moc.save()
                        dismiss()
                    }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
