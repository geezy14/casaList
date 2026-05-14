//
//  CasalistCottage.swift
//  Casalist — "Cottage" direction (playful pastel family, iOS 17+)
//
//  Requires CasalistShared.swift.
//  Use as:  CasalistCottage.Home()  or  CasalistCottage.Rewards()
//

import SwiftUI
import CoreData

public enum CasalistCottage {

    struct Palette {
        let bg, surface, surfaceAlt, surfaceHi, border, text, textDim, textMuted: Color
        let peach, mint, butter, lavender, sky, coral: Color
        static func resolve(_ dark: Bool) -> Palette {
            dark ? Palette(
                bg: Color(rgb: 0x251812), surface: Color(rgb: 0x1A0F0A), surfaceAlt: Color(rgb: 0x3A2418), surfaceHi: Color(rgb: 0x4D2F1F),
                border: Color.white.opacity(0.05),
                text: Color(rgb: 0xF7F0F8), textDim: Color(rgb: 0xF7F0F8).opacity(0.55), textMuted: Color(rgb: 0xF7F0F8).opacity(0.35),
                peach: Color(rgb: 0xC13E20), mint: Color(rgb: 0x527E45), butter: Color(rgb: 0xB8842A),
                lavender: Color(rgb: 0x5A3F8A), sky: Color(rgb: 0x3D6480), coral: Color(rgb: 0x7E3030)
            ) : Palette(
                bg: Color(rgb: 0xFFF8F0), surface: Color(rgb: 0xFFFFFF), surfaceAlt: Color(rgb: 0xFFF1E1), surfaceHi: Color(rgb: 0xFBE9D5),
                border: Color(rgb: 0x482A1E).opacity(0.08),
                text: Color(rgb: 0x3B2A22), textDim: Color(rgb: 0x3B2A22).opacity(0.6), textMuted: Color(rgb: 0x3B2A22).opacity(0.4),
                peach: Color(rgb: 0xFF9E7C), mint: Color(rgb: 0x7AB97D), butter: Color(rgb: 0xE8B040),
                lavender: Color(rgb: 0xA892D8), sky: Color(rgb: 0x6FA8D0), coral: Color(rgb: 0xE47A82)
            )
        }
    }

