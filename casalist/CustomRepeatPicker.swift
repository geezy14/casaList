import SwiftUI

/// Full repeat picker — always shows all options immediately.
/// Caller binds a String (`repeatKind`). Save writes the legacy
/// preset shape ("hourly", "daily", …) when the shape matches,
/// otherwise the JSON `custom:…` form. Empty string = no repeat;
/// the caller is responsible for clearing (X button on the row).
struct CustomRepeatPicker: View {
    @Binding var encoded: String
    @Environment(\.dismiss) private var dismiss

    @State private var interval: Int = 1
    @State private var unit: RepeatRule.Unit = .day
    @State private var weekday: Int = 6   // Friday default

    private let intervalOptions = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]

    /// Preset shortcuts shown as chips.
    private let presets: [(label: String, interval: Int, unit: RepeatRule.Unit)] = [
        ("Hourly",     1,  .hour),
        ("Every 2h",   2,  .hour),
        ("Every 4h",   4,  .hour),
        ("Every 8h",   8,  .hour),
        ("Every 12h", 12,  .hour),
        ("Daily",      1,  .day),
        ("Weekly",     1,  .week),
        ("Monthly",    1,  .month),
        ("Yearly",     1,  .year),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Quick picks") {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                    ], spacing: 8) {
                        ForEach(presets, id: \.label) { p in
                            presetChip(p)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Custom") {
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
            .navigationTitle("Repeat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { hydrate() }
        }
    }

    private func presetChip(_ p: (label: String, interval: Int, unit: RepeatRule.Unit)) -> some View {
        let isSelected = (interval == p.interval && unit == p.unit &&
                          (unit != .week || weekday == 6))
        return Button {
            interval = p.interval
            unit = p.unit
        } label: {
            Text(p.label)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? Color.accentColor : Color(.tertiarySystemBackground))
                )
        }
        .buttonStyle(.plain)
    }

    private var previewLabel: String {
        RepeatRule(interval: interval, unit: unit, weekday: unit == .week ? weekday : nil).label
    }

    /// Pre-fill the builder from whatever's stored.
    /// When encoded is empty (Never), default to Daily so the user
    /// sees a sensible starting point with no extra tap required.
    private func hydrate() {
        if encoded.isEmpty {
            interval = 1
            unit = .day
            return
        }
        if let r = RepeatRule.decode(encoded) {
            interval = r.interval
            unit = r.unit
            if let wd = r.weekday { weekday = wd }
            return
        }
        if let r = RepeatRule.fromLegacy(encoded) {
            interval = r.interval
            unit = r.unit
        }
    }

    private func save() {
        let rule = RepeatRule(
            interval: interval,
            unit: unit,
            weekday: unit == .week ? weekday : nil
        )
        encoded = rule.saveForm
        dismiss()
    }
}
