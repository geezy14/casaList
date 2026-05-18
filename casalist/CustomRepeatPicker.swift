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
    /// Selected weekdays when `unit == .week`. iOS convention 1=Sun..7=Sat.
    /// Empty set means "generic weekly" with no specific day pinned, which
    /// stores as the legacy "weekly" preset.
    @State private var selectedWeekdays: Set<Int> = []

    private let intervalOptions = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]

    /// Preset shortcuts shown as chips. `weekdays` semantics when the
    /// preset has `unit == .week`:
    ///   nil       → preset doesn't care about weekday selection
    ///   []        → generic weekly with NO specific day (legacy "weekly")
    ///   non-empty → explicit set ("Weekdays" = Mon–Fri, etc.)
    private let presets: [PresetSpec] = [
        .init(label: "Hourly",    interval: 1,  unit: .hour,  weekdays: nil),
        .init(label: "Every 2h",  interval: 2,  unit: .hour,  weekdays: nil),
        .init(label: "Every 4h",  interval: 4,  unit: .hour,  weekdays: nil),
        .init(label: "Every 8h",  interval: 8,  unit: .hour,  weekdays: nil),
        .init(label: "Every 12h", interval: 12, unit: .hour,  weekdays: nil),
        .init(label: "Daily",     interval: 1,  unit: .day,   weekdays: nil),
        .init(label: "Weekdays",  interval: 1,  unit: .week,  weekdays: [2, 3, 4, 5, 6]),
        .init(label: "Weekends",  interval: 1,  unit: .week,  weekdays: [1, 7]),
        .init(label: "Weekly",    interval: 1,  unit: .week,  weekdays: []),
        .init(label: "Monthly",   interval: 1,  unit: .month, weekdays: nil),
        .init(label: "Yearly",    interval: 1,  unit: .year,  weekdays: nil),
    ]

    private struct PresetSpec: Identifiable {
        var label: String
        var interval: Int
        var unit: RepeatRule.Unit
        var weekdays: Set<Int>?
        var id: String { label }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Quick picks") {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                    ], spacing: 8) {
                        ForEach(presets) { p in
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
                        weekdaySelector
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

    private var weekdaySelector: some View {
        // Toggleable weekday chips. Order follows the app-wide Saturday-first
        // convention (see SaturdayFirstCalendar.swift): Sat, Sun, Mon..Fri.
        // Internal weekday ints stay in iOS convention (1=Sun..7=Sat).
        // At least one day must remain selected.
        let shorts = Calendar.current.veryShortStandaloneWeekdaySymbols  // index = wd-1
        let order: [Int] = [7, 1, 2, 3, 4, 5, 6]
        return VStack(alignment: .leading, spacing: 6) {
            Text("On these days").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(order, id: \.self) { wd in
                    let isOn = selectedWeekdays.contains(wd)
                    Button {
                        if isOn {
                            selectedWeekdays.remove(wd)
                        } else {
                            selectedWeekdays.insert(wd)
                        }
                    } label: {
                        Text(shorts[wd - 1])
                            .font(.system(size: 14, weight: .heavy))
                            .frame(width: 34, height: 34)
                            .background(
                                Circle().fill(isOn ? Color.accentColor : Color(.tertiarySystemBackground))
                            )
                            .foregroundStyle(isOn ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func presetChip(_ p: PresetSpec) -> some View {
        let isSelected: Bool = {
            guard interval == p.interval && unit == p.unit else { return false }
            if p.unit == .week {
                // For .week presets, weekdays specifies the exact set ([] means
                // generic weekly). Non-.week presets ignore the day selection.
                return selectedWeekdays == (p.weekdays ?? [])
            }
            return true
        }()
        return Button {
            interval = p.interval
            unit = p.unit
            if p.unit == .week {
                selectedWeekdays = p.weekdays ?? []
            }
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
        let wds = unit == .week ? Array(selectedWeekdays).sorted() : []
        if unit == .week && wds.count > 1 {
            return RepeatRule(interval: interval, unit: unit, weekday: nil, weekdays: wds).label
        }
        return RepeatRule(interval: interval, unit: unit,
                          weekday: unit == .week ? wds.first : nil,
                          weekdays: nil).label
    }

    /// Pre-fill the builder from whatever's stored.
    /// When encoded is empty (Never), default to Daily so the user
    /// sees a sensible starting point with no extra tap required.
    private func hydrate() {
        if encoded.isEmpty {
            interval = 1
            unit = .day
            selectedWeekdays = [6]
            return
        }
        if let r = RepeatRule.decode(encoded) {
            interval = r.interval
            unit = r.unit
            let wds = r.effectiveWeekdays
            if !wds.isEmpty { selectedWeekdays = Set(wds) }
            return
        }
        if let r = RepeatRule.fromLegacy(encoded) {
            interval = r.interval
            unit = r.unit
        }
    }

    private func save() {
        let rule: RepeatRule
        if unit == .week {
            let wds = Array(selectedWeekdays).sorted()
            if wds.count > 1 {
                rule = RepeatRule(interval: interval, unit: unit, weekday: nil, weekdays: wds)
            } else {
                rule = RepeatRule(interval: interval, unit: unit, weekday: wds.first, weekdays: nil)
            }
        } else {
            rule = RepeatRule(interval: interval, unit: unit, weekday: nil, weekdays: nil)
        }
        encoded = rule.saveForm
        dismiss()
    }
}
