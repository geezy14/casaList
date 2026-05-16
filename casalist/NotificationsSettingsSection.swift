import SwiftUI

/// Notification configuration section, isolated in its own View struct
/// for the same reason DeveloperSettingsSection lives separately — too
/// many toggles + conditional pickers in a single body trips Swift's
/// metadata demangler on iOS 26 (see CLAUDE.md 2026-05-15 1.5 entry).
/// Each visual block is its own nominal View type so type complexity
/// stays bounded.
struct NotificationsSettingsSection: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("dailyBriefingEnabled") private var dailyBriefingEnabled: Bool = true
    @AppStorage("dailyBriefingHour") private var dailyBriefingHour: Int = 7
    @AppStorage("quietHoursEnabled") private var quietHoursEnabled: Bool = false
    @AppStorage("quietHoursStart") private var quietHoursStart: Int = 21
    @AppStorage("quietHoursEnd") private var quietHoursEnd: Int = 7
    @AppStorage("groceryActivityPush") private var groceryActivityPush: Bool = true
    @AppStorage("reminderRecapEnabled") private var reminderRecapEnabled: Bool = false
    @AppStorage("reminderRecapHour") private var reminderRecapHour: Int = 21

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTIFICATIONS")
                .font(.system(size: 11, weight: .heavy)).tracking(1.2)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                NotifDueDateRow(enabled: $notificationsEnabled)
                NotifDailyBriefingRow(enabled: $dailyBriefingEnabled, hour: $dailyBriefingHour)
                NotifReminderRecapRow(enabled: $reminderRecapEnabled, hour: $reminderRecapHour)
                NotifGroceryActivityRow(enabled: $groceryActivityPush)
                NotifQuietHoursRow(enabled: $quietHoursEnabled, start: $quietHoursStart, end: $quietHoursEnd)
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .onChange(of: reminderRecapEnabled) { _, _ in
            Task { await NotificationsManager.scheduleReminderRecap() }
        }
        .onChange(of: reminderRecapHour) { _, _ in
            Task { await NotificationsManager.scheduleReminderRecap() }
        }
    }
}

private struct NotifReminderRecapRow: View {
    @Binding var enabled: Bool
    @Binding var hour: Int
    var body: some View {
        Group {
            Toggle("Daily reminder recap", isOn: $enabled)
                .padding(.horizontal, 16).padding(.vertical, 10)
            if enabled {
                NotifDivider()
                NotifHourPickerRow(label: "Time", selection: $hour)
            }
            NotifDivider()
        }
    }
}

// MARK: – Rows

private struct NotifDueDateRow: View {
    @Binding var enabled: Bool
    var body: some View {
        Group {
            Toggle("Due-date reminders", isOn: $enabled)
                .padding(.horizontal, 16).padding(.vertical, 10)
            NotifDivider()
        }
    }
}

private struct NotifDailyBriefingRow: View {
    @Binding var enabled: Bool
    @Binding var hour: Int
    var body: some View {
        Group {
            Toggle("Daily morning briefing", isOn: $enabled)
                .padding(.horizontal, 16).padding(.vertical, 10)
            if enabled {
                NotifDivider()
                NotifHourPickerRow(label: "Time", selection: $hour)
            }
            NotifDivider()
        }
    }
}

private struct NotifGroceryActivityRow: View {
    @Binding var enabled: Bool
    var body: some View {
        Group {
            Toggle("Grocery list activity", isOn: $enabled)
                .padding(.horizontal, 16).padding(.vertical, 10)
            NotifDivider()
        }
    }
}

private struct NotifQuietHoursRow: View {
    @Binding var enabled: Bool
    @Binding var start: Int
    @Binding var end: Int
    var body: some View {
        Group {
            Toggle("Quiet hours", isOn: $enabled)
                .padding(.horizontal, 16).padding(.vertical, 10)
            if enabled {
                NotifDivider()
                NotifQuietHoursRange(start: $start, end: $end)
            }
        }
    }
}

private struct NotifQuietHoursRange: View {
    @Binding var start: Int
    @Binding var end: Int
    var body: some View {
        HStack {
            Text("From").font(.system(size: 14, weight: .semibold))
            Spacer()
            NotifHourPicker(selection: $start)
            Text("to").font(.system(size: 14, weight: .semibold)).padding(.leading, 8)
            NotifHourPicker(selection: $end)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}

private struct NotifHourPickerRow: View {
    let label: String
    @Binding var selection: Int
    var body: some View {
        HStack {
            Text(label).font(.system(size: 14, weight: .semibold))
            Spacer()
            NotifHourPicker(selection: $selection)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}

private struct NotifHourPicker: View {
    @Binding var selection: Int
    var body: some View {
        Picker("", selection: $selection) {
            ForEach(0..<24, id: \.self) { h in
                Text(NotifHourPicker.label(for: h)).tag(h)
            }
        }
        .pickerStyle(.menu)
    }
    static func label(for h: Int) -> String {
        var c = DateComponents(); c.hour = h; c.minute = 0
        let d = Calendar.current.date(from: c) ?? Date()
        let f = DateFormatter(); f.dateFormat = "h a"
        return f.string(from: d)
    }
}

private struct NotifDivider: View {
    var body: some View {
        Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 1).padding(.leading, 16)
    }
}
