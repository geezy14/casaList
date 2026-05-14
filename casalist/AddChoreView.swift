import SwiftUI
import SwiftData

struct AddChoreView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var label: String = ""
    @State private var points: Int = 10
    @State private var symbol: String = "checkmark.circle"

    private let symbolOptions: [String] = [
        "checkmark.circle", "trash", "leaf", "pawprint", "tshirt",
        "fork.knife", "wrench.adjustable", "cart", "house",
        "bed.double", "shower", "bicycle"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Chore") {
                    TextField("Take out trash, mow lawn…", text: $label)
                        .textInputAutocapitalization(.sentences)
                }
                Section("Points") {
                    Stepper(value: $points, in: 1...500, step: 5) {
                        Text("\(points) pts")
                    }
                }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(symbolOptions, id: \.self) { s in
                            Button { symbol = s } label: {
                                Image(systemName: s)
                                    .font(.system(size: 18))
                                    .frame(width: 44, height: 44)
                                    .background(Circle().fill(symbol == s ? Color.accentColor : Color(.secondarySystemBackground)))
                                    .foregroundStyle(symbol == s ? .white : .primary)
                            }.buttonStyle(.plain)
                        }
                    }.padding(.vertical, 4)
                }
            }
            .navigationTitle("New chore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        modelContext.insert(ChoreTemplate(
            label: label.trimmingCharacters(in: .whitespaces),
            points: points,
            symbol: symbol
        ))
        try? modelContext.save()
        dismiss()
    }
}
