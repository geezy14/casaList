import SwiftUI

/// 30-day "GitHub-style" heatmap for a single reminder. Each square
/// represents a day; filled squares are days the user completed the
/// reminder. The grid is 5 rows × 6 columns = 30 days, oldest at
/// top-left, today at bottom-right.
///
/// Caller renders this inside AddReminderView (edit mode) when the
/// reminder has a cadence that supports streaks.
struct ReminderStreakHeatmap: View {
    let taskUid: String

    /// 30-day window oldest → newest.
    private var days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<30).reversed().compactMap {
            cal.date(byAdding: .day, value: -$0, to: today)
        }
    }

    var body: some View {
        let completed = ReminderStreak.completionDays(for: taskUid)
        VStack(alignment: .leading, spacing: 6) {
            Text("LAST 30 DAYS")
                .font(.system(size: 10, weight: .heavy)).tracking(0.8)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 10), spacing: 4) {
                ForEach(days, id: \.self) { day in
                    let key = ReminderStreak.isoDay(day)
                    let isToday = Calendar.current.isDateInToday(day)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(completed.contains(key) ? Color.orange : Color.gray.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isToday ? Color.primary.opacity(0.5) : .clear, lineWidth: 1.5)
                        )
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            HStack(spacing: 8) {
                Text("🔥 \(ReminderStreak.current(for: taskUid))")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.orange)
                Text("Best \(ReminderStreak.best(for: taskUid))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