    public struct Home: View {
        @Environment(\.colorScheme) private var sys
        @State private var darkOverride: Bool? = nil
        @State private var showAddMember = false
        @State private var showInvite = false
        @State private var showSettings = false
        @State private var showAddTodo = false
        @State private var showGrocery = false
        @State private var showMaintenance = false
        @State private var showReminders = false
        @State private var showMyToDo = false
        @State private var showSchedule = false
        @State private var showProfilePhoto = false
        @AppStorage("userName") private var userName: String = ""
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)]) private var members: FetchedResults<FamilyMember>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: true)]) private var allTodos: FetchedResults<TaskItem>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyEvent.startDate, ascending: true)]) private var allEvents: FetchedResults<FamilyEvent>
        private var dark: Bool { darkOverride ?? (sys == .dark) }
        private var P: Palette { Palette.resolve(dark) }
        private var sortedMembers: [FamilyMember] { members.sorted { $0.points > $1.points } }
        public init() {}

        public var body: some View {
            ZStack {
                P.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                    ScrollView { content }.scrollIndicators(.hidden)
                }
            }
            .foregroundStyle(P.text)
            .preferredColorScheme(dark ? .dark : .light)
            .sheet(isPresented: $showAddMember) { AddFamilyMemberView() }
            .sheet(isPresented: $showInvite) { InviteFamilyView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showAddTodo) { AddTaskView() }
            .fullScreenCover(isPresented: $showGrocery) { Grocery() }
            .fullScreenCover(isPresented: $showMaintenance) { Maintenance() }
            .fullScreenCover(isPresented: $showReminders) { Reminders() }
            .fullScreenCover(isPresented: $showMyToDo) { MyToDo() }
            .fullScreenCover(isPresented: $showSchedule) { Schedule() }
            .sheet(isPresented: $showProfilePhoto) { ProfilePhotoSheet() }
        }

        private var userMember: FamilyMember? {
            let trimmed = userName.trimmingCharacters(in: .whitespaces).lowercased()
            guard !trimmed.isEmpty else { return nil }
            return members.first { $0.name.lowercased() == trimmed }
        }

        private var topBar: some View {
            HStack(spacing: 10) {
                HStack(spacing: -10) { ForEach(members) { CLAvatar($0.asCLMember, size: 34) } }
                Spacer()
                Button { showInvite = true } label: {
                    Image(systemName: "person.crop.circle.badge.plus").font(.system(size: 15)).foregroundStyle(P.text)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(P.surfaceAlt))
                }
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill").font(.system(size: 14)).foregroundStyle(P.text)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(P.surfaceAlt))
                }
                Button { darkOverride = !dark } label: {
                    Image(systemName: dark ? "sun.max.fill" : "moon.fill").font(.system(size: 14)).foregroundStyle(P.text)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(P.surfaceAlt))
                }
            }.padding(.horizontal, 20).padding(.bottom, 12)
        }

        private var content: some View {
            VStack(alignment: .leading, spacing: 14) {
                greetingCard
                stickyAgenda
                quickAdd
                star
                tiles
                whatsNew
            }.padding(.horizontal, 20).padding(.bottom, 28)
        }

        private var isNight: Bool {
            let h = Calendar.current.component(.hour, from: Date())
            return h < 6 || h >= 19
        }

        private var greetingText: String {
            let trimmed = userName.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? "hi there ✨" : "hi \(trimmed) ✨"
        }

        private var thingsTodayCount: Int {
            allTodos.filter { t in
                guard !t.isCompleted, let due = t.dueDate else { return false }
                return Calendar.current.isDateInToday(due)
            }.count
        }
        private var moduleCategories: [String] { ["groceries", "maintenance"] }

        private var thingsTodayText: String {
            switch thingsTodayCount {
            case 0: return "Nothing on the list yet"
            case 1: return "1 thing happening today"
            default: return "\(thingsTodayCount) things happening today"
            }
        }

        private var todayString: String {
            let f = DateFormatter()
            f.dateFormat = "EEEE · MMM d"
            return f.string(from: Date()).uppercased()
        }

        private var greetingCard: some View {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(todayString).font(.system(size: 11, weight: .heavy)).tracking(0.6).opacity(0.95)
                    Text(greetingText).font(.system(size: 26, weight: .heavy)).padding(.top, 2)
                    Text(thingsTodayText).font(.system(size: 13, weight: .semibold)).opacity(0.95)
                }
                .foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22).padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(isNight ? Color(rgb: 0x1F3A5E) : P.peach)
            .overlay(alignment: .trailing) {
                profileIcon
                    .padding(.trailing, 80)
            }
            .overlay(alignment: .topTrailing) {
                Text(isNight ? "🌙" : "☀️")
                    .font(.system(size: 80))
                    .opacity(0.9)
                    .offset(x: 22, y: -18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }

        /// iMessage-style profile chip — 56pt dark circle. Shows the user's
        /// uploaded photo when their matching FamilyMember has one, otherwise
        /// the person.crop.circle.fill glyph. Tap to pick/replace photo.
        private var profileIcon: some View {
            Button { showProfilePhoto = true } label: {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.12, green: 0.12, blue: 0.18))
                        .frame(width: 56, height: 56)
                        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    if let data = userMember?.photoData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable().scaledToFill()
                            .frame(width: 54, height: 54)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(Color(red: 0.27, green: 0.52, blue: 1.0).opacity(0.85))
                    }
                }
            }.buttonStyle(.plain)
        }

        private struct AgendaTile: Identifiable {
            let id = UUID()
            let timeText: String
            let label: String
            let sub: String
            let symbol: String
            let color: Color
        }

        private func tileSymbol(_ cat: String) -> String {
            switch cat.lowercased() {
            case "chores": return "checkmark.circle.fill"
            case "kitchen": return "fork.knife"
            case "groceries": return "cart.fill"
            case "maintenance": return "wrench.fill"
            default: return "calendar"
            }
        }

        private func tileColor(_ cat: String) -> Color {
            switch cat.lowercased() {
            case "chores": return P.mint
            case "kitchen": return P.butter
            case "groceries": return P.peach
            case "maintenance": return P.lavender
            default: return P.sky
            }
        }

        private var todayAgenda: [AgendaTile] {
            let cal = Calendar.current
            let dueToday = allTodos.filter { t in
                guard !t.isCompleted, t.category.lowercased() != "reminders", let due = t.dueDate else { return false }
                return cal.isDateInToday(due)
            }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
            let pinned = allTodos.filter { !$0.isCompleted && $0.category.lowercased() == "reminders" }
            let eventsToday = allEvents.filter { cal.isDateInToday($0.startDate) }
                .sorted { $0.startDate < $1.startDate }
            let timeFmt = DateFormatter()
            timeFmt.dateFormat = "h:mm a"
            let eventTiles = eventsToday.map { e -> AgendaTile in
                AgendaTile(
                    timeText: e.isAllDay ? "All-day" : timeFmt.string(from: e.startDate),
                    label: e.title,
                    sub: e.attendees,
                    symbol: "calendar",
                    color: P.sky
                )
            }
            let timedTiles = dueToday.map { task in
                AgendaTile(
                    timeText: timeFmt.string(from: task.dueDate ?? Date()),
                    label: task.task,
                    sub: task.assignee ?? "",
                    symbol: tileSymbol(task.category),
                    color: tileColor(task.category)
                )
            }
            let pinnedTiles = pinned.map { task -> AgendaTile in
                let kind = task.effectiveRepeatKind
                let timeText: String
                let symbol: String
                let f = DateFormatter()
                switch kind {
                case "hourly":   timeText = "Hourly";        symbol = "arrow.triangle.2.circlepath"
                case "every2h":  timeText = "Every 2h";      symbol = "arrow.triangle.2.circlepath"
                case "every4h":  timeText = "Every 4h";      symbol = "arrow.triangle.2.circlepath"
                case "every8h":  timeText = "Every 8h";      symbol = "arrow.triangle.2.circlepath"
                case "every12h": timeText = "Every 12h";     symbol = "arrow.triangle.2.circlepath"
                case "daily":
                    if let due = task.dueDate { f.dateFormat = "'Daily' h:mm a"; timeText = f.string(from: due) }
                    else { timeText = "Daily" }
                    symbol = "arrow.triangle.2.circlepath"
                case "weekly":
                    if let due = task.dueDate { f.dateFormat = "EEE h:mm a"; timeText = f.string(from: due) }
                    else { timeText = "Weekly" }
                    symbol = "arrow.triangle.2.circlepath"
                case "monthly":  timeText = "Monthly";       symbol = "arrow.triangle.2.circlepath"
                case "yearly":   timeText = "Yearly";        symbol = "arrow.triangle.2.circlepath"
                default:
                    if let due = task.dueDate {
                        timeText = timeFmt.string(from: due); symbol = "clock.fill"
                    } else {
                        timeText = "Pinned"; symbol = "pin.fill"
                    }
                }
                return AgendaTile(
                    timeText: timeText,
                    label: task.task,
                    sub: "",
                    symbol: symbol,
                    color: P.coral
                )
            }
            return eventTiles + timedTiles + pinnedTiles
        }

        @ViewBuilder
        private var stickyAgenda: some View {
            if !todayAgenda.isEmpty {
                Button { showSchedule = true } label: {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(todayAgenda.enumerated()), id: \.element.id) { i, a in
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: a.symbol).font(.system(size: 15)).foregroundStyle(a.color)
                                    .frame(width: 30, height: 30)
                                    .background(Circle().fill(a.color.opacity(0.2)))
                                Text(a.label).font(.system(size: 13, weight: .heavy)).lineLimit(2)
                                Text(a.sub.isEmpty ? a.timeText : "\(a.timeText) · \(a.sub)")
                                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted).lineLimit(2)
                            }
                            .padding(14).frame(width: 130, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 20).fill(i % 2 == 0 ? P.surface : P.surfaceAlt))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(P.border, lineWidth: 1.5))
                        }
                    }.padding(.vertical, 4)
                }
                .foregroundStyle(P.text)
                }.buttonStyle(.plain)
            }
        }

        private var quickAdd: some View {
            Button { showAddTodo = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle").font(.system(size: 18)).foregroundStyle(P.textDim)
                    Text("What needs doing?").font(.system(size: 14, weight: .semibold)).foregroundStyle(P.textDim)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Capsule().fill(P.surface))
                .overlay(Capsule().stroke(P.border, lineWidth: 1.5))
            }.buttonStyle(.plain)
        }

        private var star: some View {
            Group {
                if members.isEmpty {
                    emptyFamilyCard
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("THIS WEEK'S STAR ⭐").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                        starCard
                    }
                }
            }
        }

        private var emptyFamilyCard: some View {
            Button { showInvite = true } label: {
                VStack(spacing: 10) {
                    Text("👨‍👩‍👧‍👦").font(.system(size: 44))
                    Text("Invite your family").font(.system(size: 18, weight: .heavy))
                    Text("Tap to invite").font(.system(size: 12, weight: .semibold)).opacity(0.75)
                }
                .foregroundStyle(Color(rgb: 0x3B2A22))
                .frame(maxWidth: .infinity).padding(24)
                .background(P.butter)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }.buttonStyle(.plain)
        }

        private var starCard: some View {
            let sorted = sortedMembers
            let top = sorted.first
            let lead = (top?.points ?? 0) - (sorted.dropFirst().first?.points ?? 0)
            return ZStack(alignment: .bottomTrailing) {
                    Text("🏆").font(.system(size: 80)).offset(x: -10, y: 30).opacity(0.2)
                    VStack(alignment: .leading, spacing: 10) {
                        if let top {
                            HStack(spacing: 14) {
                                CLAvatar(top.asCLMember, size: 56)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("1ST PLACE").font(.system(size: 11, weight: .heavy)).tracking(0.8).opacity(0.7)
                                    Text(top.name).font(.system(size: 22, weight: .heavy))
                                    Text("\(top.points) pts\(lead > 0 ? " · \(lead) ahead!" : "")").font(.system(size: 13, weight: .bold))
                                }
                            }
                        }
                        ForEach(Array(sorted.enumerated()), id: \.element.uid) { i, m in
                            HStack(spacing: 10) {
                                Text(["🥇","🥈","🥉","4️⃣"][min(i, 3)]).font(.system(size: 14))
                                Text(m.name).font(.system(size: 13, weight: .heavy))
                                Spacer()
                                Text("\(m.points)").font(.system(size: 13, weight: .heavy)).monospacedDigit()
                            }
                        }
                    }
                    .foregroundStyle(Color(rgb: 0x3B2A22)).padding(20)
                }
                .background(P.butter)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }

        private var openTodoCount: Int {
            allTodos.filter { !$0.isCompleted && !["groceries", "maintenance", "reminders"].contains($0.category.lowercased()) }.count
        }
        private var nextTodoTitle: String {
            allTodos.first(where: { !$0.isCompleted && !["groceries", "maintenance", "reminders"].contains($0.category.lowercased()) })?.task ?? ""
        }
        private var groceryItems: [TaskItem] {
            allTodos.filter { t in
                !t.isCompleted &&
                t.category.lowercased() == "groceries" &&
                // Exclude trip headers (top-level grocery tasks with a dueDate).
                !(t.parentUid.isEmpty && t.dueDate != nil)
            }
        }
        private var groceryActiveCount: Int { groceryItems.count }
        private var groceryNextItems: String { groceryItems.prefix(3).map { $0.task }.joined(separator: ", ") }
        private var maintenanceItems: [TaskItem] { allTodos.filter { !$0.isCompleted && $0.category.lowercased() == "maintenance" } }
        private var maintenanceActiveCount: Int { maintenanceItems.count }
        private var maintenanceOverdueCount: Int { maintenanceItems.filter { ($0.dueDate ?? .distantFuture) < Date() }.count }
        private var maintenanceNextItem: String { maintenanceItems.first?.task ?? "" }
        private var reminderItems: [TaskItem] { allTodos.filter { !$0.isCompleted && $0.category.lowercased() == "reminders" } }
        private var reminderCount: Int { reminderItems.count }
        private var reminderPreview: String { reminderItems.prefix(3).map { $0.task }.joined(separator: ", ") }

        private var tiles: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("AROUND THE HOUSE").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    Button { showGrocery = true } label: {
                        tile(bg: P.mint, emoji: "🛒", label: "Grocery", big: "\(groceryActiveCount)", suffix: "to get", sub: groceryNextItems)
                    }.buttonStyle(.plain)
                    Button { showMaintenance = true } label: {
                        tile(bg: P.lavender, emoji: "🔧", label: "Maintenance", big: "\(maintenanceActiveCount)", suffix: "open", sub: maintenanceNextItem, badge: maintenanceOverdueCount > 0 ? "\(maintenanceOverdueCount) DUE" : nil)
                    }.buttonStyle(.plain)
                    Button { showMyToDo = true } label: {
                        tile(bg: P.sky, emoji: "✏️", label: "My To-Do", big: "\(openTodoCount)", suffix: "open", sub: nextTodoTitle)
                    }.buttonStyle(.plain)
                    Button { showReminders = true } label: {
                        tile(bg: P.coral, emoji: "📌", label: "Reminders", big: "\(reminderCount)", suffix: "pinned", sub: reminderPreview)
                    }.buttonStyle(.plain)
                    Button { showSchedule = true } label: {
                        tile(bg: P.butter, emoji: "📅", label: "Schedule", big: "\(scheduleUpcomingCount)", suffix: "upcoming", sub: nextEventTitle)
                    }.buttonStyle(.plain)
                }
            }
        }

        private var scheduleUpcomingCount: Int {
            allEvents.filter { $0.startDate >= Calendar.current.startOfDay(for: Date()) }.count
        }
        private var nextEventTitle: String {
            allEvents.first(where: { $0.startDate >= Date() })?.title ?? ""
        }

        private func tile(bg: Color, emoji: String, label: String, big: String, suffix: String, sub: String, badge: String? = nil) -> some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(emoji).font(.system(size: 20))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.45)))
                    Spacer()
                    if let badge {
                        Text(badge).font(.system(size: 9, weight: .heavy)).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Capsule().fill(Color.black.opacity(0.18)))
                    }
                }.padding(.bottom, 10)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(big).font(.system(size: 28, weight: .heavy))
                    Text(suffix).font(.system(size: 11, weight: .bold)).opacity(0.7)
                }
                Text(label).font(.system(size: 14, weight: .bold))
                Text(sub).font(.system(size: 11, weight: .semibold)).opacity(0.7).lineLimit(2).frame(height: 28, alignment: .top)
            }
            .foregroundStyle(Color(rgb: 0x3B2A22))
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 24).fill(bg))
        }

        private struct ActivityEntry: Identifiable {
            let id = UUID()
            let who: String
            let verb: String
            let target: String
            let when: Date
        }

        private var activityFeed: [ActivityEntry] {
            allTodos
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(6)
                .map { t in
                    let who: String = {
                        if !t.createdBy.isEmpty { return t.createdBy }
                        if let a = t.assignee, !a.isEmpty { return a }
                        return ""
                    }()
                    return ActivityEntry(
                        who: who,
                        verb: t.isCompleted ? "completed" : "added",
                        target: t.task,
                        when: t.createdAt
                    )
                }
        }

        private func relativeTime(_ d: Date) -> String {
            let interval = max(0, Date().timeIntervalSince(d))
            if interval < 60 { return "now" }
            if interval < 3600 { return "\(Int(interval / 60))m" }
            if interval < 86400 { return "\(Int(interval / 3600))h" }
            return "\(Int(interval / 86400))d"
        }

        private func memberFor(_ name: String) -> FamilyMember? {
            let trimmed = name.trimmingCharacters(in: .whitespaces).lowercased()
            guard !trimmed.isEmpty else { return nil }
            return members.first { $0.name.lowercased() == trimmed }
        }

        @ViewBuilder
        private var whatsNew: some View {
            if !activityFeed.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("WHAT'S NEW 💬").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                    VStack(spacing: 0) {
                        ForEach(Array(activityFeed.enumerated()), id: \.element.id) { i, a in
                            HStack(spacing: 12) {
                                if let m = memberFor(a.who) {
                                    CLAvatar(m.asCLMember, size: 30)
                                } else if !a.who.isEmpty {
                                    Text(String(a.who.prefix(1)).uppercased())
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 30, height: 30)
                                        .background(Circle().fill(P.peach.opacity(0.7)))
                                } else {
                                    Text("🔔").font(.system(size: 14))
                                        .frame(width: 30, height: 30).background(Circle().fill(P.surfaceAlt))
                                }
                                let displayName: String = {
                                    if let m = memberFor(a.who) { return m.name }
                                    if !a.who.isEmpty { return a.who }
                                    return "Casalist"
                                }()
                                let nameColor: Color = memberFor(a.who)?.color ?? P.text
                                (Text(displayName)
                                    .font(.system(size: 13, weight: .heavy))
                                    .foregroundColor(nameColor)
                                 + Text(" \(a.verb) ").font(.system(size: 13)).foregroundColor(P.textDim)
                                 + Text(a.target).font(.system(size: 13, weight: .semibold)))
                                .lineLimit(2)
                                Spacer()
                                Text(relativeTime(a.when)).font(.system(size: 10, weight: .heavy)).foregroundStyle(P.textMuted)
                            }.padding(.vertical, 11)
                            .overlay(alignment: .top) {
                                if i > 0 {
                                    Rectangle().fill(P.border).frame(height: 1)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
                }
            }
        }
    }

    // MARK: – Rewards
    public struct Rewards: View {
        @Environment(\.colorScheme) private var sys
        @State private var darkOverride: Bool? = nil
        @State private var showAddGoal: Bool = false
        @State private var showAddChore: Bool = false
        @Environment(\.dismiss) private var dismiss
        @Environment(\.managedObjectContext) private var modelContext
        @AppStorage("userName") private var userName: String = ""
        @AppStorage("meUid") private var meUid: String = ""
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)]) private var members: FetchedResults<FamilyMember>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyGoal.createdAt, ascending: true)]) private var goalsQuery: FetchedResults<FamilyGoal>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \ChoreTemplate.createdAt, ascending: true)]) private var choresQuery: FetchedResults<ChoreTemplate>
        public var onHome: (() -> Void)?
        private var dark: Bool { darkOverride ?? (sys == .dark) }
        private var P: Palette { Palette.resolve(dark) }
        private var sorted: [FamilyMember] { members.sorted { $0.points > $1.points } }
        private var topScore: Int { Int(sorted.first?.points ?? 0) }
        private var canManagePoints: Bool {
            FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)?.canManageFamily ?? false
        }
        public init(onHome: (() -> Void)? = nil) { self.onHome = onHome }

        public var body: some View {
            ZStack {
                P.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                    ScrollView { content }.scrollIndicators(.hidden)
                }
            }
            .foregroundStyle(P.text)
            .preferredColorScheme(dark ? .dark : .light)
            .sheet(isPresented: $showAddGoal) { AddGoalView() }
            .sheet(isPresented: $showAddChore) { AddChoreView() }
        }

        private var topBar: some View {
            HStack {
                Button { if let onHome { onHome() } else { dismiss() } } label: {
                    Image(systemName: "house.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(P.text)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(P.surfaceAlt))
                }
                Spacer()
                Button { darkOverride = !dark } label: {
                    Image(systemName: dark ? "sun.max.fill" : "moon.fill").font(.system(size: 14)).foregroundStyle(P.text)
                        .frame(width: 38, height: 38).background(Circle().fill(P.surfaceAlt))
                }
            }.padding(.horizontal, 16).padding(.bottom, 12)
        }

        private var content: some View {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CHORE REWARDS 🏆").font(.system(size: 12, weight: .heavy)).tracking(1.2).foregroundStyle(P.peach)
                    Text("Family Leaderboard").font(.system(size: 28, weight: .heavy))
                }
                podium
                standings
                goals
                available
            }.padding(.horizontal, 20).padding(.bottom, 28)
        }

        private var podium: some View {
            Group {
                if sorted.count >= 3 {
                    HStack(alignment: .bottom, spacing: 14) {
                        ForEach(Array([sorted[1], sorted[0], sorted[2]].enumerated()), id: \.element.uid) { idx, m in
                            let place = idx == 1 ? 1 : (idx == 0 ? 2 : 3)
                            let sz: CGFloat = place == 1 ? 64 : 50
                            let podH: CGFloat = place == 1 ? 68 : (place == 2 ? 48 : 36)
                            let podColor = place == 1 ? P.peach : (place == 2 ? P.coral : P.mint)
                            VStack(spacing: 6) {
                                CLAvatar(m.asCLMember, size: sz)
                                Text(m.name).font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(rgb: 0x3B2A22))
                                Text("\(m.points) pts").font(.system(size: 11, weight: .bold)).foregroundStyle(Color(rgb: 0x3B2A22).opacity(0.7))
                                Text(["🥇","🥈","🥉"][place - 1]).font(.system(size: 24, weight: .heavy))
                                    .frame(maxWidth: .infinity).frame(height: podH)
                                    .background(UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12).fill(podColor))
                            }.frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 18).padding(.top, 20).padding(.bottom, 0)
                    .background(RoundedRectangle(cornerRadius: 32).fill(P.butter))
                } else {
                    VStack(spacing: 8) {
                        Text("🏆").font(.system(size: 40))
                        Text("Add 3+ family members for a podium").font(.system(size: 13, weight: .heavy))
                    }
                    .foregroundStyle(Color(rgb: 0x3B2A22))
                    .frame(maxWidth: .infinity).padding(24)
                    .background(RoundedRectangle(cornerRadius: 32).fill(P.butter))
                }
            }
        }

        private var standings: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("STANDINGS").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                VStack(spacing: 0) {
                    ForEach(Array(sorted.enumerated()), id: \.element.uid) { i, m in
                        HStack(spacing: 12) {
                            Text(["🥇","🥈","🥉","4️⃣"][min(i, 3)]).font(.system(size: 20))
                            CLAvatar(m.asCLMember, size: 36)
                            VStack(spacing: 5) {
                                HStack(spacing: 8) {
                                    Text(m.name).font(.system(size: 14, weight: .heavy))
                                    Spacer()
                                    if canManagePoints {
                                        Button { adjustPoints(m, by: -5) } label: {
                                            Image(systemName: "minus").font(.system(size: 11, weight: .heavy))
                                                .frame(width: 22, height: 22)
                                                .background(Circle().fill(P.surfaceAlt))
                                                .foregroundStyle(P.text)
                                        }.buttonStyle(.plain)
                                    }
                                    Text("\(m.points) pts").font(.system(size: 14, weight: .heavy)).foregroundStyle(m.color).monospacedDigit()
                                    if canManagePoints {
                                        Button { adjustPoints(m, by: 5) } label: {
                                            Image(systemName: "plus").font(.system(size: 11, weight: .heavy))
                                                .frame(width: 22, height: 22)
                                                .background(Circle().fill(P.peach.opacity(0.2)))
                                                .foregroundStyle(P.peach)
                                        }.buttonStyle(.plain)
                                    }
                                }
                                GeometryReader { g in
                                    RoundedRectangle(cornerRadius: 3).fill(P.surfaceAlt).overlay(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3).fill(m.color)
                                            .frame(width: g.size.width * CGFloat(m.points) / CGFloat(max(topScore, 1)))
                                    }
                                }.frame(height: 6)
                            }
                        }.padding(.vertical, 11)
                        .overlay(alignment: .top) {
                            if i > 0 { Rectangle().fill(P.border).frame(height: 1) }
                        }
                    }
                    if sorted.isEmpty {
                        Text("No family members yet").font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(P.textMuted).padding(.vertical, 24)
                    }
                }
                .padding(.horizontal, 16)
                .background(RoundedRectangle(cornerRadius: 24).fill(P.surface))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(P.border, lineWidth: 1.5))
            }
        }

        private func memberFor(_ name: String) -> FamilyMember? {
            let trimmed = name.lowercased()
            return members.first { $0.name.lowercased() == trimmed }
        }

        private var goals: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("SAVING UP FOR…").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                    Spacer()
                    Button { showAddGoal = true } label: {
                        Label("Add", systemImage: "plus")
                            .font(.system(size: 11, weight: .heavy)).foregroundStyle(P.peach).padding(.trailing, 4)
                    }
                }
                if goalsQuery.isEmpty {
                    Button { showAddGoal = true } label: {
                        VStack(spacing: 6) {
                            Text("🎯").font(.system(size: 30))
                            Text("Add a goal").font(.system(size: 13, weight: .heavy)).foregroundStyle(P.text)
                            Text("Set a points target for what you're saving up for").font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textDim).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(20)
                        .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
                    }.buttonStyle(.plain)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(goalsQuery) { g in
                            goalCard(g)
                        }
                    }
                }
            }
        }

        private func goalCard(_ g: FamilyGoal) -> some View {
            let m = memberFor(g.ownerName)
            let memberPoints = m?.points ?? 0
            let progress = min(memberPoints, g.targetPoints)
            let color = m?.color ?? P.peach
            return VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    if let m { CLAvatar(m.asCLMember, size: 26) }
                    Text(g.ownerName).font(.system(size: 12, weight: .heavy))
                    Spacer()
                    Button {
                        modelContext.delete(g)
                        try? modelContext.save()
                    } label: {
                        Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(P.textMuted)
                    }.buttonStyle(.plain)
                }
                Text(g.label).font(.system(size: 13, weight: .bold)).foregroundStyle(P.text)
                Text("\(progress) / \(g.targetPoints) pts").font(.system(size: 11, weight: .bold)).foregroundStyle(P.textMuted)
                GeometryReader { gg in
                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.15)).overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(color)
                            .frame(width: gg.size.width * CGFloat(progress) / CGFloat(g.targetPoints))
                    }
                }.frame(height: 8)
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22).fill(color.opacity(0.15)))
        }

        private var available: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("EARN POINTS 💪").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                    Spacer()
                    Button { showAddChore = true } label: {
                        Label("Add", systemImage: "plus")
                            .font(.system(size: 11, weight: .heavy)).foregroundStyle(P.peach).padding(.trailing, 4)
                    }
                }
                if choresQuery.isEmpty {
                    Button { showAddChore = true } label: {
                        VStack(spacing: 6) {
                            Text("💪").font(.system(size: 30))
                            Text("Add a chore").font(.system(size: 13, weight: .heavy)).foregroundStyle(P.text)
                            Text("Family members tap Claim to earn points for finishing it").font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textDim).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(20)
                        .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
                    }.buttonStyle(.plain)
                } else {
                    VStack(spacing: 8) {
                        ForEach(choresQuery) { c in
                            choreRow(c)
                        }
                    }
                }
            }
        }

        private func choreRow(_ c: ChoreTemplate) -> some View {
            HStack(spacing: 12) {
                Image(systemName: c.symbol).font(.system(size: 14)).foregroundStyle(P.peach)
                    .frame(width: 36, height: 36).background(Circle().fill(P.peach.opacity(0.2)))
                Text(c.label).font(.system(size: 14, weight: .heavy))
                Spacer()
                Text("⭐ \(c.points)").font(.system(size: 12, weight: .heavy))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(P.butter))
                    .foregroundStyle(.white)
                Button { claim(c) } label: {
                    Text("Claim").font(.system(size: 12, weight: .heavy)).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Capsule().fill(P.peach))
                }.buttonStyle(.plain)
                Button {
                    modelContext.delete(c)
                    try? modelContext.save()
                } label: {
                    Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(P.textMuted)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 20).fill(P.surface))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(P.border, lineWidth: 1.5))
        }

        private func adjustPoints(_ m: FamilyMember, by delta: Int) {
            m.points = max(0, m.points + Int64(delta))
            try? modelContext.save()
        }

        private func claim(_ c: ChoreTemplate) {
            let me = userName.trimmingCharacters(in: .whitespaces)
            let item = TaskItem(
                context: modelContext,
                task: c.label,
                assignee: me.isEmpty ? nil : me,
                category: "Chores",
                isCompleted: false,
                points: Int(c.points),
                createdBy: me
            )
            if let h = c.household {
                modelContext.assign(item, toStoreOf: h)
                item.household = h
            }
            try? modelContext.save()
        }
    }
}

