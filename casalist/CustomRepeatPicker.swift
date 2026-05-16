import SwiftUI

/// Single entry point for picking a reminder cadence. Replaces the
/// older "How often" Menu + separate "Custom…" button combo with one
/// sheet that does both: preset chips at the top, custom builder
/// below, and a "Don't repeat" toggle. Caller binds a String — the
/// host's `repeatKind` — and the sheet writes the legacy preset
/// shape ("hourly", "daily", …) when possible, otherwise the JSON
/// `custom:…` form. Empty string = no repeat.
struct CustomRepeatPicker: View {
    @Binding var encoded: String
    @Environment(\.dismiss) private var dismiss

    @State private var dontRepeat: Bool = false
    @State private var interval: Int = 1
    @State private var unit: RepeatRule.Unit = .hour
    @State private var weekday: Int = 6   // Friday default

    private let intervalOptions = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]

    /// Preset shortcuts shown as chips. Each is a triple of
    /// (display label, interval, unit). Tapping one fills the builder
    /// below so the user can see exactly what they picked.
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
                Section {
                    Toggle("Don't repeat", isOn: $dontRepeat)
                }
                if !dontRepeat {
                    Section("Quick picks") {
                        // Two-row chip grid. Tapping a chip fills the
                        // builder below so the user can tweak from a
                        // sensible starting point.
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
            }
            .navigationTitle("Repeat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear { hydrate() }
        }
    }

    private func presetChip(_ p: (label: String, interval: Int, unit: RepeatRule.Unit)) -> some View {
        let isSelected = (interval == p.interval && unit == p.unit && weekday == 6)
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

    /// Pre-fill the builder from whatever's already stored — works for
    /// custom JSON (decoded directly), legacy presets ("hourly",
    /// "daily", …), and empty strings (flips on the "Don't repeat"
    /// toggle).
    private func hydrate() {
        if encoded.isEmpty {
            dontRepeat = true
            return
        }
        if let r = RepeatRule.decode(encoded) {
            interval = r.interval
            unit = r.unit
            if let wd = r.weekday { weekday = wd }
            dontRepeat = false
            return
        }
        if let r = RepeatRule.fromLegacy(encoded) {
            interval = r.interval
            unit = r.unit
            dontRepeat = false
            return
        }
    }

    private func save() {
        if dontRepeat {
            encoded = ""
        } else {
            let rule = RepeatRule(
                interval: interval,
                unit: unit,
                weekday: unit == .week ? weekday : nil
            )
            encoded = rule.saveForm
        }
        dismiss()
    }
}
