import SwiftUI

/// Sheet that builds a RepeatRule. Bound to a String (the host's
/// `repeatKind`) — caller doesn't have to know about the JSON encoding.
/// "Save" writes the encoded `custom:...` string; "Don't repeat" writes
/// an empty string.
struct CustomRepeatPicker: View {
    @Binding var encoded: String
    @Environment(\.dismiss) private var dismiss

    @State private var interval: Int = 1
    @State private var unit: RepeatRule.Unit = .hour
    @State private var weekday: Int = 6   // Friday as a nicely-named default

    private let intervalOptions = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]

    var body: some View {
        NavigationStack {
            Form {
                Section("How often") {
                    Picker("Every", selection: $interval) {
                        ForEach(intervalOptions, id: \.self) { Text("\($0)").tag($0) }
                    }
                    Picker("Unit", selection: $unit) {
                        ForEach(RepeatRule.Unit.allCases, id: \.self) { u in
                            Text(u.label).tag(u)
                        }
                    }
                    if unit == .week {
                        Picker("On day", selection: $weekday) {
                            let symbols = Calendar.current.standaloneWeekdaySymbols
                            ForEach(1...7, id: \.self) { wd in
                                Text(symbols[wd - 1]).tag(wd)
                            }
                        }
                    }
                }
                Section {
                    Label(previewLabel, systemImage: "repeat")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .navigationTitle("Custom repeat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear {
                if let r = RepeatRule.decode(encoded) {
                    interval = r.interval
                    unit = r.unit
                    if let wd = r.weekday { weekday = wd }
                }
            }
        }
    }

    private var previewLabel: String {
        let rule = RepeatRule(interval: interval, unit: unit, weekday: unit == .week ? weekday : nil)
        return rule.label
    }

    private func save() {
        let rule = RepeatRule(interval: interval, unit: unit, weekday: unit == .week ? weekday : nil)
        encoded = rule.encoded
        dismiss()
    }
}