extension CasalistCottage {

    public struct MyToDo: View {
        @Environment(\.colorScheme) private var sys
        @Environment(\.dismiss) private var dismiss
        @Environment(\.managedObjectContext) private var modelContext
        @State private var darkOverride: Bool? = nil
        @State private var filter: String = "Today"
        @State private var showAddTodo = false
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.dueDate, ascending: true)]) private var todos: FetchedResults<TaskItem>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)]) private var members: FetchedResults<FamilyMember>
        public var onHome: (() -> Void)?
        private var dark: Bool { darkOverride ?? (sys == .dark) }
        private var P: Palette { Palette.resolve(dark) }
        public init(onHome: (() -> Void)? = nil) { self.onHome = onHome }

        private func isModuleCategory(_ cat: String) -> Bool {
            ["groceries", "maintenance", "reminders"].contains(cat.lowercased())
        }
        private var incomplete: [TaskItem] { todos.filter { !$0.isCompleted && !isModuleCategory($0.category) } }
        private var completed: [TaskItem] { todos.filter { $0.isCompleted && !isModuleCategory($0.category) } }
        private func isToday(_ d: Date?) -> Bool {
            guard let d else { return false }
            return Calendar.current.isDateInToday(d)
        }
        private func isThisWeek(_ d: Date?) -> Bool {
            guard let d else { return false }
            return Calendar.current.isDate(d, equalTo: Date(), toGranularity: .weekOfYear)
        }
        private var todayItems: [TaskItem] { incomplete.filter { isToday($0.dueDate) } }
        private var weekItems: [TaskItem] { incomplete.filter { isThisWeek($0.dueDate) } }
        private var visibleItems: [TaskItem] {
            switch filter {
            case "Today": return todayItems
            case "This week": return weekItems
            default: return incomplete
            }
        }
        private var doneTodayCount: Int { completed.filter { isToday($0.dueDate) }.count }
        private var totalTodayCount: Int { todos.filter { isToday($0.dueDate) }.count }
        private var donePercent: Double {
            guard totalTodayCount > 0 else { return 0 }
            return Double(doneTodayCount) / Double(totalTodayCount)
        }
        private func categoryColor(_ cat: String) -> Color {
            switch cat.lowercased() {
            case "chores": return P.mint
            case "kitchen": return P.butter
            case "groceries": return P.coral
            case "maintenance": return P.lavender
            default: return P.peach
            }
        }
        private func categorySymbol(_ cat: String) -> String {
            switch cat.lowercased() {
            case "chores": return "checkmark.circle.fill"
            case "kitchen": return "fork.knife"
            case "groceries": return "cart.fill"
            case "maintenance": return "wrench.fill"
            default: return "circle.fill"
            }
        }
        private func memberFor(_ assignee: String?) -> CLFamilyMember? {
            guard let assignee, !assignee.isEmpty else { return nil }
            return members.first { $0.name.lowercased() == assignee.lowercased() }?.asCLMember
        }
        private func whenString(_ d: Date?) -> String {
            guard let d else { return "No date" }
            let f = DateFormatter()
            if Calendar.current.isDateInToday(d) {
                f.dateFormat = "h:mm a"
                return "Today \(f.string(from: d))"
            }
            f.dateFormat = "EEE MMM d"
            return f.string(from: d)
        }

        public var body: some View {
            ZStack {
                P.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                    ScrollView { content }.scrollIndicators(.hidden)
                }
            }
            .foregroundStyle(P.text)
            .preferredColorScheme(dark ? .dark : .light)
            .navigationBarBackButtonHidden()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddTodo) { AddTaskView() }
        }

        private var topBar: some View {
            HStack {
                Button { if let onHome { onHome() } else { dismiss() } } label: {
                    Image(systemName: "house.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(P.text)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(P.surfaceAlt))
                }
                Spacer()
                Button { darkOverride = !dark } label: {
                    Image(systemName: dark ? "sun.max.fill" : "moon.fill").font(.system(size: 14)).foregroundStyle(P.text)
                        .frame(width: 38, height: 38).background(Circle().fill(P.surfaceAlt))
                }
                Button { showAddTodo = true } label: {
                    Image(systemName: "plus").font(.system(size: 19, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(P.peach))
                        .shadow(color: P.peach.opacity(0.4), radius: 8, y: 4)
                }
            }.padding(.horizontal, 16).padding(.bottom, 12)
        }

        private var content: some View {
            VStack(alignment: .leading, spacing: 14) {
                progressHero
                quickAdd
                filters
                byKind
                forToday
                recentlyDone
            }.padding(.horizontal, 20).padding(.bottom, 28)
        }

        private var progressHero: some View {
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.25), lineWidth: 6).frame(width: 76, height: 76)
                    Circle().trim(from: 0, to: donePercent)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 76, height: 76)
                    VStack(spacing: 0) {
                        Text("\(Int(donePercent * 100))%").font(.system(size: 18, weight: .heavy))
                        Text("DONE").font(.system(size: 8, weight: .heavy)).tracking(0.8).opacity(0.85)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("MY TO-DO").font(.system(size: 11, weight: .heavy)).tracking(0.8).opacity(0.85)
                    Text("\(todayItems.count) left for today").font(.system(size: 22, weight: .heavy))
                    Text(totalTodayCount == 0 ? "Nothing scheduled" : "\(doneTodayCount) of \(totalTodayCount) done").font(.system(size: 12, weight: .semibold)).opacity(0.85)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(20)
            .background(P.coral)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }

        private var quickAdd: some View {
            Button { showAddTodo = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle").font(.system(size: 18)).foregroundStyle(P.textDim)
                    Text("Add to your list...").font(.system(size: 14, weight: .semibold)).foregroundStyle(P.textDim)
                    Spacer()
                    Image(systemName: "arrow.up").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white)
                        .frame(width: 32, height: 32).background(Circle().fill(P.peach))
                }
                .padding(.horizontal, 16).padding(.vertical, 4).padding(.trailing, 4)
                .background(Capsule().fill(P.surface))
                .overlay(Capsule().stroke(P.border, lineWidth: 1.5))
            }.buttonStyle(.plain)
        }

        private var filters: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    pill("Today", count: todayItems.count)
                    pill("This week", count: weekItems.count)
                    pill("All", count: incomplete.count)
                }
            }
        }

        private func pill(_ label: String, count: Int) -> some View {
            let active = filter == label
            return Button { filter = label } label: {
                HStack(spacing: 8) {
                    Text(label).font(.system(size: 13, weight: .heavy))
                    Text("\(count)").font(.system(size: 11, weight: .heavy))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.black.opacity(0.25)))
                }
                .foregroundStyle(active ? .white : P.textDim)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(active ? P.peach : P.surfaceAlt))
            }
        }

        private var byKind: some View {
            let counts = Dictionary(grouping: incomplete, by: { $0.category }).mapValues { $0.count }
            return VStack(alignment: .leading, spacing: 8) {
                Text("BY KIND").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        kindChip(emoji: "🧹", label: "Chores", color: P.mint, count: counts["Chores"] ?? 0)
                        kindChip(emoji: "🍴", label: "Kitchen", color: P.butter, count: counts["kitchen"] ?? 0)
                        kindChip(emoji: "🛒", label: "Groceries", color: P.coral, count: counts["groceries"] ?? 0)
                        kindChip(emoji: "🔧", label: "Maintenance", color: P.lavender, count: counts["Maintenance"] ?? 0)
                    }
                }
            }
        }

        private func kindChip(emoji: String, label: String, color: Color, count: Int) -> some View {
            HStack(spacing: 8) {
                Text(emoji).font(.system(size: 14))
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.3)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.system(size: 12, weight: .heavy))
                    Text("\(count) open").font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 16).fill(P.surface))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(P.border, lineWidth: 1.5))
        }

        private var filterHeader: String {
            switch filter {
            case "Today": return "FOR TODAY ☀️"
            case "This week": return "THIS WEEK 📅"
            default: return "ALL OPEN ✨"
            }
        }

        private var forToday: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(filterHeader).font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                    Spacer()
                    Text("\(visibleItems.count) items").font(.system(size: 11, weight: .heavy)).foregroundStyle(P.textMuted).padding(.trailing, 4)
                }
                if visibleItems.isEmpty {
                    Button { showAddTodo = true } label: {
                        VStack(spacing: 8) {
                            Text("📝").font(.system(size: 36))
                            Text("Nothing here yet").font(.system(size: 14, weight: .heavy))
                            Text("Tap to add your first task").font(.system(size: 11, weight: .semibold)).opacity(0.7)
                        }
                        .foregroundStyle(P.text)
                        .frame(maxWidth: .infinity).padding(24)
                        .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
                    }.buttonStyle(.plain)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(visibleItems.enumerated()), id: \.element.id) { i, t in
                            todoRow(t, isFirst: i == 0)
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
                }
            }
        }

        private func todoRow(_ t: TaskItem, isFirst: Bool) -> some View {
            let color = categoryColor(t.category)
            return HStack(spacing: 12) {
                Button { FamilyPoints.toggle(t, in: members); try? modelContext.save() } label: {
                    Circle().stroke(color, lineWidth: 2).frame(width: 22, height: 22)
                }.buttonStyle(.plain)
                Image(systemName: categorySymbol(t.category)).font(.system(size: 14)).foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 10).fill(color))
                VStack(alignment: .leading, spacing: 3) {
                    Text(t.task).font(.system(size: 14, weight: .heavy))
                    HStack(spacing: 6) {
                        Circle().fill(color).frame(width: 6, height: 6)
                        Text(whenString(t.dueDate)).font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textDim)
                        if !t.category.isEmpty {
                            Text("·").font(.system(size: 11)).foregroundStyle(P.textMuted)
                            Text(t.category.capitalized).font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textDim)
                        }
                    }
                }
                Spacer()
                if let cl = memberFor(t.assignee) { CLAvatar(cl, size: 26) }
            }.padding(.vertical, 11)
            .overlay(alignment: .top) {
                if !isFirst { Rectangle().fill(P.border).frame(height: 1) }
            }
        }

        private var recentlyDone: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("RECENTLY DONE 🎉").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                    Spacer()
                    if !completed.isEmpty {
                        Text("\(completed.count) done").font(.system(size: 11, weight: .heavy)).foregroundStyle(P.peach).padding(.trailing, 4)
                    }
                }
                if !completed.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(completed.prefix(5).enumerated()), id: \.element.id) { i, t in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundStyle(P.mint)
                                Text(t.task).font(.system(size: 13, weight: .semibold)).strikethrough().foregroundStyle(P.textDim)
                                Spacer()
                                if let cl = memberFor(t.assignee) { CLAvatar(cl, size: 22) }
                            }.padding(.vertical, 10)
                            .overlay(alignment: .top) {
                                if i > 0 { Rectangle().fill(P.border).frame(height: 1) }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
                }
            }
        }
    }
}

