import SwiftUI

/// Read-only feed of "what fired today / yesterday / earlier."
/// Reads from `ReminderHistory` (local JSON log). Tap entries do
/// nothing for now — could deep-link to the reminder later.
struct ReminderHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [ReminderHistory.Entry] = []
    @State private var confirmClear: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(grouped, id: \.label) { section in
                            Section(section.label) {
                                ForEach(section.items) { entry in
                                    row(entry)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(role: .destructive) {
                            confirmClear = true
                        } label: {
                            Label("Clear history", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .confirmationDialog(
                "Clear all history?",
                isPresented: $confirmClear,
                titleVisibility: .visible
            ) {
                Button("Clear", role: .destructive) {
                    ReminderHistory.clearAll()
                    entries = []
                }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear { entries = ReminderHistory.load() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No reminder activity yet").font(.system(size: 16, weight: .heavy))
            Text("Marked-done and snoozed actions from reminders show up here.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private func row(_ entry: ReminderHistory.Entry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon(for: entry.action))
                .foregroundStyle(color(for: entry.action))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.taskName).font(.system(size: 15, weight: .semibold))
                Text(label(for: entry.action)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(timeLabel(entry.timestamp))
                .font(.caption).foregroundStyle(.tertiary)
        }
    }

    private func icon(for a: ReminderHistory.Action) -> String {
        switch a {
        case .fired: return "bell.fill"
        case .markedDone: return "checkmark.circle.fill"
        case .snoozed: return "moon.zzz.fill"
        }
    }

    private func color(for a: ReminderHistory.Action) -> Color {
        switch a {
        case .fired: return .blue
        case .markedDone: return .green
        case .snoozed: return .orange
        }
    }

    private func label(for a: ReminderHistory.Action) -> String {
        switch a {
        case .fired: return "Notification fired"
        case .markedDone: return "Marked done"
        case .snoozed: return "Snoozed"
        }
    }

    private func timeLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: d)
    }

    // MARK: – Sectioning

    private struct Bucket {
        let label: String
        let items: [ReminderHistory.Entry]
    }

    private var grouped: [Bucket] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let weekAgo = cal.date(byAdding: .day, value: -7, to: today)!

        var todayBucket: [ReminderHistory.Entry] = []
        var yesterdayBucket: [ReminderHistory.Entry] = []
        var thisWeekBucket: [ReminderHistory.Entry] = []
        var olderBucket: [ReminderHistory.Entry] = []

        for e in entries {
            if e.timestamp >= today {
                todayBucket.append(e)
            } else if e.timestamp >= yesterday {
                yesterdayBucket.append(e)
            } else if e.timestamp >= weekAgo {
                thisWeekBucket.append(e)
            } else {
                olderBucket.append(e)
            }
        }
        var out: [Bucket] = []
        if !todayBucket.isEmpty { out.append(Bucket(label: "Today", items: todayBucket)) }
        if !yesterdayBucket.isEmpty { out.append(Bucket(label: "Yesterday", items: yesterdayBucket)) }
        if !thisWeekBucket.isEmpty { out.append(Bucket(label: "This week", items: thisWeekBucket)) }
        if !olderBucket.isEmpty { out.append(Bucket(label: "Older", items: olderBucket)) }
        return out
    }
}
