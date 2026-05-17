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
    /// Last ~50 chars of the App Group container URL the widget
    /// actually got. Used to render a diagnostic line in the empty
    /// state so we can tell whether the widget process is reading
    /// the right shared container.
    let containerPathTail: String
    /// Whether the URL is the App Group container (good) or the
    /// fallback Documents dir (App Group not entitled to widget).
    let isFallback: Bool
}

struct TodayReminderProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayReminderEntry {
        TodayReminderEntry(
            date: Date(),
            snapshot: sampleSnapshot,
            containerPathTail: "placeholder",
            isFallback: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayReminderEntry) -> Void) {
        let (snap, tail, fallback) = readWithDiagnostic(preview: context.isPreview)
        let entry = TodayReminderEntry(
            date: Date(),
            snapshot: context.isPreview ? sampleSnapshot : snap,
            containerPathTail: tail,
            isFallback: fallback
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayReminderEntry>) -> Void) {
        let now = Date()
        let (snap, tail, fallback) = readWithDiagnostic(preview: false)
        let entry = TodayReminderEntry(
            date: now,
            snapshot: snap,
            containerPathTail: tail,
            isFallback: fallback
        )
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    /// Read the snapshot and return diagnostic crumbs alongside it so
    /// we can surface in the widget body whether the App Group is
    /// reachable from the widget process.
    private func readWithDiagnostic(preview: Bool) -> (TodayReminderSnapshot?, String, Bool) {
        let url = AppGroup.containerURL
        let urlString = url.absoluteString
        let fallback = !urlString.contains("/Group/") &&
                       !urlString.contains("Containers/Shared/AppGroup")
        let tail = String(urlString.suffix(50))
        let snap = preview ? nil : TodayReminderSnapshot.load()
        return (snap, tail, fallback)
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
        VStack(alignment: .leading, spacing: 4) {
            Text("All clear").font(.system(size: 13, weight: .heavy))
            Text("No reminders today")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            // Diagnostic: surface why the widget thinks the list is
            // empty. Helps tell "main app didn't write" from "widget
            // can't read the shared container."
            if entry.isFallback {
                Text("⚠️ App Group not linked")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(.red)
            } else if entry.snapshot == nil {
                Text("No snapshot file at:")
                    .font(.system(size: 7))
                    .foregroundStyle(.tertiary)
                Text(entry.containerPathTail)
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
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
            default:
                if raw.hasPrefix("custom:") {
                    let hex = String(raw.dropFirst("custom:".count))
                    return colorFromHex(hex) ?? .gray.opacity(0.5)
                }
                return .gray.opacity(0.5)
            }
        }()
        return Circle().fill(color).frame(width: 6, height: 6)
    }

    /// "#RRGGBB" → Color. Standalone copy here (widget target isn't
    /// linking ReminderColorTag.swift). Keep in sync if the canonical
    /// parser ever changes.
    private func colorFromHex(_ hex: String) -> Color? {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        return Color(
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255
        )
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
    TodayReminderEntry(
        date: .now,
        snapshot: TodayReminderSnapshot(
            entries: [
                .init(id: "1", title: "Take meds", fireAt: .now.addingTimeInterval(3600),
                      isDone: false, colorTagRaw: "red", assignee: ""),
                .init(id: "2", title: "Water plants", fireAt: .now.addingTimeInterval(7200),
                      isDone: false, colorTagRaw: "green", assignee: ""),
                .init(id: "3", title: "Trash out", fireAt: .now.addingTimeInterval(14400),
                      isDone: false, colorTagRaw: "blue", assignee: "dakoda"),
            ],
            generatedAt: .now
        ),
        containerPathTail: "preview",
        isFallback: false
    )
}