extension CasalistCottage {

    public struct Grocery: View {
        @Environment(\.colorScheme) private var sys
        @Environment(\.dismiss) private var dismiss
        @Environment(\.managedObjectContext) private var modelContext
        @State private var darkOverride: Bool? = nil
        @State private var newItem: String = ""
        @State private var showAdd = false
        @State private var newItemByTrip: [String: String] = [:]
        @AppStorage("userName") private var userName: String = ""
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: false)]) private var allTasks: FetchedResults<TaskItem>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)]) private var members: FetchedResults<FamilyMember>
        private var dark: Bool { darkOverride ?? (sys == .dark) }
        private var P: Palette { Palette.resolve(dark) }
        public init() {}

        private var groceryTasks: [TaskItem] { allTasks.filter { $0.category.lowercased() == "groceries" } }
        // A "trip" is a top-level grocery task with a dueDate (shows in agenda).
        private var trips: [TaskItem] {
            groceryTasks.filter { $0.parentUid.isEmpty && $0.dueDate != nil }
                .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        }
        // Flat items: top-level grocery tasks without a dueDate (the existing quick-add behavior).
        private var flatActive: [TaskItem] {
            groceryTasks.filter { $0.parentUid.isEmpty && $0.dueDate == nil && !$0.isCompleted }
        }
        private var flatBought: [TaskItem] {
            groceryTasks.filter { $0.parentUid.isEmpty && $0.dueDate == nil && $0.isCompleted }
        }
        private func items(in trip: TaskItem) -> [TaskItem] {
            groceryTasks.filter { $0.parentUid == trip.uid }
        }
        private var activeCount: Int {
            flatActive.count + trips.reduce(0) { $0 + items(in: $1).filter { !$0.isCompleted }.count }
        }
        private var boughtCount: Int {
            flatBought.count + trips.reduce(0) { $0 + items(in: $1).filter { $0.isCompleted }.count }
        }

        public var body: some View {
            ZStack {
                P.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                    ScrollView { content }.scrollIndicators(.hidden)
                }
            }
            .foregroundStyle(P.text)
            .preferredColorScheme(dark ? .dark : .light)
            .sheet(isPresented: $showAdd) { AddGroceryTripView() }
        }

        private var topBar: some View {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "house.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(P.text)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(P.surfaceAlt))
                }
                Spacer()
                Button { darkOverride = !dark } label: {
                    Image(systemName: dark ? "sun.max.fill" : "moon.fill").font(.system(size: 14)).foregroundStyle(P.text)
                        .frame(width: 38, height: 38).background(Circle().fill(P.surfaceAlt))
                }
                Button { showAdd = true } label: {
                    Image(systemName: "plus").font(.system(size: 19, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(P.peach))
                        .shadow(color: P.peach.opacity(0.4), radius: 8, y: 4)
                }
            }.padding(.horizontal, 16).padding(.bottom, 12)
        }

        private var content: some View {
            VStack(alignment: .leading, spacing: 14) {
                hero
                quickAddRow
                if !trips.isEmpty { tripsSection }
                flatActiveSection
                boughtSection
            }.padding(.horizontal, 20).padding(.bottom, 28)
        }

        private var hero: some View {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.2)).frame(width: 76, height: 76)
                    Text("🛒").font(.system(size: 36))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("GROCERY").font(.system(size: 11, weight: .heavy)).tracking(0.8).opacity(0.85)
                    Text("\(activeCount) to get").font(.system(size: 22, weight: .heavy))
                    Text(boughtCount == 0 ? "Tap + to plan a trip" : "\(boughtCount) in the cart").font(.system(size: 12, weight: .semibold)).opacity(0.85)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white).padding(20)
            .background(P.mint)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }

        private var quickAddRow: some View {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle").font(.system(size: 18)).foregroundStyle(P.textDim)
                TextField("Milk, eggs, bread…", text: $newItem)
                    .font(.system(size: 14, weight: .semibold))
                    .submitLabel(.done)
                    .onSubmit(addInlineItem)
                Button { addInlineItem() } label: {
                    Image(systemName: "arrow.up").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white)
                        .frame(width: 32, height: 32).background(Circle().fill(P.peach))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 4).padding(.trailing, 4)
            .background(Capsule().fill(P.surface))
            .overlay(Capsule().stroke(P.border, lineWidth: 1.5))
        }

        private func addInlineItem() {
            let name = newItem.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }
            let it = TaskItem(
                context: modelContext,
                task: name,
                category: "groceries",
                points: 0,
                createdBy: userName.trimmingCharacters(in: .whitespaces)
            )
            if let h = allTasks.first?.household {
                modelContext.assign(it, toStoreOf: h)
                it.household = h
            }
            try? modelContext.save()
            newItem = ""
        }

        private func tripDateText(_ d: Date) -> String {
            let f = DateFormatter()
            if Calendar.current.isDateInToday(d) { f.dateFormat = "'Today' h:mm a" }
            else if Calendar.current.isDateInTomorrow(d) { f.dateFormat = "'Tmrw' h:mm a" }
            else { f.dateFormat = "MMM d · h:mm a" }
            return f.string(from: d)
        }

        @ViewBuilder
        private var tripsSection: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("SHOPPING TRIPS 🛍️").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                    Spacer()
                    Text("\(trips.count)").font(.system(size: 11, weight: .heavy)).foregroundStyle(P.textMuted).padding(.trailing, 4)
                }
                ForEach(trips) { trip in
                    tripCard(trip)
                }
            }
        }

        private func tripCard(_ trip: TaskItem) -> some View {
            let tripItems = items(in: trip)
            let openItems = tripItems.filter { !$0.isCompleted }
            return VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(trip.task).font(.system(size: 16, weight: .heavy))
                    Spacer()
                    if let due = trip.dueDate {
                        Text(tripDateText(due))
                            .font(.system(size: 10, weight: .heavy))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Capsule().fill(P.peach.opacity(0.25)))
                            .foregroundStyle(P.peach)
                    }
                    Button {
                        for it in tripItems { modelContext.delete(it) }
                        modelContext.delete(trip)
                        try? modelContext.save()
                    } label: {
                        Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(P.textMuted)
                    }.buttonStyle(.plain)
                }
                if tripItems.isEmpty {
                    Text("No items yet — add below").font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textMuted).padding(.leading, 4)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(tripItems.enumerated()), id: \.element.id) { i, t in
                            HStack(spacing: 12) {
                                Button { FamilyPoints.toggle(t, in: members); try? modelContext.save() } label: {
                                    if t.isCompleted {
                                        Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundStyle(P.mint)
                                    } else {
                                        Circle().stroke(P.mint, lineWidth: 2).frame(width: 20, height: 20)
                                    }
                                }.buttonStyle(.plain)
                                Text(t.task)
                                    .font(.system(size: 13, weight: .semibold))
                                    .strikethrough(t.isCompleted)
                                    .foregroundStyle(t.isCompleted ? P.textDim : P.text)
                                Spacer()
                                Button { modelContext.delete(t); try? modelContext.save() } label: {
                                    Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(P.textMuted)
                                }.buttonStyle(.plain)
                            }.padding(.vertical, 9)
                            .overlay(alignment: .top) {
                                if i > 0 { Rectangle().fill(P.border).frame(height: 1) }
                            }
                        }
                    }
                    .padding(.leading, 16)
                }
                tripInlineAdd(trip)
                if !openItems.isEmpty {
                    Text("\(openItems.count) to get").font(.system(size: 10, weight: .heavy)).foregroundStyle(P.textMuted).padding(.leading, 4)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
        }

        private func tripInlineAdd(_ trip: TaskItem) -> some View {
            let key = trip.uid
            let binding = Binding<String>(
                get: { newItemByTrip[key] ?? "" },
                set: { newItemByTrip[key] = $0 }
            )
            return HStack(spacing: 10) {
                Image(systemName: "plus.circle").font(.system(size: 16)).foregroundStyle(P.textDim)
                TextField("Add to \(trip.task)…", text: binding)
                    .font(.system(size: 13, weight: .semibold))
                    .submitLabel(.done)
                    .onSubmit { addItem(to: trip) }
                Button { addItem(to: trip) } label: {
                    Image(systemName: "arrow.up").font(.system(size: 12, weight: .heavy)).foregroundStyle(.white)
                        .frame(width: 26, height: 26).background(Circle().fill(P.mint))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.vertical, 4).padding(.trailing, 4)
            .background(Capsule().fill(P.surfaceAlt))
            .overlay(Capsule().stroke(P.border, lineWidth: 1.5))
        }

        private func addItem(to trip: TaskItem) {
            let key = trip.uid
            let name = (newItemByTrip[key] ?? "").trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }
            let item = TaskItem(
                context: modelContext,
                task: name,
                category: "groceries",
                points: 0,
                createdBy: userName.trimmingCharacters(in: .whitespaces),
                parentUid: trip.uid
            )
            if let h = trip.household {
                modelContext.assign(item, toStoreOf: h)
                item.household = h
            }
            try? modelContext.save()
            newItemByTrip[key] = ""
        }

        @ViewBuilder
        private var flatActiveSection: some View {
            if !flatActive.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("OTHER ITEMS").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                        Spacer()
                        Text("\(flatActive.count)").font(.system(size: 11, weight: .heavy)).foregroundStyle(P.textMuted).padding(.trailing, 4)
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(flatActive.enumerated()), id: \.element.id) { i, t in
                            row(t, isFirst: i == 0)
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
                }
            } else if trips.isEmpty {
                VStack(spacing: 8) {
                    Text("🥗").font(.system(size: 36))
                    Text("Cart is empty").font(.system(size: 14, weight: .heavy))
                    Text("Quick-add above, or tap + for a planned trip").font(.system(size: 11, weight: .semibold)).opacity(0.7)
                }
                .foregroundStyle(P.text)
                .frame(maxWidth: .infinity).padding(24)
                .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
            }
        }

        private func row(_ t: TaskItem, isFirst: Bool) -> some View {
            HStack(spacing: 12) {
                Button { FamilyPoints.toggle(t, in: members); try? modelContext.save() } label: {
                    Circle().stroke(P.mint, lineWidth: 2).frame(width: 22, height: 22)
                }.buttonStyle(.plain)
                Text(t.task).font(.system(size: 14, weight: .heavy))
                Spacer()
                Button { modelContext.delete(t); try? modelContext.save() } label: {
                    Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(P.textMuted)
                }.buttonStyle(.plain)
            }.padding(.vertical, 12)
            .overlay(alignment: .top) {
                if !isFirst { Rectangle().fill(P.border).frame(height: 1) }
            }
        }

        @ViewBuilder
        private var boughtSection: some View {
            if !flatBought.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("IN THE CART ✓").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                        Spacer()
                        Button { clearBought() } label: {
                            Text("Clear").font(.system(size: 11, weight: .heavy)).foregroundStyle(P.peach).padding(.trailing, 4)
                        }
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(flatBought.prefix(10).enumerated()), id: \.element.id) { i, t in
                            HStack(spacing: 12) {
                                Button { FamilyPoints.toggle(t, in: members); try? modelContext.save() } label: {
                                    Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundStyle(P.mint)
                                }.buttonStyle(.plain)
                                Text(t.task).font(.system(size: 13, weight: .semibold)).strikethrough().foregroundStyle(P.textDim)
                                Spacer()
                            }.padding(.vertical, 10)
                            .overlay(alignment: .top) {
                                if i > 0 { Rectangle().fill(P.border).frame(height: 1) }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
                }
            }
        }

        private func clearBought() {
            for t in flatBought { modelContext.delete(t) }
            try? modelContext.save()
        }
    }

    public struct Maintenance: View {
        @Environment(\.colorScheme) private var sys
        @Environment(\.dismiss) private var dismiss
        @Environment(\.managedObjectContext) private var modelContext
        @State private var darkOverride: Bool? = nil
        @State private var showAdd = false
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.dueDate, ascending: true)]) private var allTasks: FetchedResults<TaskItem>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)]) private var members: FetchedResults<FamilyMember>
        private var dark: Bool { darkOverride ?? (sys == .dark) }
        private var P: Palette { Palette.resolve(dark) }
        public init() {}

        private var maintenanceTasks: [TaskItem] { allTasks.filter { $0.category.lowercased() == "maintenance" } }
        private var active: [TaskItem] { maintenanceTasks.filter { !$0.isCompleted } }
        private var done: [TaskItem] { maintenanceTasks.filter { $0.isCompleted } }
        private var overdue: [TaskItem] {
            active.filter { ($0.dueDate ?? .distantFuture) < Date() }
        }
        private var dueSoon: [TaskItem] {
            let now = Date()
            let weekOut = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
            return active.filter { ($0.dueDate ?? .distantFuture) >= now && ($0.dueDate ?? .distantFuture) <= weekOut }
        }
        private var laterItems: [TaskItem] {
            let weekOut = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            return active.filter { ($0.dueDate ?? .distantFuture) > weekOut }
        }

        public var body: some View {
            ZStack {
                P.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                    ScrollView { content }.scrollIndicators(.hidden)
                }
            }
            .foregroundStyle(P.text)
            .preferredColorScheme(dark ? .dark : .light)
            .sheet(isPresented: $showAdd) { AddTaskView(defaultCategory: "Maintenance") }
        }

        private var topBar: some View {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "house.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(P.text)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(P.surfaceAlt))
                }
                Spacer()
                Button { darkOverride = !dark } label: {
                    Image(systemName: dark ? "sun.max.fill" : "moon.fill").font(.system(size: 14)).foregroundStyle(P.text)
                        .frame(width: 38, height: 38).background(Circle().fill(P.surfaceAlt))
                }
                Button { showAdd = true } label: {
                    Image(systemName: "plus").font(.system(size: 19, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(P.peach))
                        .shadow(color: P.peach.opacity(0.4), radius: 8, y: 4)
                }
            }.padding(.horizontal, 16).padding(.bottom, 12)
        }

        private var content: some View {
            VStack(alignment: .leading, spacing: 14) {
                hero
                if active.isEmpty && done.isEmpty {
                    emptyCard
                } else {
                    section(title: "OVERDUE ⚠️", items: overdue, color: P.coral)
                    section(title: "DUE THIS WEEK 📅", items: dueSoon, color: P.butter)
                    section(title: "UPCOMING", items: laterItems, color: P.lavender)
                    section(title: "DONE ✓", items: done.suffix(5).map { $0 }, color: P.mint, completed: true)
                }
            }.padding(.horizontal, 20).padding(.bottom, 28)
        }

        private var hero: some View {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.2)).frame(width: 76, height: 76)
                    Image(systemName: "wrench.and.screwdriver.fill").font(.system(size: 32)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("MAINTENANCE").font(.system(size: 11, weight: .heavy)).tracking(0.8).opacity(0.85)
                    Text("\(active.count) on the list").font(.system(size: 22, weight: .heavy))
                    Text(overdue.isEmpty ? "All good" : "\(overdue.count) overdue").font(.system(size: 12, weight: .semibold)).opacity(0.85)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white).padding(20)
            .background(P.lavender)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }

        private var emptyCard: some View {
            Button { showAdd = true } label: {
                VStack(spacing: 8) {
                    Text("🔧").font(.system(size: 36))
                    Text("Nothing scheduled").font(.system(size: 14, weight: .heavy))
                    Text("Tap + to add a maintenance task").font(.system(size: 11, weight: .semibold)).opacity(0.7)
                }
                .foregroundStyle(P.text)
                .frame(maxWidth: .infinity).padding(24)
                .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
            }.buttonStyle(.plain)
        }

        @ViewBuilder
        private func section(title: String, items: [TaskItem], color: Color, completed: Bool = false) -> some View {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(title).font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                        Spacer()
                        Text("\(items.count)").font(.system(size: 11, weight: .heavy)).foregroundStyle(P.textMuted).padding(.trailing, 4)
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { i, t in
                            HStack(spacing: 12) {
                                Button { FamilyPoints.toggle(t, in: members); try? modelContext.save() } label: {
                                    if completed {
                                        Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundStyle(color)
                                    } else {
                                        Circle().stroke(color, lineWidth: 2).frame(width: 22, height: 22)
                                    }
                                }.buttonStyle(.plain)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(t.task).font(.system(size: 14, weight: .heavy))
                                        .strikethrough(completed)
                                        .foregroundStyle(completed ? P.textDim : P.text)
                                    if let due = t.dueDate {
                                        HStack(spacing: 6) {
                                            Circle().fill(color).frame(width: 6, height: 6)
                                            Text(dueString(due)).font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textDim)
                                        }
                                    }
                                }
                                Spacer()
                                Button { modelContext.delete(t) } label: {
                                    Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(P.textMuted)
                                }.buttonStyle(.plain)
                            }.padding(.vertical, 11)
                            .overlay(alignment: .top) {
                                if i > 0 { Rectangle().fill(P.border).frame(height: 1) }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
                }
            }
        }

        private func dueString(_ d: Date) -> String {
            let now = Date()
            let cal = Calendar.current
            if cal.isDateInToday(d) { return "Due today" }
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: d)).day ?? 0
            if days < 0 { return "\(-days) day\(days == -1 ? "" : "s") overdue" }
            if days == 1 { return "Tomorrow" }
            if days <= 7 { return "In \(days) days" }
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            return f.string(from: d)
        }
    }

    public struct Reminders: View {
        @Environment(\.colorScheme) private var sys
        @Environment(\.dismiss) private var dismiss
        @Environment(\.managedObjectContext) private var modelContext
        @State private var darkOverride: Bool? = nil
        @State private var newItem: String = ""
        @State private var showAddReminder: Bool = false
        @State private var editingReminder: TaskItem? = nil
        @State private var expandedHourlyIds: Set<NSManagedObjectID> = []
        @AppStorage("userName") private var userName: String = ""
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: false)]) private var allTasks: FetchedResults<TaskItem>
        private var dark: Bool { darkOverride ?? (sys == .dark) }
        private var P: Palette { Palette.resolve(dark) }
        public init() {}

        private var allReminders: [TaskItem] { allTasks.filter { $0.category.lowercased() == "reminders" } }
        private var hourlyReminders: [TaskItem] {
            allReminders.filter { $0.effectiveRepeatKind == "hourly" }
        }
        private var otherReminders: [TaskItem] {
            allReminders.filter { !$0.isCompleted && $0.effectiveRepeatKind != "hourly" }
        }
        private var pinned: [TaskItem] { otherReminders }

        private func iconFor(_ t: TaskItem) -> String {
            if !t.effectiveRepeatKind.isEmpty { return "arrow.triangle.2.circlepath" }
            if t.dueDate != nil { return "clock.fill" }
            return "pin.fill"
        }

        private func scheduleDetail(_ t: TaskItem) -> String? {
            let kind = t.effectiveRepeatKind
            let f = DateFormatter()
            switch kind {
            case "hourly":   return "Every hour"
            case "every2h":  return "Every 2h"
            case "every4h":  return "Every 4h"
            case "every8h":  return "Every 8h"
            case "every12h": return "Every 12h"
            case "daily":
                guard let due = t.dueDate else { return "Daily" }
                f.dateFormat = "'Daily at' h:mm a"
                return f.string(from: due)
            case "weekly":
                guard let due = t.dueDate else { return "Weekly" }
                f.dateFormat = "'Weekly' EEE h:mm a"
                return f.string(from: due)
            case "monthly":
                guard let due = t.dueDate else { return "Monthly" }
                let day = Calendar.current.component(.day, from: due)
                f.dateFormat = "h:mm a"
                return "Monthly day \(day) · \(f.string(from: due))"
            case "yearly":
                guard let due = t.dueDate else { return "Yearly" }
                f.dateFormat = "'Yearly' MMM d · h:mm a"
                return f.string(from: due)
            default:
                guard let due = t.dueDate else { return nil }
                if Calendar.current.isDateInToday(due) {
                    f.dateFormat = "'Today' h:mm a"
                } else if Calendar.current.isDateInTomorrow(due) {
                    f.dateFormat = "'Tmrw' h:mm a"
                } else {
                    f.dateFormat = "MMM d · h:mm a"
                }
                return f.string(from: due)
            }
        }

        public var body: some View {
            ZStack {
                P.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                    ScrollView { content }.scrollIndicators(.hidden)
                }
            }
            .foregroundStyle(P.text)
            .preferredColorScheme(dark ? .dark : .light)
            .sheet(isPresented: $showAddReminder) { AddReminderView() }
            .sheet(item: $editingReminder) { reminder in AddReminderView(editing: reminder) }
        }

        private var topBar: some View {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "house.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(P.text)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(P.surfaceAlt))
                }
                Spacer()
                Button { darkOverride = !dark } label: {
                    Image(systemName: dark ? "sun.max.fill" : "moon.fill").font(.system(size: 14)).foregroundStyle(P.text)
                        .frame(width: 38, height: 38).background(Circle().fill(P.surfaceAlt))
                }
                Button { showAddReminder = true } label: {
                    Image(systemName: "plus").font(.system(size: 19, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(P.peach))
                        .shadow(color: P.peach.opacity(0.4), radius: 8, y: 4)
                }
            }.padding(.horizontal, 16).padding(.bottom, 12)
        }

        private var content: some View {
            VStack(alignment: .leading, spacing: 14) {
                hero
                quickAddRow
                listSection
            }.padding(.horizontal, 20).padding(.bottom, 28)
        }

        private var hero: some View {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.2)).frame(width: 76, height: 76)
                    Text("📌").font(.system(size: 36))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("REMINDERS").font(.system(size: 11, weight: .heavy)).tracking(0.8).opacity(0.85)
                    Text("\(pinned.count) pinned").font(.system(size: 22, weight: .heavy))
                    Text(pinned.isEmpty ? "Pin info you reference often" : "Tap an item to remove it").font(.system(size: 12, weight: .semibold)).opacity(0.85)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white).padding(20)
            .background(P.coral)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }

        private var quickAddRow: some View {
            HStack(spacing: 10) {
                Image(systemName: "pin.fill").font(.system(size: 16)).foregroundStyle(P.textDim)
                TextField("Wi-Fi password, vet number…", text: $newItem)
                    .font(.system(size: 14, weight: .semibold))
                    .submitLabel(.done)
                    .onSubmit(addInlineItem)
                Button { addInlineItem() } label: {
                    Image(systemName: "plus").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white)
                        .frame(width: 32, height: 32).background(Circle().fill(P.peach))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 4).padding(.trailing, 4)
            .background(Capsule().fill(P.surface))
            .overlay(Capsule().stroke(P.border, lineWidth: 1.5))
        }

        private func addInlineItem() {
            let name = newItem.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }
            let it = TaskItem(
                context: modelContext,
                task: name,
                category: "reminders",
                points: 0,
                createdBy: userName.trimmingCharacters(in: .whitespaces)
            )
            if let h = allTasks.first?.household {
                modelContext.assign(it, toStoreOf: h)
                it.household = h
            }
            try? modelContext.save()
            newItem = ""
        }

        @ViewBuilder
        private var listSection: some View {
            VStack(alignment: .leading, spacing: 14) {
                if !hourlyReminders.isEmpty {
                    hourlySection
                }
                pinnedSection
            }
        }

        private var hourlySection: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("HOURLY ⟳").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                    Spacer()
                    Text("\(hourlyReminders.count)").font(.system(size: 11, weight: .heavy)).foregroundStyle(P.textMuted).padding(.trailing, 4)
                }
                VStack(spacing: 18) {
                    ForEach(hourlyReminders) { t in
                        hourlyStack(t)
                    }
                }
            }
        }

        /// The stack-of-completions view for one hourly reminder.
        /// One unchecked card on top, up to 3 dimmed/struck history cards behind.
        /// Tap the count footer to expand into a full vertical list.
        private func hourlyStack(_ t: TaskItem) -> some View {
            let isExpanded = expandedHourlyIds.contains(t.objectID)
            return VStack(spacing: 8) {
                if isExpanded {
                    hourlyCard(t, struckOut: false)
                    ForEach(0..<t.completionCount, id: \.self) { _ in
                        hourlyCard(t, struckOut: true)
                    }
                } else {
                    let stackedBehind = min(t.completionCount, 3)
                    ZStack(alignment: .top) {
                        ForEach((1...max(stackedBehind, 1)).reversed(), id: \.self) { layer in
                            if layer <= stackedBehind {
                                hourlyCard(t, struckOut: true)
                                    .scaleEffect(1 - CGFloat(layer) * 0.035, anchor: .top)
                                    .opacity(0.55 - Double(layer - 1) * 0.13)
                                    .offset(y: CGFloat(layer) * 12)
                                    .allowsHitTesting(false)
                            }
                        }
                        hourlyCard(t, struckOut: false)
                            .zIndex(100)
                    }
                    .padding(.bottom, CGFloat(stackedBehind) * 12)
                }

                if t.completionCount > 0 {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            if isExpanded {
                                expandedHourlyIds.remove(t.objectID)
                            } else {
                                expandedHourlyIds.insert(t.objectID)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .heavy))
                            Text(isExpanded
                                 ? "Hide history"
                                 : "Show all \(t.completionCount) completed")
                                .font(.system(size: 11, weight: .heavy))
                        }
                        .foregroundStyle(P.textDim)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(P.surfaceAlt))
                    }.buttonStyle(.plain)
                }
            }
        }

        private func hourlyCard(_ t: TaskItem, struckOut: Bool) -> some View {
            Button { editingReminder = t } label: {
                HStack(spacing: 14) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            t.completionCount += 1
                        }
                        try? modelContext.save()
                    } label: {
                        if struckOut {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(P.coral)
                        } else {
                            Circle()
                                .stroke(P.coral, lineWidth: 2)
                                .frame(width: 24, height: 24)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(struckOut)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t.task)
                            .font(.system(size: 16, weight: .heavy))
                            .strikethrough(struckOut)
                            .foregroundStyle(struckOut ? P.textDim : P.text)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10))
                                .foregroundStyle(P.coral)
                            Text(scheduleDetail(t) ?? "Every hour")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(P.textDim)
                        }
                    }
                    Spacer(minLength: 0)
                    if !struckOut {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(P.textMuted)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 20).fill(P.surface))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(P.border, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .disabled(struckOut)
        }

        @ViewBuilder
        private var pinnedSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("PINNED 📌").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                    Spacer()
                    Text("\(pinned.count)").font(.system(size: 11, weight: .heavy)).foregroundStyle(P.textMuted).padding(.trailing, 4)
                }
                if pinned.isEmpty && hourlyReminders.isEmpty {
                    VStack(spacing: 8) {
                        Text("📋").font(.system(size: 36))
                        Text("Nothing pinned").font(.system(size: 14, weight: .heavy))
                        Text("Add quick-reference info above").font(.system(size: 11, weight: .semibold)).opacity(0.7)
                    }
                    .foregroundStyle(P.text)
                    .frame(maxWidth: .infinity).padding(24)
                    .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
                } else if !pinned.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(pinned) { t in
                            Button { editingReminder = t } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: iconFor(t))
                                            .font(.system(size: 14))
                                            .foregroundStyle(P.coral)
                                        if let detail = scheduleDetail(t) {
                                            Text(detail)
                                                .font(.system(size: 10, weight: .heavy))
                                                .foregroundStyle(P.textDim)
                                                .lineLimit(1)
                                        }
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10, weight: .heavy))
                                            .foregroundStyle(P.textMuted)
                                    }
                                    Text(t.task)
                                        .font(.system(size: 14, weight: .heavy))
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(4)
                                        .foregroundStyle(P.text)
                                    Spacer(minLength: 0)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                                .background(RoundedRectangle(cornerRadius: 20).fill(P.surface))
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(P.border, lineWidth: 1.5))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

