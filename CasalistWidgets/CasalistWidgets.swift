import WidgetKit
import SwiftUI

/// Today Reminders widget — three variants designed to feel like
/// part of Casalist's UI, not generic data dumps.
///
/// Design language:
/// - Coral → peach hero gradient (matches the in-app Reminders hero card)
/// - Big rounded number as the visual anchor (the count or first item)
/// - Faded SF Symbol illustration behind the content for texture
/// - Thick color-tag stripes per reminder so categorization reads
/// - Relative-time copy ("In 23m" / "Now" / "Overdue 10m") instead of
///   bare clock times for the next-up surface.

struct TodayReminderEntry: TimelineEntry {
    let date: Date
    let snapshot: TodayReminderSnapshot?
}

struct TodayReminderProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayReminderEntry {
        TodayReminderEntry(date: Date(), snapshot: sampleSnapshot)
    }
    func getSnapshot(in context: Context, completion: @escaping (TodayReminderEntry) -> Void) {
        completion(TodayReminderEntry(
            date: Date(),
            snapshot: context.isPreview ? sampleSnapshot : TodayReminderSnapshot.load()
        ))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayReminderEntry>) -> Void) {
        let now = Date()
        let entry = TodayReminderEntry(date: now, snapshot: TodayReminderSnapshot.load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
    private var sampleSnapshot: TodayReminderSnapshot {
        TodayReminderSnapshot(
            entries: [
                .init(id: "1", title: "Take meds", fireAt: Date().addingTimeInterval(900),
                      isDone: false, colorTagRaw: "red", assignee: "geezy"),
                .init(id: "2", title: "Water plants", fireAt: Date().addingTimeInterval(7200),
                      isDone: false, colorTagRaw: "green", assignee: ""),
                .init(id: "3", title: "Pickup laundry", fireAt: Date().addingTimeInterval(14400),
                      isDone: false, colorTagRaw: "blue", assignee: "dakoda"),
            ],
            generatedAt: Date()
        )
    }
}

struct TodayRemindersEntryView: View {
    var entry: TodayReminderProvider.Entry
    @Environment(\.widgetFamily) private var family

    private var open: [TodayReminderSnapshot.Entry] {
        (entry.snapshot?.entries.filter { !$0.isDone }) ?? []
    }

    var body: some View {
        switch family {
        case .systemSmall:  SmallView(open: open)
        case .systemMedium: MediumView(open: open)
        case .systemLarge:  LargeView(open: open)
        default:            MediumView(open: open)
        }
    }
}

// MARK: – Small

private struct SmallView: View {
    let open: [TodayReminderSnapshot.Entry]

    var body: some View {
        ZStack(alignment: .topLeading) {
            CasalistHero()
            // Faded bell as texture anchor — clipped to the card's
            // rounded shape via the outer .clipShape below.
            Image(systemName: "bell.fill")
                .font(.system(size: 78))
                .foregroundStyle(.white.opacity(0.12))
                .offset(x: 60, y: 40)
                .rotationEffect(.degrees(14))

            if open.isEmpty {
                emptySmall
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    pinkLabel("TODAY")
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(open.count)")
                            .font(.system(size: 56, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.5)
                        Spacer(minLength: 0)
                    }
                    .padding(.top, -4)
                    Text(open.count == 1 ? "reminder" : "reminders")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.top, -4)
                    Spacer(minLength: 0)
                    if let first = open.first {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("NEXT")
                                .font(.system(size: 8, weight: .heavy)).tracking(1.2)
                                .foregroundStyle(.white.opacity(0.7))
                            Text(first.title)
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(relativeTime(first.fireAt))
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                }
                .padding(14)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var emptySmall: some View {
        VStack(alignment: .leading, spacing: 6) {
            pinkLabel("ALL CLEAR")
            Text("☀️").font(.system(size: 40))
            Spacer(minLength: 0)
            Text("Nothing today")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white)
        }
        .padding(14)
    }
}

// MARK: – Medium

private struct MediumView: View {
    let open: [TodayReminderSnapshot.Entry]

    var body: some View {
        HStack(spacing: 10) {
            // Hero card (rounded, clipped so the pin doesn't slip out)
            ZStack(alignment: .topLeading) {
                CasalistHero()
                Image(systemName: "pin.fill")
                    .font(.system(size: 92))
                    .foregroundStyle(.white.opacity(0.12))
                    .offset(x: 38, y: 56)
                    .rotationEffect(.degrees(-18))
                VStack(alignment: .leading, spacing: 0) {
                    pinkLabel("TODAY")
                    Text("\(open.count)")
                        .font(.system(size: 60, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.top, -6)
                    Text(open.count == 1 ? "reminder" : "reminders")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.top, -4)
                    Spacer(minLength: 0)
                    Text(weekdayLabel(Date()).uppercased())
                        .font(.system(size: 9, weight: .heavy)).tracking(1.2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(14)
            }
            .frame(width: 138)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            // List column
            VStack(alignment: .leading, spacing: 8) {
                if open.isEmpty {
                    Text("All clear ☀️")
                        .font(.system(size: 16, weight: .heavy))
                    Text("No reminders firing today.")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    ForEach(open.prefix(3)) { e in
                        prettyRow(e)
                    }
                    if open.count > 3 {
                        Text("+\(open.count - 3) more")
                            .font(.system(size: 10, weight: .heavy)).tracking(0.5)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 12)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: – Large

private struct LargeView: View {
    let open: [TodayReminderSnapshot.Entry]

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                CasalistHero()
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 120))
                    .foregroundStyle(.white.opacity(0.12))
                    .offset(x: 160, y: -10)
                    .rotationEffect(.degrees(14))
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(weekdayLabel(Date()).uppercased())
                            .font(.system(size: 11, weight: .heavy)).tracking(1.4)
                            .foregroundStyle(.white.opacity(0.85))
                        Text(dayLabel(Date()))
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: -4) {
                        Text("\(open.count)")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("open")
                            .font(.system(size: 10, weight: .heavy)).tracking(1.0)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
            }
            .frame(height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, 10).padding(.top, 10)

            if open.isEmpty {
                Spacer()
                emptyLarge
                Spacer()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(open.prefix(6).enumerated()), id: \.element.id) { idx, e in
                        bigRow(e)
                        if idx < min(open.count, 6) - 1 {
                            Divider().opacity(0.4).padding(.leading, 28)
                        }
                    }
                    if open.count > 6 {
                        Text("+\(open.count - 6) more later today")
                            .font(.system(size: 10, weight: .heavy)).tracking(0.8)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14).padding(.top, 8)
            }
        }
    }

    private var emptyLarge: some View {
        VStack(spacing: 10) {
            Text("☀️").font(.system(size: 56))
            Text("All clear today")
                .font(.system(size: 18, weight: .heavy))
            Text("Open Casalist to add a reminder")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: – Hero background + chrome

/// Coral → peach gradient that matches the Reminders hero in the
/// main app. Reused across all three widget sizes for visual cohesion.
private struct CasalistHero: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.51, blue: 0.42),   // coral top
                Color(red: 0.84, green: 0.36, blue: 0.38),   // deeper coral bottom
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            // Subtle inner glow so the texture doesn't feel flat.
            RadialGradient(
                colors: [Color.white.opacity(0.18), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 200
            )
        )
    }
}

private func pinkLabel(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 9, weight: .heavy)).tracking(1.5)
        .foregroundStyle(.white.opacity(0.9))
}

// MARK: – Rows

private func prettyRow(_ e: TodayReminderSnapshot.Entry) -> some View {
    HStack(spacing: 10) {
        Capsule()
            .fill(tagColor(e.colorTagRaw))
            .frame(width: 4, height: 30)
        VStack(alignment: .leading, spacing: 2) {
            Text(e.title)
                .font(.system(size: 13, weight: .heavy))
                .lineLimit(1)
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(.secondary)
                Text(relativeTime(e.fireAt))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                if !e.assignee.isEmpty {
                    Text("·").font(.system(size: 8)).foregroundStyle(.tertiary)
                    Text(e.assignee)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        Spacer(minLength: 0)
    }
}

private func bigRow(_ e: TodayReminderSnapshot.Entry) -> some View {
    HStack(spacing: 10) {
        RoundedRectangle(cornerRadius: 4)
            .fill(tagColor(e.colorTagRaw))
            .frame(width: 5, height: 34)
        VStack(alignment: .leading, spacing: 2) {
            Text(e.title)
                .font(.system(size: 15, weight: .heavy))
                .lineLimit(1)
            HStack(spacing: 5) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                Text(relativeTime(e.fireAt))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        Spacer(minLength: 0)
        if !e.assignee.isEmpty {
            Text(String(e.assignee.prefix(1)).uppercased())
                .font(.system(size: 11, weight: .heavy))
                .frame(width: 24, height: 24)
                .background(
                    Circle().fill(LinearGradient(
                        colors: [Color(red: 0.95, green: 0.51, blue: 0.42),
                                 Color(red: 0.84, green: 0.36, blue: 0.38)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                )
                .foregroundStyle(.white)
        }
    }
    .padding(.vertical, 8)
}

// MARK: – Color + time

private func tagColor(_ raw: String) -> Color {
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
            return colorFromHex(String(raw.dropFirst("custom:".count))) ?? .gray.opacity(0.6)
        }
        return .gray.opacity(0.5)
    }
}

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

private func relativeTime(_ fire: Date?) -> String {
    guard let fire else { return "Pinned" }
    let now = Date()
    let secs = fire.timeIntervalSince(now)
    if secs < -60 {
        let mins = Int(-secs / 60)
        if mins < 60 { return "Overdue \(mins)m" }
        return "Overdue \(mins / 60)h"
    }
    if secs < 60 { return "Now" }
    if secs < 3600 { return "In \(Int(secs / 60))m" }
    let cal = Calendar.current
    if cal.isDateInToday(fire) {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: fire)
    }
    if cal.isDateInTomorrow(fire) {
        let f = DateFormatter(); f.dateFormat = "'Tmrw' h:mm a"; return f.string(from: fire)
    }
    let f = DateFormatter(); f.dateFormat = "MMM d · h:mm a"
    return f.string(from: fire)
}

private func weekdayLabel(_ d: Date) -> String {
    let f = DateFormatter(); f.dateFormat = "EEEE"; return f.string(from: d)
}

private func dayLabel(_ d: Date) -> String {
    let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: d)
}

// MARK: – Configuration

struct TodayRemindersWidget: Widget {
    let kind: String = "TodayRemindersWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayReminderProvider()) { entry in
            if #available(iOS 17.0, *) {
                TodayRemindersEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color(.systemBackground)
                    }
            } else {
                TodayRemindersEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Today's reminders")
        .description("Today's open reminders, color-tagged and sorted by fire time.")
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
                .init(id: "1", title: "Take meds", fireAt: .now.addingTimeInterval(900),
                      isDone: false, colorTagRaw: "red", assignee: "geezy"),
                .init(id: "2", title: "Water plants", fireAt: .now.addingTimeInterval(7200),
                      isDone: false, colorTagRaw: "green", assignee: ""),
                .init(id: "3", title: "Pickup laundry", fireAt: .now.addingTimeInterval(14400),
                      isDone: false, colorTagRaw: "blue", assignee: "dakoda"),
            ],
            generatedAt: .now
        )
    )
}
