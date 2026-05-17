import WidgetKit
import SwiftUI

/// Today Reminders widget — reads the snapshot the main app wrote to
/// the shared App Group container.
///
/// Sizes:
/// - **small** — count + first item
/// - **medium** — count + next 3 items
/// - **large** — full today's list (up to ~10)

struct TodayReminderEntry: TimelineEntry {
    let date: Date
    let snapshot: TodayReminderSnapshot?
}

struct TodayReminderProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayReminderEntry {
        TodayReminderEntry(date: Date(), snapshot: sampleSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayReminderEntry) -> Void) {
        let entry = TodayReminderEntry(
            date: Date(),
            snapshot: context.isPreview ? sampleSnapshot : TodayReminderSnapshot.load()
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayReminderEntry>) -> Void) {
        // Single-entry timeline: the snapshot is updated by the main
        // app whenever reminders change, and WidgetCenter reloads us
        // then. Refresh every 30 min as a backstop in case the user
        // hasn't opened the app.
        let now = Date()
        let entry = TodayReminderEntry(date: now, snapshot: TodayReminderSnapshot.load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private var sampleSnapshot: TodayReminderSnapshot {
        TodayReminderSnapshot(
            entries: [
                .init(id: "1", title: "Take meds", fireAt: Date().addingTimeInterval(3600),
                      isDone: false, colorTagRaw: "red", assignee: ""),
                .init(id: "2", title: "Water plants", fireAt: Date().addingTimeInterval(7200),
                      isDone: false, colorTagRaw: "green", assignee: ""),
                .init(id: "3", title: "Trash out", fireAt: Date().addingTimeInterval(14400),
                      isDone: false, colorTagRaw: "blue", assignee: "geezy"),
            ],
            generatedAt: Date()
        )
    }
}

struct TodayRemindersEntryView: View {
    var entry: TodayReminderProvider.Entry
    @Environment(\.widgetFamily) private var family

    private var openCount: Int {
        entry.snapshot?.entries.filter { !$0.isDone }.count ?? 0
    }

    private var visibleEntries: [TodayReminderSnapshot.Entry] {
        let open = entry.snapshot?.entries.filter { !$0.isDone } ?? []
        switch family {
        case .systemSmall:  return Array(open.prefix(1))
        case .systemMedium: return Array(open.prefix(3))
        default:            return Array(open.prefix(10))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if visibleEntries.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                ForEach(visibleEntries) { e in
                    row(e)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: "bell.fill")
                .font(.caption2)
                .foregroundStyle(.tint)
            Text("\(openCount) today")
                .font(.system(size: 11, weight: .heavy)).tracking(0.6)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func row(_ e: TodayReminderSnapshot.Entry) -> some View {
        HStack(spacing: 6) {
            tagDot(e.colorTagRaw)
            VStack(alignment: .leading, spacing: 1) {
                Text(e.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                if let fire = e.fireAt {
                    Text(fire, style: .time)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !e.assignee.isEmpty {
                Text(String(e.assignee.prefix(1)).uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .frame(width: 14, height: 14)
                    .background(Circle().fill(.tertiary))
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("All clear").font(.system(size: 13, weight: .heavy))
            Text("No reminders today")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func tagDot(_ raw: String) -> some View {
        let color: Color = {
            switch raw {
            case "red":    return .red
            case "orange": return .orange
            case "yellow": return .yellow
            case "green":  return .green
            case "blue":   return .blue
            case "purple": return .purple
            case "pink":   return .pink
            default:       return .gray.opacity(0.5)
            }
        }()
        return Circle().fill(color).frame(width: 6, height: 6)
    }
}

struct TodayRemindersWidget: Widget {
    let kind: String = "TodayRemindersWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayReminderProvider()) { entry in
            if #available(iOS 17.0, *) {
                TodayRemindersEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                TodayRemindersEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Today's reminders")
        .description("Quick look at reminders firing today.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemMedium) {
    TodayRemindersWidget()
} timeline: {
    TodayReminderEntry(date: .now, snapshot: TodayReminderSnapshot(
        entries: [
            .init(id: "1", title: "Take meds", fireAt: .now.addingTimeInterval(3600),
                  isDone: false, colorTagRaw: "red", assignee: ""),
            .init(id: "2", title: "Water plants", fireAt: .now.addingTimeInterval(7200),
                  isDone: false, colorTagRaw: "green", assignee: ""),
            .init(id: "3", title: "Trash out", fireAt: .now.addingTimeInterval(14400),
                  isDone: false, colorTagRaw: "blue", assignee: "dakoda"),
        ],
        generatedAt: .now
    ))
}