extension CasalistCottage {

    public struct Schedule: View {
        @Environment(\.colorScheme) private var sys
        @Environment(\.dismiss) private var dismiss
        @Environment(\.managedObjectContext) private var modelContext
        @State private var darkOverride: Bool? = nil
        @State private var showAdd: Bool = false
        @State private var editingEvent: FamilyEvent? = nil
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyEvent.startDate, ascending: true)]) private var allEvents: FetchedResults<FamilyEvent>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)]) private var members: FetchedResults<FamilyMember>
        private var dark: Bool { darkOverride ?? (sys == .dark) }
        private var P: Palette { Palette.resolve(dark) }
        public init() {}

        private var upcoming: [FamilyEvent] {
            allEvents.filter { $0.startDate >= Calendar.current.startOfDay(for: Date()) }
                .sorted { $0.startDate < $1.startDate }
        }
        private var past: [FamilyEvent] {
            allEvents.filter { $0.startDate < Calendar.current.startOfDay(for: Date()) }
                .sorted { $0.startDate > $1.startDate }
        }
        private var todayEvents: [FamilyEvent] {
            upcoming.filter { Calendar.current.isDateInToday($0.startDate) }
        }
        private var weekEvents: [FamilyEvent] {
            let cal = Calendar.current
            let now = Date()
            let weekOut = cal.date(byAdding: .day, value: 7, to: now) ?? now
            return upcoming.filter { !cal.isDateInToday($0.startDate) && $0.startDate <= weekOut }
        }
        private var laterEvents: [FamilyEvent] {
            let cal = Calendar.current
            let now = Date()
            let weekOut = cal.date(byAdding: .day, value: 7, to: now) ?? now
            return upcoming.filter { $0.startDate > weekOut }
        }

        public var body: some View {
            ZStack {
                P.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                    ScrollView { content }.scrollIndicators(.hidden)
                }
            }
            .foregroundStyle(P.text)
            .preferredColorScheme(dark ? .dark : .light)
            .sheet(isPresented: $showAdd) { AddEventView() }
            .sheet(item: $editingEvent) { event in AddEventView(editing: event) }
        }

        private var topBar: some View {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "house.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(P.text)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(P.surfaceAlt))
                }
                Spacer()
                Button { darkOverride = !dark } label: {
                    Image(systemName: dark ? "sun.max.fill" : "moon.fill").font(.system(size: 14)).foregroundStyle(P.text)
                        .frame(width: 38, height: 38).background(Circle().fill(P.surfaceAlt))
                }
                Button { showAdd = true } label: {
                    Image(systemName: "plus").font(.system(size: 19, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(P.peach))
                        .shadow(color: P.peach.opacity(0.4), radius: 8, y: 4)
                }
            }.padding(.horizontal, 16).padding(.bottom, 12)
        }

        private var content: some View {
            VStack(alignment: .leading, spacing: 14) {
                hero
                if allEvents.isEmpty {
                    emptyCard
                } else {
                    section("TODAY ☀️", events: todayEvents, color: P.peach)
                    section("THIS WEEK 📅", events: weekEvents, color: P.butter)
                    section("UPCOMING", events: laterEvents, color: P.sky)
                    section("PAST", events: past.prefix(10).map { $0 }, color: P.textMuted, isPast: true)
                }
            }.padding(.horizontal, 20).padding(.bottom, 28)
        }

        private var hero: some View {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.2)).frame(width: 76, height: 76)
                    Image(systemName: "calendar").font(.system(size: 32)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("SCHEDULE").font(.system(size: 11, weight: .heavy)).tracking(0.8).opacity(0.85)
                    Text("\(upcoming.count) upcoming").font(.system(size: 22, weight: .heavy))
                    Text(todayEvents.isEmpty ? "Nothing today" : "\(todayEvents.count) today").font(.system(size: 12, weight: .semibold)).opacity(0.85)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white).padding(20)
            .background(P.sky)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }

        private var emptyCard: some View {
            Button { showAdd = true } label: {
                VStack(spacing: 8) {
                    Text("📅").font(.system(size: 36))
                    Text("No events scheduled").font(.system(size: 14, weight: .heavy))
                    Text("Tap + to add a family event").font(.system(size: 11, weight: .semibold)).opacity(0.7)
                }
                .foregroundStyle(P.text)
                .frame(maxWidth: .infinity).padding(24)
                .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
            }.buttonStyle(.plain)
        }

        @ViewBuilder
        private func section(_ title: String, events: [FamilyEvent], color: Color, isPast: Bool = false) -> some View {
            if !events.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(title).font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                        Spacer()
                        Text("\(events.count)").font(.system(size: 11, weight: .heavy)).foregroundStyle(P.textMuted).padding(.trailing, 4)
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { i, e in
                            eventRow(e, color: color, isFirst: i == 0, isPast: isPast)
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
                }
            }
        }

        private func eventRow(_ e: FamilyEvent, color: Color, isFirst: Bool, isPast: Bool) -> some View {
            Button { editingEvent = e } label: {
                HStack(spacing: 12) {
                    VStack(spacing: 2) {
                        Text(dayLabel(e.startDate)).font(.system(size: 9, weight: .heavy)).foregroundStyle(P.textDim).tracking(0.5)
                        Text(monthLabel(e.startDate)).font(.system(size: 18, weight: .heavy)).foregroundStyle(color)
                    }
                    .frame(width: 44)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.18)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(e.title)
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(isPast ? P.textDim : P.text)
                            .strikethrough(isPast)
                        HStack(spacing: 6) {
                            Image(systemName: "clock").font(.system(size: 10)).foregroundStyle(color)
                            Text(timeLabel(e))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(P.textDim)
                            if !e.location.isEmpty {
                                Text("·").foregroundStyle(P.textMuted)
                                Image(systemName: "mappin").font(.system(size: 10)).foregroundStyle(P.textMuted)
                                Text(e.location).font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textDim).lineLimit(1)
                            }
                        }
                        if !e.attendees.isEmpty {
                            Text(e.attendees).font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .heavy)).foregroundStyle(P.textMuted)
                }.padding(.vertical, 11)
                .overlay(alignment: .top) {
                    if !isFirst { Rectangle().fill(P.border).frame(height: 1) }
                }
            }.buttonStyle(.plain)
        }

        private func dayLabel(_ d: Date) -> String {
            let f = DateFormatter(); f.dateFormat = "d"
            return f.string(from: d)
        }
        private func monthLabel(_ d: Date) -> String {
            let f = DateFormatter(); f.dateFormat = "MMM"
            return f.string(from: d).uppercased()
        }
        private func timeLabel(_ e: FamilyEvent) -> String {
            if e.isAllDay { return "All-day" }
            let f = DateFormatter(); f.dateFormat = "h:mm a"
            return f.string(from: e.startDate)
        }
    }
}

extension CasalistCottage {
    public struct Root: View {
        @State private var page: Int = 0
        public init() {}
        public var body: some View {
            TabView(selection: $page) {
                Home().tag(0)
                MyToDo(onHome: { page = 0 }).tag(1)
                Rewards(onHome: { page = 0 }).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
        }
    }
}

#Preview("Root") { CasalistCottage.Root() }
#Preview("Home") { CasalistCottage.Home() }
#Preview("Rewards") { CasalistCottage.Rewards() }
#Preview("MyToDo") { CasalistCottage.MyToDo() }
#Preview("Schedule") { CasalistCottage.Schedule() }
