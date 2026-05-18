//
//  CasalistCottage.swift
//  Casalist — "Cottage" direction (playful pastel family, iOS 17+)
//
//  Requires CasalistShared.swift.
//  Use as:  CasalistCottage.Home()  or  CasalistCottage.Rewards()
//

import SwiftUI
import CoreData
import UIKit
import EventKit

public enum CasalistCottage {

    struct Palette {
        let bg, surface, surfaceAlt, surfaceHi, border, text, textDim, textMuted: Color
        let peach, mint, butter, lavender, sky, coral: Color

        /// Default palette name when none has been picked yet.
        static let defaultName = "vivid"

        /// Resolve a specific palette by name regardless of the user's
        /// active selection. Used by the Settings picker swatches so they
        /// can preview each option's colors.
        static func resolveForPreview(_ name: String, dark: Bool) -> Palette {
            switch name {
            case "vivid":  return vivid(dark)
            case "anchor": return anchor(dark)
            case "harbor": return harbor(dark)
            case "dodger": return dodger(dark)
            default:       return ember(dark)
            }
        }

        /// User-selectable theme. Routes to one of the named factories based
        /// on the "paletteName" AppStorage value (Settings → Appearance).
        ///
        /// IMPORTANT: any view that wants palette changes to take effect must
        /// declare `@AppStorage("paletteName")` in scope (or be a child of a
        /// view that does) so SwiftUI re-evaluates the `P` computed property
        /// when the user flips the picker.
        static func resolve(_ dark: Bool) -> Palette {
            let name = UserDefaults.standard.string(forKey: "paletteName") ?? defaultName
            switch name {
            case "vivid":  return vivid(dark)
            case "anchor": return anchor(dark)
            default:       return ember(dark)
            }
        }

        /// "Anchor" — the Casalist family theme. Cobalt-blue primary
        /// (#0059AC) grounds; warm amber + forest green + plum + brick
        /// give it life. Companion to the carrot-orange Family List tile
        /// on the dashboard.
        ///   peach    → cobalt #0059AC  (primary / CTAs)
        ///   mint     → forest green    (success / chores)
        ///   butter   → warm amber      (highlight / points)
        ///   lavender → plum violet     (secondary / maintenance)
        ///   sky      → lighter cobalt  (info / cool secondary)
        ///   coral    → brick red       (warning / overdue)
        static func anchor(_ dark: Bool) -> Palette {
            dark ? Palette(
                bg: Color(rgb: 0x05101E), surface: Color(rgb: 0x0F1E33), surfaceAlt: Color(rgb: 0x18304E), surfaceHi: Color(rgb: 0x254569),
                border: Color.white.opacity(0.10),
                text: Color(rgb: 0xE6EEF7), textDim: Color(rgb: 0xE6EEF7).opacity(0.6), textMuted: Color(rgb: 0xE6EEF7).opacity(0.4),
                peach: Color(rgb: 0x3B86D0), mint: Color(rgb: 0x2EAA75), butter: Color(rgb: 0xE8AB44),
                lavender: Color(rgb: 0x9956C2), sky: Color(rgb: 0x5BA0DB), coral: Color(rgb: 0xDD5E5E)
            ) : Palette(
                bg: Color(rgb: 0xF2F6FB), surface: Color(rgb: 0xFFFFFF), surfaceAlt: Color(rgb: 0xD4E0EF), surfaceHi: Color(rgb: 0xB5C7DD),
                border: Color(rgb: 0x002A60).opacity(0.12),
                text: Color(rgb: 0x002A60), textDim: Color(rgb: 0x002A60).opacity(0.6), textMuted: Color(rgb: 0x002A60).opacity(0.4),
                peach: Color(rgb: 0x0059AC), mint: Color(rgb: 0x067A4F), butter: Color(rgb: 0xD89019),
                lavender: Color(rgb: 0x6A2A8C), sky: Color(rgb: 0x2A7EC9), coral: Color(rgb: 0xC93B3B)
            )
        }

        /// "Dodger" — classic dodger blue (#1E90FF) as the primary. Cool
        /// blue-leaning surfaces with warm gold + kelly green + royal
        /// purple accents to balance.
        ///   peach    → dodger blue       (primary / CTAs)
        ///   mint     → kelly green       (success / chores)
        ///   butter   → saturated gold    (highlight / points)
        ///   lavender → royal purple      (secondary / maintenance)
        ///   sky      → deeper cobalt     (info / cool secondary)
        ///   coral    → red-orange        (warning / overdue)
        static func dodger(_ dark: Bool) -> Palette {
            dark ? Palette(
                bg: Color(rgb: 0x05101E), surface: Color(rgb: 0x0F1C2D), surfaceAlt: Color(rgb: 0x1A2D45), surfaceHi: Color(rgb: 0x2A4163),
                border: Color.white.opacity(0.10),
                text: Color(rgb: 0xEAF1F7), textDim: Color(rgb: 0xEAF1F7).opacity(0.6), textMuted: Color(rgb: 0xEAF1F7).opacity(0.4),
                peach: Color(rgb: 0x4DA8FF), mint: Color(rgb: 0x4ABF6E), butter: Color(rgb: 0xE8C552),
                lavender: Color(rgb: 0x9477E2), sky: Color(rgb: 0x4A95E0), coral: Color(rgb: 0xEF6647)
            ) : Palette(
                bg: Color(rgb: 0xF5F8FB), surface: Color(rgb: 0xFFFFFF), surfaceAlt: Color(rgb: 0xDDE7F2), surfaceHi: Color(rgb: 0xBED1E5),
                border: Color(rgb: 0x0A2F5A).opacity(0.12),
                text: Color(rgb: 0x0A2F5A), textDim: Color(rgb: 0x0A2F5A).opacity(0.6), textMuted: Color(rgb: 0x0A2F5A).opacity(0.4),
                peach: Color(rgb: 0x1E90FF), mint: Color(rgb: 0x2EAA53), butter: Color(rgb: 0xE6B225),
                lavender: Color(rgb: 0x6E47C8), sky: Color(rgb: 0x0A6FCC), coral: Color(rgb: 0xE0421A)
            )
        }

        /// "Ember" — coral-forward warm. Confident coral primary, teal
        /// complement, gold + mauve-rose accents. Warm brown dark mode.
        static func ember(_ dark: Bool) -> Palette {
            dark ? Palette(
                bg: Color(rgb: 0x2A1610), surface: Color(rgb: 0x3A1E18), surfaceAlt: Color(rgb: 0x4D2A20), surfaceHi: Color(rgb: 0x6B3D2D),
                border: Color.white.opacity(0.10),
                text: Color(rgb: 0xFFF1E8), textDim: Color(rgb: 0xFFF1E8).opacity(0.55), textMuted: Color(rgb: 0xFFF1E8).opacity(0.35),
                peach: Color(rgb: 0xFF8266), mint: Color(rgb: 0x3DCDC0), butter: Color(rgb: 0xF0B449),
                lavender: Color(rgb: 0xE07AAC), sky: Color(rgb: 0x80D0DF), coral: Color(rgb: 0xE85248)
            ) : Palette(
                bg: Color(rgb: 0xFFF4EE), surface: Color(rgb: 0xFFFFFF), surfaceAlt: Color(rgb: 0xFFDDD0), surfaceHi: Color(rgb: 0xFFC9B5),
                border: Color(rgb: 0x5C2A1F).opacity(0.12),
                text: Color(rgb: 0x5C2A1F), textDim: Color(rgb: 0x5C2A1F).opacity(0.6), textMuted: Color(rgb: 0x5C2A1F).opacity(0.4),
                peach: Color(rgb: 0xFF5E3A), mint: Color(rgb: 0x00A89B), butter: Color(rgb: 0xE89A2A),
                lavender: Color(rgb: 0xC9528A), sky: Color(rgb: 0x4FB3C8), coral: Color(rgb: 0xC8362E)
            )
        }


        /// "Vivid" — saturated jewel tones on near-white / near-black.
        /// Punchy, confident, modern.
        ///   peach    → coral red    (primary / CTAs)
        ///   mint     → emerald      (success / completed / chores)
        ///   butter   → vivid gold   (highlight / pinned / points)
        ///   lavender → hot grape    (secondary / maintenance)
        ///   sky      → electric blue (info / cool secondary)
        ///   coral    → hot magenta  (warning / overdue / urgent)
        static func vivid(_ dark: Bool) -> Palette {
            dark ? Palette(
                bg: Color(rgb: 0x0A0A12), surface: Color(rgb: 0x14141F), surfaceAlt: Color(rgb: 0x1F1F30), surfaceHi: Color(rgb: 0x2D2D45),
                border: Color.white.opacity(0.10),
                text: Color(rgb: 0xFAFAFA), textDim: Color(rgb: 0xFAFAFA).opacity(0.6), textMuted: Color(rgb: 0xFAFAFA).opacity(0.4),
                peach: Color(rgb: 0xFF7350), mint: Color(rgb: 0x3DD9A4), butter: Color(rgb: 0xFFD740),
                lavender: Color(rgb: 0xC084FC), sky: Color(rgb: 0x60A5FA), coral: Color(rgb: 0xFF477E)
            ) : Palette(
                bg: Color(rgb: 0xFFFAF2), surface: Color(rgb: 0xFFFFFF), surfaceAlt: Color(rgb: 0xFFF0E0), surfaceHi: Color(rgb: 0xFFE4C9),
                border: Color(rgb: 0x1A1A1A).opacity(0.10),
                text: Color(rgb: 0x1A1A1A), textDim: Color(rgb: 0x1A1A1A).opacity(0.6), textMuted: Color(rgb: 0x1A1A1A).opacity(0.4),
                peach: Color(rgb: 0xFF4D2E), mint: Color(rgb: 0x00B07F), butter: Color(rgb: 0xFFC107),
                lavender: Color(rgb: 0x9B4DCA), sky: Color(rgb: 0x1E88E5), coral: Color(rgb: 0xFF1F4F)
            )
        }

        /// "Harbor" — blue-forward coastal but SATURATED (no pastels).
        /// Burnt orange, teal-green, ochre, indigo, cobalt, brick on
        /// deep navy text / cool-white bg. Confident jewel/earth tones.
        ///   peach    → burnt orange (primary / CTAs)
        ///   mint     → teal-green   (success / chores)
        ///   butter   → ochre gold   (highlight / points)
        ///   lavender → indigo       (secondary / maintenance)
        ///   sky      → cobalt blue  (info / cool secondary)
        ///   coral    → brick red    (warning / overdue)
        static func harbor(_ dark: Bool) -> Palette {
            dark ? Palette(
                bg: Color(rgb: 0x081628), surface: Color(rgb: 0x10243B), surfaceAlt: Color(rgb: 0x1B324F), surfaceHi: Color(rgb: 0x2A4566),
                border: Color.white.opacity(0.10),
                text: Color(rgb: 0xE6EEF5), textDim: Color(rgb: 0xE6EEF5).opacity(0.6), textMuted: Color(rgb: 0xE6EEF5).opacity(0.4),
                peach: Color(rgb: 0xE0764A), mint: Color(rgb: 0x40A88A), butter: Color(rgb: 0xE0B046),
                lavender: Color(rgb: 0x877AC4), sky: Color(rgb: 0x3A8FD9), coral: Color(rgb: 0xCC5752)
            ) : Palette(
                bg: Color(rgb: 0xF0F4F7), surface: Color(rgb: 0xFFFFFF), surfaceAlt: Color(rgb: 0xD6E0E8), surfaceHi: Color(rgb: 0xB8C7D5),
                border: Color(rgb: 0x0A2540).opacity(0.12),
                text: Color(rgb: 0x0A2540), textDim: Color(rgb: 0x0A2540).opacity(0.6), textMuted: Color(rgb: 0x0A2540).opacity(0.4),
                peach: Color(rgb: 0xD45826), mint: Color(rgb: 0x1A8568), butter: Color(rgb: 0xCC962E),
                lavender: Color(rgb: 0x6457A8), sky: Color(rgb: 0x1862A6), coral: Color(rgb: 0xB73B36)
            )
        }


        /// Bright, candy-colored palette used by the Kid (starfield) view.
        static func starfield() -> Palette {
            Palette(
                bg: Color(rgb: 0x1B1E4A),
                surface: Color(rgb: 0x2A2E66),
                surfaceAlt: Color(rgb: 0x363C7E),
                surfaceHi: Color(rgb: 0x4A5099),
                border: Color.white.opacity(0.10),
                text: Color(rgb: 0xFFFCEC),
                textDim: Color(rgb: 0xFFFCEC).opacity(0.7),
                textMuted: Color(rgb: 0xFFFCEC).opacity(0.45),
                peach: Color(rgb: 0xFF6B9D),
                mint: Color(rgb: 0x4ECDC4),
                butter: Color(rgb: 0xFFD93D),
                lavender: Color(rgb: 0xB084F5),
                sky: Color(rgb: 0x5DC8FF),
                coral: Color(rgb: 0xFF8B5C)
            )
        }

        /// Deep navy / teal ocean palette for the Kid starfield view.
        static func starfieldOcean() -> Palette {
            Palette(
                bg: Color(rgb: 0x0A1628),
                surface: Color(rgb: 0x0F2040),
                surfaceAlt: Color(rgb: 0x163052),
                surfaceHi: Color(rgb: 0x1E4068),
                border: Color.white.opacity(0.10),
                text: Color(rgb: 0xE8F8FF),
                textDim: Color(rgb: 0xE8F8FF).opacity(0.7),
                textMuted: Color(rgb: 0xE8F8FF).opacity(0.45),
                peach: Color(rgb: 0xFF7B6B),
                mint: Color(rgb: 0x00CED4),
                butter: Color(rgb: 0xFFD166),
                lavender: Color(rgb: 0x7FCDFF),
                sky: Color(rgb: 0x48D1CC),
                coral: Color(rgb: 0xFF6B6B)
            )
        }

        /// Deep forest green / warm nature palette for the Kid starfield view.
        static func starfieldGarden() -> Palette {
            Palette(
                bg: Color(rgb: 0x1A2A1A),
                surface: Color(rgb: 0x243A24),
                surfaceAlt: Color(rgb: 0x2E4A2E),
                surfaceHi: Color(rgb: 0x3A5A3A),
                border: Color.white.opacity(0.10),
                text: Color(rgb: 0xFAF8EC),
                textDim: Color(rgb: 0xFAF8EC).opacity(0.7),
                textMuted: Color(rgb: 0xFAF8EC).opacity(0.45),
                peach: Color(rgb: 0xFF8FA3),
                mint: Color(rgb: 0x7ED96F),
                butter: Color(rgb: 0xF9C846),
                lavender: Color(rgb: 0xB5A7F5),
                sky: Color(rgb: 0x6ECFCF),
                coral: Color(rgb: 0xFF9F6B)
            )
        }

        /// Dreamy pink / purple orchid palette for the Kid starfield view.
        static func starfieldOrchid() -> Palette {
            Palette(
                bg: Color(rgb: 0x2A0A3A),
                surface: Color(rgb: 0x3D1254),
                surfaceAlt: Color(rgb: 0x4E1A6A),
                surfaceHi: Color(rgb: 0x622280),
                border: Color.white.opacity(0.12),
                text: Color(rgb: 0xFFF0FA),
                textDim: Color(rgb: 0xFFF0FA).opacity(0.7),
                textMuted: Color(rgb: 0xFFF0FA).opacity(0.45),
                peach: Color(rgb: 0xFF69B4),   // hot pink
                mint: Color(rgb: 0xDA70D6),    // orchid
                butter: Color(rgb: 0xFFD1DC),  // pastel pink
                lavender: Color(rgb: 0xC77DFF),// bright lavender
                sky: Color(rgb: 0xFF9ECD),     // pink-sky
                coral: Color(rgb: 0xFF85A1)    // rose coral
            )
        }
    }

    public struct Home: View {
        @Environment(\.colorScheme) private var sys
        @State private var darkOverride: Bool? = nil
        @State private var showAddMember = false
        @State private var showInvite = false
        @State private var showSettings = false
        @State private var showInbox = false
        @State private var showAddTodo = false
        @State private var showGrocery = false
        @State private var showMaintenance = false
        @State private var showReminders = false
        @State private var showMyToDo = false
        @State private var showSchedule = false
        @State private var showFamilyList = false
        @State private var selectedAgendaTask: TaskItem? = nil
        @State private var activeDraftBundle: TaskItem? = nil
        @State private var quickTaskText: String = ""
        @State private var showProfilePhoto = false
        @State private var showPersonalCard = false
        @AppStorage("userName") private var userName: String = ""
        @AppStorage("meUid") private var meUid: String = ""
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil")) private var members: FetchedResults<FamilyMember>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil")) private var allTodos: FetchedResults<TaskItem>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyEvent.startDate, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil")) private var allEvents: FetchedResults<FamilyEvent>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyGoal.createdAt, ascending: false)], predicate: NSPredicate(format: "deletedAt == nil")) private var allGoals: FetchedResults<FamilyGoal>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil")) private var households: FetchedResults<Household>
        private var dark: Bool { darkOverride ?? (sys == .dark) }
        @AppStorage("paletteName") private var paletteName: String = "vivid"
        private var P: Palette { Palette.resolveForPreview(paletteName, dark: dark) }
        private var sortedMembers: [FamilyMember] { members.sorted { $0.points > $1.points } }
        private var canManage: Bool {
            FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)?.canManageFamily ?? false
        }
        @State private var quickAddPing: String? = nil
        @State private var quickAddTick: Int = 0
        @State private var searchText: String = ""
        @FocusState private var searchFocused: Bool
        @State private var selectedSearchTask: TaskItem? = nil
        @Environment(\.managedObjectContext) private var modelContext
        private var inboxBadgeCount: Int {
            let me = FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)
            let pending = allGoals.filter { GoalApproval.isPending($0) && !$0.isRedeemed }
            if me?.canManageFamily == true { return pending.count }
            let lc = (me?.name.lowercased() ?? userName.lowercased())
            return pending.filter { GoalApproval.realOwnerName($0).lowercased() == lc }.count
        }
        public init() {}

        public var body: some View {
            ZStack {
                P.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                    ScrollView { content }
                        .scrollIndicators(.hidden)
                        .refreshable {
                            try? await Task.sleep(for: .seconds(2))
                            modelContext.refreshAllObjects()
                        }
                }
            }
            .foregroundStyle(P.text)
            .preferredColorScheme(dark ? .dark : .light)
            .sheet(isPresented: $showAddMember) { AddFamilyMemberView() }
            .sheet(isPresented: $showInvite) { InviteFamilyView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showInbox) { InboxView() }
            .sheet(isPresented: $showAddTodo) { AddTaskView() }
            .fullScreenCover(isPresented: $showGrocery) { Grocery() }
            .fullScreenCover(isPresented: $showMaintenance) { Maintenance() }
            .fullScreenCover(isPresented: $showReminders) { Reminders() }
            .fullScreenCover(isPresented: $showMyToDo) { MyToDo() }
            .fullScreenCover(isPresented: $showSchedule) { Schedule() }
            .fullScreenCover(isPresented: $showFamilyList) { FamilyListView() }
            .sheet(item: $selectedAgendaTask) { t in TaskDetailView(task: t) }
            .sheet(item: $activeDraftBundle) { b in BundleDraftSheet(bundle: b) }
            .sheet(item: $selectedSearchTask) { t in TaskDetailView(task: t) }
            .sheet(isPresented: $showProfilePhoto) { ProfilePhotoSheet() }
            .fullScreenCover(isPresented: $showPersonalCard) { PersonalCardView() }
        }

        // MARK: – Search bar

        private var searchBar: some View {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(searchText.isEmpty ? P.textMuted : P.peach)
                TextField("Search tasks, reminders, events…", text: $searchText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(P.text)
                    .focused($searchFocused)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchFocused = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(P.textMuted)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.2), value: searchText.isEmpty)
            .padding(.horizontal, 16).padding(.vertical, 11)
            .background(Capsule().fill(P.surface))
            .overlay(Capsule().stroke(searchFocused ? P.peach.opacity(0.5) : P.border, lineWidth: searchFocused ? 2 : 1.5))
        }

        // MARK: – Search results

        private struct SearchResult: Identifiable {
            let id: String
            let title: String
            let subtitle: String
            let category: String
            let color: Color
            let taskItem: TaskItem?
            let isEvent: Bool
        }

        private func searchResultColor(_ category: String) -> Color {
            switch category.lowercased() {
            case "chores":     return P.mint
            case "home", "maintenance": return P.lavender
            case "groceries":  return P.mint
            case "reminders":  return P.coral
            case "family":     return Color(rgb: 0xE67E22)
            case "event":      return P.sky
            default:           return P.textDim
            }
        }

        private func categoryLabel(_ raw: String) -> String {
            switch raw.lowercased() {
            case "chores":      return "Chore"
            case "home":        return "Home"
            case "maintenance": return "Home"
            case "groceries":   return "Grocery"
            case "reminders":   return "Reminder"
            case "family":      return "Family"
            case "event":       return "Event"
            default:            return raw.capitalized
            }
        }

        private var allSearchResults: [SearchResult] {
            let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
            guard !q.isEmpty else { return [] }

            let dateFmt = DateFormatter()
            dateFmt.dateFormat = "MMM d"

            let taskResults: [SearchResult] = allTodos.compactMap { t in
                guard t.task.lowercased().contains(q) else { return nil }
                var sub = ""
                if let a = t.assignee, !a.isEmpty { sub = a }
                if let d = t.dueDate {
                    let ds = dateFmt.string(from: d)
                    sub = sub.isEmpty ? ds : "\(sub) · \(ds)"
                }
                if t.points > 0 { sub = sub.isEmpty ? "⭐\(t.points)" : "\(sub) · ⭐\(t.points)" }
                return SearchResult(
                    id: t.uid,
                    title: t.task,
                    subtitle: sub,
                    category: t.category,
                    color: searchResultColor(t.category),
                    taskItem: t,
                    isEvent: false
                )
            }

            let eventResults: [SearchResult] = allEvents.compactMap { e in
                guard e.title.lowercased().contains(q) else { return nil }
                var sub = dateFmt.string(from: e.startDate)
                if !e.attendees.isEmpty { sub += " · \(e.attendees)" }
                return SearchResult(
                    id: e.uid.uuidString,
                    title: e.title,
                    subtitle: sub,
                    category: "event",
                    color: searchResultColor("event"),
                    taskItem: nil,
                    isEvent: true
                )
            }

            return (taskResults + eventResults)
                .sorted { $0.title.lowercased() < $1.title.lowercased() }
        }

        private func sectionedResults() -> [(label: String, results: [SearchResult])] {
            let all = allSearchResults
            let order = ["Reminder", "Chore", "Grocery", "Home", "Family", "Event"]
            var grouped: [String: [SearchResult]] = [:]
            for r in all {
                let label = categoryLabel(r.category)
                grouped[label, default: []].append(r)
            }
            var out: [(String, [SearchResult])] = []
            for key in order {
                if let rows = grouped[key], !rows.isEmpty { out.append((key, rows)) }
            }
            // Any unexpected categories at the end
            for (key, rows) in grouped where !order.contains(key) {
                out.append((key, rows))
            }
            return out
        }

        @ViewBuilder
        private var searchResults: some View {
            let sections = sectionedResults()
            VStack(alignment: .leading, spacing: 20) {
                if sections.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").font(.system(size: 32)).foregroundStyle(P.textMuted)
                        Text("No results for \"\(searchText)\"")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(P.textDim)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 60)
                } else {
                    ForEach(sections, id: \.label) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.label.uppercased())
                                .font(.system(size: 11, weight: .heavy))
                                .tracking(1.2)
                                .foregroundStyle(P.textDim)
                                .padding(.leading, 4)
                            VStack(spacing: 0) {
                                ForEach(Array(section.results.enumerated()), id: \.element.id) { i, r in
                                    Button {
                                        searchFocused = false
                                        if let t = r.taskItem {
                                            selectedSearchTask = t
                                        } else if r.isEvent {
                                            showSchedule = true
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(r.color)
                                                .frame(width: 4, height: 36)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(r.title)
                                                    .font(.system(size: 14, weight: .heavy))
                                                    .foregroundStyle(P.text)
                                                    .lineLimit(1)
                                                if !r.subtitle.isEmpty {
                                                    Text(r.subtitle)
                                                        .font(.system(size: 11, weight: .semibold))
                                                        .foregroundStyle(P.textMuted)
                                                        .lineLimit(1)
                                                }
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(P.textMuted)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 11)
                                        .overlay(alignment: .top) {
                                            if i > 0 {
                                                Rectangle().fill(P.border).frame(height: 1).padding(.leading, 30)
                                            }
                                        }
                                    }
                                    .buttonStyle(.row)
                                }
                            }
                            .background(RoundedRectangle(cornerRadius: 20).fill(P.surface))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(P.border, lineWidth: 1.5))
                        }
                    }
                }
            }
        }

        private var userMember: FamilyMember? {
            let trimmed = userName.trimmingCharacters(in: .whitespaces).lowercased()
            guard !trimmed.isEmpty else { return nil }
            return members.first { $0.name.lowercased() == trimmed }
        }

        private var topBar: some View {
            HStack(spacing: 10) {
                HStack(spacing: -10) { ForEach(members) { LeveledAvatar(member: $0, size: 34, showEmblem: false) } }
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
                Button { showInbox = true } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "tray.full.fill").font(.system(size: 14)).foregroundStyle(P.text)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(P.surfaceAlt))
                        if inboxBadgeCount > 0 {
                            Text("\(inboxBadgeCount)")
                                .font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Capsule().fill(P.peach))
                                .offset(x: 6, y: -2)
                        }
                    }
                }
            }.padding(.horizontal, 20).padding(.bottom, 12)
        }

        /// True when every "Around the House" tile has something in it —
        /// only then is there content worth searching.
        private var hasSearchableContent: Bool {
            groceryActiveCount > 0 || homeTileCount > 0 || openTodoCount > 0
            || reminderCount > 0 || scheduleUpcomingCount > 0 || familyListOpenCount > 0
        }

        private var content: some View {
            VStack(alignment: .leading, spacing: 14) {
                greetingCard
                stickyAgenda
                quickAdd
                if canManage { quickAddChips }
                star
                tiles
                whatsNew
            }.padding(.horizontal, 20).padding(.bottom, 28)
        }

        private func quickAddEmoji(_ entry: QuickAddEntry) -> String {
            switch entry.category.lowercased() {
            case "maintenance": return "🔧"
            case "home":        return "🏠"
            case "groceries":   return "🛒"
            case "family":      return "👨‍👩‍👧"
            case "reminders":   return "🔔"
            default:            return "✅"
            }
        }

        private var quickAddChips: some View {
            let entries = QuickAddHistory.load()
            return Group {
                if !entries.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text("QUICK ADD").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim)
                            if let ping = quickAddPing {
                                Text("· \(ping)")
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundStyle(P.peach)
                                    .transition(.opacity)
                            }
                            Spacer()
                            Menu {
                                Button(role: .destructive) {
                                    QuickAddHistory.clearAll()
                                    quickAddTick += 1
                                } label: { Label("Clear all", systemImage: "trash") }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 11, weight: .heavy))
                                    .foregroundStyle(P.textMuted)
                                    .frame(width: 22, height: 22)
                            }
                        }
                        .padding(.leading, 4)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(entries) { e in
                                quickAddTile(e)
                            }
                        }
                    }
                    .id(quickAddTick)
                }
            }
        }

        private func quickAddTile(_ e: QuickAddEntry) -> some View {
            Button {
                let households = (try? modelContext.fetch(Household.fetchRequest())) ?? []
                let t = QuickAddHistory.spawn(
                    e, creator: userName.trimmingCharacters(in: .whitespaces),
                    in: modelContext, household: households.preferredTarget
                )
                Task { await NotificationsManager.scheduleNow(for: t) }
                withAnimation { quickAddPing = "Added \"\(e.label)\"" }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation { quickAddPing = nil }
                }
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(quickAddEmoji(e)).font(.system(size: 30))
                    Spacer()
                    Text(e.label)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(P.text)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    HStack(spacing: 4) {
                        if !e.assignee.isEmpty {
                            Text(e.assignee)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(P.textDim)
                        }
                        if e.points > 0 {
                            Text("\(e.points) pts")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(P.lavender)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .frame(minHeight: 110)
                .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
            }
            .buttonStyle(.row)
            .contextMenu {
                Button(role: .destructive) {
                    QuickAddHistory.remove(e)
                    quickAddTick += 1
                } label: { Label("Remove", systemImage: "trash") }
                Button(role: .destructive) {
                    QuickAddHistory.clearAll()
                    quickAddTick += 1
                } label: { Label("Clear all", systemImage: "trash.fill") }
            }
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
            
            Button {
                showPersonalCard = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.12, green: 0.12, blue: 0.18))
                        .frame(width: 56, height: 56)
                        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    if let data = userMember?.photoBlob, let ui = UIImage(data: data) {
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
            }.buttonStyle(.row)
        }

        private struct AgendaTile: Identifiable {
            let id = UUID()
            let timeText: String
            let label: String
            let sub: String
            let symbol: String
            let color: Color
            let taskUid: String?   // nil for event tiles, set for task/reminder tiles
            var isDraftBundle: Bool = false
        }

        private func tileSymbol(_ cat: String) -> String {
            switch cat.lowercased() {
            case "chores": return "checkmark.circle.fill"
            case "home": return "house.fill"
            case "groceries": return "cart.fill"
            case "maintenance": return "wrench.fill"
            default: return "calendar"
            }
        }

        private func tileColor(_ cat: String) -> Color {
            switch cat.lowercased() {
            case "chores": return P.mint
            case "home": return P.butter
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
                    color: P.sky,
                    taskUid: nil
                )
            }
            let timedTiles = dueToday.map { task -> AgendaTile in
                let due = task.dueDate ?? Date()
                let comps = cal.dateComponents([.hour, .minute], from: due)
                let hasTime = (comps.hour ?? 0) != 0 || (comps.minute ?? 0) != 0
                var timeStr = hasTime ? timeFmt.string(from: due) : "Today"
                if hasTime, let end = task.endDate {
                    timeStr += " – \(timeFmt.string(from: end))"
                }
                return AgendaTile(
                    timeText: timeStr,
                    label: task.task,
                    sub: task.assignee ?? "",
                    symbol: tileSymbol(task.category),
                    color: tileColor(task.category),
                    taskUid: task.uid
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
                    color: P.coral,
                    taskUid: task.uid
                )
            }
            // Draft bundles — always in agenda until finalized
            let draftBundleTiles = allTodos
                .filter { $0.repeatKind == "bundle-draft" && $0.parentUid.isEmpty }
                .map { bundle -> AgendaTile in
                    let childCount = allTodos.filter { $0.parentUid == bundle.uid }.count
                    return AgendaTile(
                        timeText: childCount == 0 ? "Add chores" : "\(childCount) chore\(childCount == 1 ? "" : "s")",
                        label: bundle.task,
                        sub: bundle.assignee ?? "Anyone",
                        symbol: "square.stack.fill",
                        color: tileColor(bundle.category),
                        taskUid: bundle.uid,
                        isDraftBundle: true
                    )
                }
            return draftBundleTiles + eventTiles + timedTiles + pinnedTiles
        }

        @ViewBuilder
        private var stickyAgenda: some View {
            if !todayAgenda.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(todayAgenda.enumerated()), id: \.element.id) { i, a in
                            Button {
                                if a.isDraftBundle,
                                   let uid = a.taskUid,
                                   let b = allTodos.first(where: { $0.uid == uid }) {
                                    activeDraftBundle = b
                                } else if let uid = a.taskUid,
                                   let t = allTodos.first(where: { $0.uid == uid }) {
                                    selectedAgendaTask = t
                                } else {
                                    showSchedule = true
                                }
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Image(systemName: a.symbol).font(.system(size: 15)).foregroundStyle(a.color)
                                            .frame(width: 30, height: 30)
                                            .background(Circle().fill(a.color.opacity(0.2)))
                                        Text(a.label).font(.system(size: 13, weight: .heavy)).lineLimit(2)
                                        Text(a.sub.isEmpty ? a.timeText : "\(a.timeText) · \(a.sub)")
                                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted).lineLimit(1).truncationMode(.tail)
                                    }
                                    .padding(14).frame(width: 130, height: 110, alignment: .leading)
                                    .background(RoundedRectangle(cornerRadius: 20).fill(i % 2 == 0 ? P.surface : P.surfaceAlt))
                                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(
                                        a.isDraftBundle ? Color.red.opacity(0.5) : P.border, lineWidth: 1.5))

                                }
                            }.buttonStyle(.row)
                        }
                    }.padding(.vertical, 4)
                }
                .foregroundStyle(P.text)
            }
        }

        private var quickAdd: some View {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle").font(.system(size: 18)).foregroundStyle(P.textDim)
                TextField("Quick task...", text: $quickTaskText)
                    .font(.system(size: 14, weight: .semibold))
                    .submitLabel(.done)
                    .onSubmit(addQuickTask)
                Button { addQuickTask() } label: {
                    Image(systemName: "arrow.up").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white)
                        .frame(width: 32, height: 32).background(Circle().fill(P.peach))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 4).padding(.trailing, 4)
            .background(Capsule().fill(P.surface))
            .overlay(Capsule().stroke(P.border, lineWidth: 1.5))
        }

        private func addQuickTask() {
            let name = quickTaskText.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }
            let myName = (FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)?.name ?? userName)
                .trimmingCharacters(in: .whitespaces)
            let it = TaskItem(
                context: modelContext,
                task: name,
                category: "Chores",
                points: 5,
                createdBy: myName
            )
            it.assignee = myName
            if let h = households.preferredTarget {
                modelContext.assign(it, toStoreOf: h)
                it.household = h
            }
            try? modelContext.save()
            quickTaskText = ""
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
            }.buttonStyle(.row)
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
                            LeveledAvatar(member: top, size: 56)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("1ST PLACE").font(.system(size: 11, weight: .heavy)).tracking(0.8).opacity(0.7)
                                Text(top.name).font(.system(size: 22, weight: .heavy))
                                Text("\(top.points) pts\(lead > 0 ? " · \(lead) ahead!" : "")").font(.system(size: 13, weight: .bold))
                            }
                        }
                    }
                    ForEach(Array(sorted.enumerated()), id: \.element.uid) { i, m in
                        let lp = Int(max(m.lifetimePoints, m.points))
                        let rank = levelLabel(for: lp)
                        HStack(spacing: 10) {
                            Text(["🥇","🥈","🥉","4️⃣"][min(i, 3)]).font(.system(size: 14))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(m.name).font(.system(size: 13, weight: .heavy))
                                Text(rank).font(.system(size: 10, weight: .semibold)).opacity(0.6)
                            }
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

        private var myDashboardTodos: [TaskItem] {
            let myName = (FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)?.name ?? userName)
                .trimmingCharacters(in: .whitespaces).lowercased()
            // Family-category items count in MyToDo *once they have an assignee*
            // (i.e. someone claimed them). Excluded categories below have their
            // own tiles (groceries / maintenance / reminders).
            return allTodos.filter { t in
                !t.isCompleted
                && !["groceries", "maintenance", "reminders"].contains(t.category.lowercased())
                && (t.assignee ?? "").trimmingCharacters(in: .whitespaces).lowercased() == myName
            }
        }
        private var openTodoCount: Int { myDashboardTodos.count }
        private var nextTodoTitle: String { myDashboardTodos.first?.task ?? "" }
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
        /// "Home" tile bundles both `home` and `maintenance` category tasks so
        /// the dashboard surfaces both kinds at a glance. The detail view has
        /// a pill toggle to drill into one category at a time.
        private var homeAndMaintenanceItems: [TaskItem] {
            allTodos.filter { !$0.isCompleted && (["home", "maintenance"].contains($0.category.lowercased())) }
        }
        private var homeTileCount: Int { homeAndMaintenanceItems.count }
        private var maintenanceOverdueCount: Int { maintenanceItems.filter { ($0.dueDate ?? .distantFuture) < Date() }.count }
        private var homeOverdueCount: Int {
            homeAndMaintenanceItems.filter { ($0.dueDate ?? .distantFuture) < Date() }.count
        }
        private var homeNextItem: String { homeAndMaintenanceItems.first?.task ?? "" }
        private var reminderItems: [TaskItem] {
            let myName = (FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)?.name ?? userName)
                .trimmingCharacters(in: .whitespaces).lowercased()
            return allTodos.filter {
                guard !$0.isCompleted && $0.category.lowercased() == "reminders" else { return false }
                let assignee = ($0.assignee ?? "").trimmingCharacters(in: .whitespaces)
                return assignee.isEmpty || assignee.lowercased() == myName
            }
        }
        private var reminderCount: Int { reminderItems.count }
        private var reminderPreview: String { reminderItems.prefix(3).map { $0.task }.joined(separator: ", ") }

        private var tiles: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("AROUND THE HOUSE").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    Button { showGrocery = true } label: {
                        tile(bg: P.mint, emoji: "🛒", label: "Grocery", big: "\(groceryActiveCount)", suffix: "to get", sub: groceryNextItems)
                    }.buttonStyle(.row)
                    Button { showMaintenance = true } label: {
                        tile(bg: P.lavender, emoji: "🏠", label: "Home", big: "\(homeTileCount)", suffix: "open", sub: homeNextItem, badge: homeOverdueCount > 0 ? "\(homeOverdueCount) DUE" : nil)
                    }.buttonStyle(.row)
                    Button { showMyToDo = true } label: {
                        tile(bg: P.butter, emoji: "✏️", label: "My To-Do", big: "\(openTodoCount)", suffix: "open", sub: nextTodoTitle)
                    }.buttonStyle(.row)
                    Button { showReminders = true } label: {
                        tile(bg: P.coral, emoji: "📌", label: "Reminders", big: "\(reminderCount)", suffix: "pinned", sub: reminderPreview)
                    }.buttonStyle(.row)
                    Button { showSchedule = true } label: {
                        tile(bg: P.sky, emoji: "📅", label: "Schedule", big: "\(scheduleUpcomingCount)", suffix: "upcoming", sub: nextEventTitle)
                    }.buttonStyle(.row)
                    Button { showFamilyList = true } label: {
                        tile(bg: Color(rgb: 0xE67E22), emoji: "🪴", label: "Family List", big: "\(familyListOpenCount)", suffix: "up for grabs", sub: familyListNextItem)
                    }.buttonStyle(.row)
                }
            }
        }

        /// Mirror the Family tab's "up for grabs" filter so the tile
        /// number matches: unclaimed, non-completed, and excluding
        /// outing containers (family tasks with a dueDate AND no
        /// parentUid — those are plans, not chores).
        private var familyListOpenCount: Int {
            allTodos.filter(isFamilyUpForGrabs).count
        }
        private var familyListNextItem: String {
            allTodos.first(where: isFamilyUpForGrabs)?.task ?? ""
        }
        private func isFamilyUpForGrabs(_ t: TaskItem) -> Bool {
            t.category.lowercased() == "family"
                && !t.isCompleted
                && (t.assignee ?? "").trimmingCharacters(in: .whitespaces).isEmpty
                && t.parentUid.isEmpty   // not nested under an outing
                && t.dueDate == nil      // not an outing container itself
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
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(bg)
                    .overlay(
                        // Subtle top highlight + bottom shade gives the
                        // solid color a saturated, dimensional look without
                        // shifting the underlying palette value.
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.clear, Color.black.opacity(0.22)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            )
            .shadow(color: bg.opacity(0.35), radius: 10, x: 0, y: 4)
        }

        private struct ActivityEntry: Identifiable {
            let id = UUID()
            let who: String
            let verb: String
            let target: String
            let when: Date
            /// Optional " to <name>" suffix when the actor is acting on behalf
            /// of someone else — e.g. parent assigning a chore to a kid.
            var recipient: String? = nil
        }

        private var activityFeed: [ActivityEntry] {
            // Merge two streams:
            // - Tasks: most-recent activity, completion (with completedAt)
            //   takes priority over creation (createdAt) for ordering.
            // - Goals: redemptions only (isRedeemed && redeemedAt set).
            let taskEntries: [ActivityEntry] = allTodos.map { t in
                let isCompletion = t.isCompleted || t.completedAt != nil
                let who: String = {
                    if isCompletion, let a = t.assignee, !a.isEmpty { return a }
                    if !t.createdBy.isEmpty { return t.createdBy }
                    if let a = t.assignee, !a.isEmpty { return a }
                    return ""
                }()
                // For additions, show " to <assignee>" when the creator
                // assigned it to someone OTHER than themselves. Suppress
                // self-assignment ("geezy added to geezy" reads silly).
                let recipient: String? = {
                    guard !isCompletion else { return nil }
                    guard let a = t.assignee?.trimmingCharacters(in: .whitespaces), !a.isEmpty else { return nil }
                    if a.lowercased() == t.createdBy.lowercased() { return nil }
                    return a
                }()
                return ActivityEntry(
                    who: who,
                    verb: isCompletion ? "completed" : "added",
                    target: t.task,
                    when: isCompletion ? (t.completedAt ?? t.createdAt) : t.createdAt,
                    recipient: recipient
                )
            }
            let redemptionEntries: [ActivityEntry] = allGoals
                .filter { $0.isRedeemed && $0.redeemedAt != nil && !GoalApproval.isPending($0) }
                .map { g in
                    ActivityEntry(
                        who: GoalApproval.realOwnerName(g),
                        verb: "redeemed 🎁",
                        target: g.label,
                        when: g.redeemedAt ?? g.createdAt
                    )
                }
            return (taskEntries + redemptionEntries)
                .sorted { $0.when > $1.when }
                .prefix(6)
                .map { $0 }
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
                                    LeveledAvatar(member: m, size: 30)
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
                                let recipientText: Text? = {
                                    guard let r = a.recipient, !r.isEmpty else { return nil }
                                    let rName = memberFor(r)?.name ?? r
                                    let rColor: Color = memberFor(r)?.color ?? P.text
                                    return Text(" to ").font(.system(size: 13)).foregroundColor(P.textDim)
                                        + Text(rName).font(.system(size: 13, weight: .heavy)).foregroundColor(rColor)
                                }()
                                let base = Text(displayName)
                                    .font(.system(size: 13, weight: .heavy))
                                    .foregroundColor(nameColor)
                                 + Text(" \(a.verb) ").font(.system(size: 13)).foregroundColor(P.textDim)
                                 + Text(a.target).font(.system(size: 13, weight: .semibold))
                                (recipientText.map { base + $0 } ?? base)
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
        @State private var showSettings: Bool = false
        @State private var redeemTarget: FamilyGoal? = nil
        /// When admin taps a member's avatar in standings (and that member
        /// has at least one pending request), this opens an inline approval
        /// sheet scoped to just their requests.
        @State private var pendingForKid: FamilyMember? = nil
        @State private var earningBundleDetail: TaskItem? = nil
        @State private var celebrate: Bool = false
        @State private var celebrateLabel: String = ""
        @State private var celebrateEmoji: String = "⭐"
        @Environment(\.dismiss) private var dismiss
        @Environment(\.managedObjectContext) private var modelContext
        @AppStorage("userName") private var userName: String = ""
        @AppStorage("meUid") private var meUid: String = ""
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil")) private var members: FetchedResults<FamilyMember>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyGoal.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil")) private var goalsQuery: FetchedResults<FamilyGoal>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.dueDate, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil")) private var allTodos: FetchedResults<TaskItem>
        public var onHome: (() -> Void)?
        private var dark: Bool { darkOverride ?? (sys == .dark) }
        @AppStorage("paletteName") private var paletteName: String = "vivid"
        private var P: Palette { Palette.resolveForPreview(paletteName, dark: dark) }
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
                    ScrollView { content }
                        .scrollIndicators(.hidden)
                        .refreshable {
                            // Pull-to-refresh: wait briefly so CloudKit can
                            // land pending shared-zone changes, then drop
                            // cached objects so @FetchRequests re-read.
                            try? await Task.sleep(for: .seconds(2))
                            modelContext.refreshAllObjects()
                        }
                }
            }
            .foregroundStyle(P.text)
            .preferredColorScheme(dark ? .dark : .light)
            .sheet(isPresented: $showAddGoal) { AddGoalView() }
            .sheet(item: $redeemTarget) { g in redeemSheet(g) }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(item: $pendingForKid) { m in pendingForKidSheet(m) }
            .sheet(item: $earningBundleDetail) { b in bundleDetailSheet(b) }
            .celebration(visible: $celebrate, label: celebrateLabel, emoji: celebrateEmoji)
            .swipeBack { if let onHome { onHome() } else { dismiss() } }
        }

        /// Pending FamilyGoals owned by this member (PENDING:<name> pattern),
        /// excluding redeemed and soft-deleted records.
        private func pendingForMember(_ m: FamilyMember) -> [FamilyGoal] {
            let lc = m.name.lowercased()
            return goalsQuery.filter { g in
                GoalApproval.isPending(g)
                && !g.isRedeemed
                && g.isLive
                && GoalApproval.realOwnerName(g).lowercased() == lc
            }
        }

        /// Sheet presented when an admin taps a kid's avatar with a pending
        /// badge in standings. Shows that kid's pending reward requests with
        /// inline price-setting + Approve / Deny.
        private func pendingForKidSheet(_ m: FamilyMember) -> some View {
            PendingForKidSheet(member: m, palette: P, moc: modelContext)
        }

    /// Per-member approval sheet — extracted so each pending goal row can
    /// hold its own `@State` for the price stepper without leaking across
    /// rows or across sheet presentations.
    fileprivate struct PendingForKidSheet: View {
        let member: FamilyMember
        let palette: Palette
        let moc: NSManagedObjectContext
        @Environment(\.dismiss) private var dismiss
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyGoal.createdAt, ascending: true)],
                      predicate: NSPredicate(format: "deletedAt == nil")) private var goals: FetchedResults<FamilyGoal>

        private var P: Palette { palette }

        private var pending: [FamilyGoal] {
            let lc = member.name.lowercased()
            return goals.filter { g in
                GoalApproval.isPending(g)
                && !g.isRedeemed
                && g.isLive
                && GoalApproval.realOwnerName(g).lowercased() == lc
            }
        }

        var body: some View {
            NavigationStack {
                ZStack {
                    P.bg.ignoresSafeArea()
                    ScrollView {
                        VStack(spacing: 14) {
                            header
                            if pending.isEmpty {
                                VStack(spacing: 10) {
                                    Text("🎉").font(.system(size: 44))
                                    Text("All caught up").font(.system(size: 16, weight: .heavy))
                                    Text("\(member.name) has no pending requests.")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(P.textMuted)
                                }
                                .padding(24)
                                .frame(maxWidth: .infinity)
                                .background(RoundedRectangle(cornerRadius: 20).fill(P.surface))
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(P.border, lineWidth: 1.5))
                            } else {
                                ForEach(pending, id: \.uid) { g in
                                    PendingGoalCard(goal: g, palette: P, moc: moc)
                                }
                            }
                        }
                        .padding(20)
                    }
                    .scrollIndicators(.hidden)
                }
                .navigationTitle("\(member.name)'s requests")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                }
                .foregroundStyle(P.text)
            }
        }

        private var header: some View {
            HStack(spacing: 12) {
                LeveledAvatar(member: member, size: 48, showEmblem: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name).font(.system(size: 18, weight: .heavy))
                    Text("\(pending.count) pending request\(pending.count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(P.textMuted)
                }
                Spacer()
            }
            .padding(.bottom, 4)
        }
    }

    /// One pending goal card with its own price stepper state. Approve sets
    /// the price + strips the PENDING: prefix; Deny soft-deletes.
    fileprivate struct PendingGoalCard: View {
        let goal: FamilyGoal
        let palette: Palette
        let moc: NSManagedObjectContext
        @State private var draftPrice: Int = 0
        @State private var initialized: Bool = false

        private var P: Palette { palette }
        private var needsPrice: Bool { goal.targetPoints == 0 }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text("💬").font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.label).font(.system(size: 15, weight: .heavy))
                        Text(needsPrice ? "Needs a price" : "Suggested: \(goal.targetPoints) pts")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textMuted)
                    }
                    Spacer()
                }
                if !goal.note.isEmpty {
                    Text("\u{201C}\(goal.note)\u{201D}")
                        .font(.system(size: 13, weight: .semibold).italic())
                        .foregroundStyle(P.textDim)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(P.surfaceAlt.opacity(0.4)))
                }
                HStack {
                    Text("Set price").font(.system(size: 11, weight: .heavy)).foregroundStyle(P.textMuted)
                    Spacer()
                    Text("\(draftPrice) pts").font(.system(size: 14, weight: .heavy)).foregroundStyle(P.peach)
                    Stepper("\(draftPrice) pts", value: $draftPrice, in: 10...10_000, step: 10).labelsHidden()
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 12).fill(P.surfaceAlt.opacity(0.5)))
                HStack(spacing: 10) {
                    Button {
                        GoalApproval.deny(goal, in: moc)
                        try? moc.save()
                    } label: {
                        Text("Deny").font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Capsule().fill(Color.red.opacity(0.8)))
                    }.buttonStyle(.row)
                    Button {
                        GoalApproval.approve(goal, targetPoints: draftPrice)
                        try? moc.save()
                    } label: {
                        Text("Approve · \(draftPrice) pts")
                            .font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Capsule().fill(P.mint))
                    }.buttonStyle(.row)
                    .disabled(draftPrice < 10)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20).fill(P.surface))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(P.border, lineWidth: 1.5))
            .onAppear {
                if !initialized {
                    draftPrice = goal.targetPoints > 0 ? Int(goal.targetPoints) : 50
                    initialized = true
                }
            }
        }
    }

        private var topBar: some View {
            HStack(spacing: 10) {
                Button { if let onHome { onHome() } else { dismiss() } } label: {
                    Image(systemName: "house.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(P.text)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(P.surfaceAlt))
                }
                Spacer()
                Text("REWARDS")
                    .font(.system(size: 14, weight: .heavy))
                    .tracking(1.5)
                    .foregroundStyle(P.text)
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill").font(.system(size: 14)).foregroundStyle(P.text)
                        .frame(width: 38, height: 38).background(Circle().fill(P.surfaceAlt))
                }
            }.padding(.horizontal, 16).padding(.bottom, 12)
        }

        private var content: some View {
            VStack(alignment: .leading, spacing: 16) {
                heroCard
                podium
                standings
                goals
                redeemed
                available
            }.padding(.horizontal, 20).padding(.bottom, 28)
        }

        /// Full-width card for the current user's stats.
        private var heroCard: some View {
            Group {
                if let me = myMember {
                    let myRank = (sorted.firstIndex(where: { $0.uid == me.uid }) ?? 0) + 1
                    let streak = StreakTracker.effectiveCurrent(for: me.uid)
                    // lifetimePoints is 0 on pre-migration members; fall back to
                    // current points until real lifetime data accumulates.
                    let lp = Int(max(me.lifetimePoints, me.points))
                    let level = levelNumber(for: lp)
                    let nextLevelPts = nextLevelThreshold(for: lp) ?? (lp + 1000)
                    let prevLevelPts = nextLevelPts - 1  // only used for display; progress fn handles thresholds
                    let xpProgress = xpProgress(for: lp)
                    let _ = prevLevelPts  // suppress unused warning
                    let accentColor = me.color

                    VStack(spacing: 14) {
                        HStack(spacing: 16) {
                            LeveledAvatar(member: me, size: 64, overrideLevel: level)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(me.name).font(.system(size: 20, weight: .heavy))
                                    Text("#\(myRank)").font(.system(size: 13, weight: .heavy))
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(Capsule().fill(accentColor.opacity(0.2)))
                                        .foregroundStyle(accentColor)
                                }
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("\(me.points)").font(.system(size: 22, weight: .heavy)).foregroundStyle(accentColor)
                                        Text("POINTS").font(.system(size: 9, weight: .heavy)).tracking(1).foregroundStyle(P.textMuted)
                                    }
                                    if streak > 0 {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("🔥\(streak)").font(.system(size: 22, weight: .heavy))
                                            Text("STREAK").font(.system(size: 9, weight: .heavy)).tracking(1).foregroundStyle(P.textMuted)
                                        }
                                    }
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("LVL \(level)").font(.system(size: 22, weight: .heavy)).foregroundStyle(P.peach)
                                        Text(levelLabel(for: lp).uppercased()).font(.system(size: 9, weight: .heavy)).tracking(1).foregroundStyle(P.textMuted)
                                    }
                                }
                            }
                            Spacer()
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("XP").font(.system(size: 9, weight: .heavy)).tracking(1).foregroundStyle(P.textMuted)
                                Spacer()
                                Text("\(lp) / \(nextLevelPts) pts").font(.system(size: 9, weight: .heavy)).foregroundStyle(P.textMuted)
                            }
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 5).fill(P.surfaceAlt)
                                    .overlay(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(LinearGradient(colors: [accentColor, accentColor.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                                            .frame(width: geo.size.width * max(0, min(1, xpProgress)))
                                    }
                            }.frame(height: 8)
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(LinearGradient(colors: [accentColor.opacity(0.18), accentColor.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(accentColor.opacity(0.3), lineWidth: 1.5))
                }
            }
        }

        private var activeGoals: [FamilyGoal] { goalsQuery.filter { !$0.isRedeemed && !GoalApproval.isPending($0) } }
        private var redeemedGoals: [FamilyGoal] {
            goalsQuery.filter { $0.isRedeemed }
                .sorted { ($0.redeemedAt ?? .distantPast) > ($1.redeemedAt ?? .distantPast) }
        }

        private var myMember: FamilyMember? {
            FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)
        }

        /// Open, point-bearing TaskItems that should appear in the EARN POINTS
        /// section. Owner/admin see everything; standard/kid see only their own.
        private var earningTasks: [TaskItem] {
            // Exclude bundle children (they live under their bundle container) and drafts.
            // Bundle containers (isChoreBundle) count as a single earning unit using their bonus points.
            let pointTasks = allTodos.filter {
                !$0.isCompleted
                && $0.points > 0
                && $0.parentUid.isEmpty          // no bundle children
                && $0.repeatKind != "bundle-draft" // no unfinished drafts
            }
            if let me = myMember, !me.canManageFamily {
                let lc = me.name.lowercased()
                return pointTasks.filter { ($0.assignee ?? "").lowercased() == lc }
            }
            return pointTasks
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
                                LeveledAvatar(member: m, size: sz)
                                Text(m.name).font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(rgb: 0x3B2A22))
                                Text("\(m.points) pts").font(.system(size: 11, weight: .bold)).foregroundStyle(Color(rgb: 0x3B2A22).opacity(0.7))
                                Text(["🥇","🥈","🥉"][place - 1]).font(.system(size: place == 1 ? 32 : 26, weight: .heavy))
                                    .frame(maxWidth: .infinity).frame(height: podH)
                                    .background(UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12).fill(podColor))
                            }.frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 18).padding(.top, 20).padding(.bottom, 0)
                    .background(RoundedRectangle(cornerRadius: 32).fill(
                        LinearGradient(colors: [P.butter, P.peach.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    ))
                } else {
                    VStack(spacing: 8) {
                        Text("🏆").font(.system(size: 40))
                        Text("Add 3+ family members for a podium").font(.system(size: 13, weight: .heavy))
                    }
                    .foregroundStyle(Color(rgb: 0x3B2A22))
                    .frame(maxWidth: .infinity).padding(24)
                    .background(RoundedRectangle(cornerRadius: 32).fill(
                        LinearGradient(colors: [P.butter, P.peach.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    ))
                }
            }
        }

        private var standings: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("LEADERBOARD 🏆").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                VStack(spacing: 0) {
                    ForEach(Array(sorted.enumerated()), id: \.element.uid) { i, m in
                        let pendingCount = pendingForMember(m).count
                        let canApprove = canManagePoints && pendingCount > 0
                        HStack(spacing: 12) {
                            Text(["🥇","🥈","🥉","4️⃣"][min(i, 3)]).font(.system(size: 20))
                            Button {
                                if canApprove { pendingForKid = m }
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    LeveledAvatar(member: m, size: 36, showEmblem: false)
                                    if canApprove {
                                        Text("\(pendingCount)")
                                            .font(.system(size: 9, weight: .heavy))
                                            .foregroundStyle(.white)
                                            .frame(minWidth: 16, minHeight: 16)
                                            .padding(.horizontal, 3)
                                            .background(Capsule().fill(P.peach))
                                            .overlay(Capsule().stroke(P.surface, lineWidth: 2))
                                            .offset(x: 6, y: -4)
                                    }
                                }
                            }
                            .buttonStyle(.row)
                            .disabled(!canApprove)
                            VStack(spacing: 5) {
                                HStack(spacing: 8) {
                                    Text(m.name).font(.system(size: 14, weight: .heavy))
                                    let streak = StreakTracker.effectiveCurrent(for: m.uid)
                                    if streak > 0 {
                                        Text("🔥\(streak)").font(.system(size: 11, weight: .heavy)).foregroundStyle(P.peach)
                                    }
                                    let badgeCount = AwardedBadgeStore.awarded(for: m.uid).count
                                    if badgeCount > 0 {
                                        Text("🎖\(badgeCount)").font(.system(size: 11, weight: .heavy)).foregroundStyle(P.lavender)
                                    }
                                    Spacer()
                                    if canManagePoints {
                                        Button { adjustPoints(m, by: -5) } label: {
                                            Image(systemName: "minus").font(.system(size: 11, weight: .heavy))
                                                .frame(width: 22, height: 22)
                                                .background(Circle().fill(P.surfaceAlt))
                                                .foregroundStyle(P.text)
                                        }.buttonStyle(.row)
                                    }
                                    Text("\(m.points) pts").font(.system(size: 14, weight: .heavy)).foregroundStyle(m.color).monospacedDigit()
                                    if canManagePoints {
                                        Button { adjustPoints(m, by: 5) } label: {
                                            Image(systemName: "plus").font(.system(size: 11, weight: .heavy))
                                                .frame(width: 22, height: 22)
                                                .background(Circle().fill(P.peach.opacity(0.2)))
                                                .foregroundStyle(P.peach)
                                        }.buttonStyle(.row)
                                    }
                                }
                                standingsTierBadge(for: m)
                                GeometryReader { g in
                                    RoundedRectangle(cornerRadius: 3).fill(P.surfaceAlt).overlay(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(LinearGradient(colors: [m.color, m.color.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
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
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 28).fill(P.surface.opacity(0.5)))
        }

        private func memberFor(_ name: String) -> FamilyMember? {
            let trimmed = name.lowercased()
            return members.first { $0.name.lowercased() == trimmed }
        }

        @ViewBuilder
        private func standingsTierBadge(for m: FamilyMember) -> some View {
            let memberPts = Int(m.points)
            let tiersSorted = GameRulesStore.shared.rules.rewardTiers.sorted { $0.minPoints < $1.minPoints }
            if let memberTier = tiersSorted.last(where: { memberPts >= $0.minPoints }) {
                HStack {
                    HStack(spacing: 4) {
                        Text(memberTier.emoji).font(.system(size: 10))
                        Text(memberTier.name).font(.system(size: 10, weight: .heavy))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color(rgb: 0x7B5EA7).opacity(0.2)))
                    .foregroundStyle(Color(rgb: 0x7B5EA7))
                    Spacer()
                }
            }
        }

        private var goals: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("REWARD GOALS 🎁").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                    Spacer()
                    Button { showAddGoal = true } label: {
                        Label("Add", systemImage: "plus")
                            .font(.system(size: 11, weight: .heavy)).foregroundStyle(P.peach).padding(.trailing, 4)
                    }
                }
                if activeGoals.isEmpty {
                    Button { showAddGoal = true } label: {
                        VStack(spacing: 6) {
                            Text("🎯").font(.system(size: 30))
                            Text("Add a goal").font(.system(size: 13, weight: .heavy)).foregroundStyle(P.text)
                            Text("Set a points target for what you're saving up for").font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textDim).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(20)
                        .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
                    }.buttonStyle(.row)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(activeGoals) { g in
                            goalCard(g)
                        }
                    }
                }
            }
        }

        private func goalCard(_ g: FamilyGoal) -> some View {
            let isTeam = TeamGoal.isTeam(g)
            let m = isTeam ? nil : memberFor(g.ownerName)
            let rawProgress: Int64 = isTeam ? TeamGoal.progress(for: g, members: members) : (m?.points ?? 0)
            let progress = min(rawProgress, g.targetPoints)
            let color = isTeam ? P.lavender : (m?.color ?? P.peach)
            let canRedeem = (rawProgress >= g.targetPoints) && (isTeam || canManagePoints || isViewerOwnerOfGoal(g))
            return VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    if isTeam {
                        Text("👨‍👩‍👧‍👦").font(.system(size: 18))
                    } else if let m { LeveledAvatar(member: m, size: 26) }
                    Text(isTeam ? TeamGoal.displayName : g.ownerName).font(.system(size: 12, weight: .heavy))
                    Spacer()
                    if canManagePoints || isViewerOwnerOfGoal(g) {
                        Button {
                            g.softDelete()
                            try? modelContext.save()
                        } label: {
                            Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(P.textMuted)
                        }.buttonStyle(.row)
                    }
                }
                HStack(spacing: 6) {
                    Text(g.label).font(.system(size: 13, weight: .bold)).foregroundStyle(P.text)
                    Spacer()
                    if canRedeem {
                        Text("✅").font(.system(size: 14))
                    } else {
                        Text("🔒").font(.system(size: 12)).foregroundStyle(P.textMuted)
                    }
                }
                Text("\(progress) / \(g.targetPoints) pts").font(.system(size: 11, weight: .bold)).foregroundStyle(P.textMuted)
                GeometryReader { gg in
                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.15)).overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(color)
                            .frame(width: gg.size.width * CGFloat(progress) / CGFloat(g.targetPoints))
                    }
                }.frame(height: 8)
                if canRedeem {
                    Button { redeemTarget = g } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "gift.fill").font(.system(size: 11, weight: .heavy))
                            Text("Redeem").font(.system(size: 12, weight: .heavy))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(Capsule().fill(color))
                        .foregroundStyle(.white)
                    }.buttonStyle(.row)
                    .padding(.top, 4)
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22).fill(color.opacity(0.15)))
        }

        private func isViewerOwnerOfGoal(_ g: FamilyGoal) -> Bool {
            (myMember?.name.lowercased() ?? "") == g.ownerName.lowercased()
        }

        private func redeemSheet(_ g: FamilyGoal) -> some View {
            let isTeam = TeamGoal.isTeam(g)
            let m = isTeam ? nil : memberFor(g.ownerName)
            let color = isTeam ? P.lavender : (m?.color ?? P.peach)
            return NavigationStack {
                ZStack {
                    P.bg.ignoresSafeArea()
                    VStack(spacing: 18) {
                        Spacer().frame(height: 8)
                        Image(systemName: isTeam ? "party.popper.fill" : "gift.fill").font(.system(size: 44)).foregroundStyle(color)
                        Text("Redeem \(g.label)?").font(.system(size: 20, weight: .heavy)).multilineTextAlignment(.center)
                        Text(isTeam
                            ? "Whole-family goals are celebration milestones — no points get spent."
                            : "\(g.targetPoints) pts will be spent from \(g.ownerName)'s balance.")
                            .font(.system(size: 13)).foregroundStyle(P.textMuted)
                            .multilineTextAlignment(.center).padding(.horizontal, 24)
                        HStack(spacing: 12) {
                            Button("Cancel") { redeemTarget = nil }
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Capsule().fill(P.surfaceAlt))
                                .foregroundStyle(P.text)
                            Button {
                                if !isTeam, let m = memberFor(g.ownerName) {
                                    m.points = max(0, m.points - g.targetPoints)
                                }
                                g.isRedeemed = true
                                g.redeemedAt = Date()
                                try? modelContext.save()
                                let label = g.label
                                redeemTarget = nil
                                // Celebrate after dismiss so overlay fires on Rewards page.
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    celebrateLabel = "Redeemed \(label)!"
                                    celebrateEmoji = "🎉"
                                    celebrate = true
                                }
                            } label: {
                                Text("Redeem").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Capsule().fill(color))
                        }
                        .padding(.horizontal, 24)
                        Spacer()
                    }
                    .padding(20)
                }
                .foregroundStyle(P.text)
            }
            .presentationDetents([.medium])
        }

        private var redeemed: some View {
            Group {
                if !redeemedGoals.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("REDEEMED 🏆").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                        VStack(spacing: 8) {
                            ForEach(redeemedGoals.prefix(6)) { g in
                                let isTeam = TeamGoal.isTeam(g)
                                let m = isTeam ? nil : memberFor(g.ownerName)
                                let color = isTeam ? P.lavender : (m?.color ?? P.peach)
                                HStack(spacing: 10) {
                                    if isTeam {
                                        Text("👨‍👩‍👧‍👦").font(.system(size: 22))
                                    } else if let m { LeveledAvatar(member: m, size: 28) }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(g.label).font(.system(size: 13, weight: .heavy))
                                        Text("\(isTeam ? TeamGoal.displayName : g.ownerName) · \(g.targetPoints) pts").font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted)
                                    }
                                    Spacer()
                                    if let d = g.redeemedAt {
                                        Text(d, style: .date).font(.system(size: 10)).foregroundStyle(P.textMuted)
                                    }
                                    if canManagePoints {
                                        Button {
                                            g.softDelete()
                                            try? modelContext.save()
                                        } label: {
                                            Image(systemName: "xmark").font(.system(size: 10)).foregroundStyle(P.textMuted)
                                        }.buttonStyle(.row)
                                    }
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 14).fill(color.opacity(0.12)))
                            }
                        }
                    }
                }
            }
        }

        private var available: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("ACTIVE QUESTS ⚡").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                    Spacer()
                    Text("\(earningTasks.count) open").font(.system(size: 10, weight: .heavy)).foregroundStyle(P.textMuted).padding(.trailing, 4)
                }
                if earningTasks.isEmpty {
                    VStack(spacing: 6) {
                        Text("💪").font(.system(size: 30))
                        Text(emptyEarningHeadline).font(.system(size: 13, weight: .heavy)).foregroundStyle(P.text)
                        Text(emptyEarningSubtitle).font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textDim).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(20)
                    .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
                } else if myMember?.canManageFamily == true {
                    // Owner/admin sees the family's earning pipeline grouped
                    // by assignee, so they can see who has work outstanding.
                    VStack(spacing: 14) {
                        ForEach(earningGroups, id: \.assigneeKey) { group in
                            earningGroupCard(group)
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        ForEach(earningTasks, id: \.uid) { t in
                            earningRow(t)
                        }
                    }
                }
            }
        }

        private struct EarningGroup {
            let assigneeKey: String       // lowercased name or "" for unassigned
            let displayName: String
            let member: FamilyMember?
            let tasks: [TaskItem]
            var totalPoints: Int { tasks.reduce(0) { $0 + Int($1.points) } }
        }

        private var earningGroups: [EarningGroup] {
            // Group earning tasks by assignee. Order: members in fetch order,
            // then any unassigned tasks last.
            var grouped: [String: [TaskItem]] = [:]
            for t in earningTasks {
                let key = (t.assignee ?? "").lowercased()
                grouped[key, default: []].append(t)
            }
            var groups: [EarningGroup] = []
            for m in members {
                let key = m.name.lowercased()
                if let tasks = grouped[key], !tasks.isEmpty {
                    groups.append(EarningGroup(assigneeKey: key, displayName: m.name, member: m, tasks: tasks))
                }
            }
            if let unassigned = grouped[""], !unassigned.isEmpty {
                groups.append(EarningGroup(assigneeKey: "", displayName: "Unassigned", member: nil, tasks: unassigned))
            }
            return groups
        }

        private func earningGroupCard(_ group: EarningGroup) -> some View {
            // Group header dropped — the per-row avatar already tags assignee,
            // and the section heading on the page handles the section purpose.
            // Tasks stay ordered by member (still grouped under the hood).
            VStack(spacing: 6) {
                ForEach(group.tasks, id: \.uid) { t in
                    earningRow(t)
                }
            }
        }

        private var emptyEarningHeadline: String {
            (myMember?.canManageFamily ?? false) ? "No open chores" : "Nothing to earn right now"
        }
        private var emptyEarningSubtitle: String {
            (myMember?.canManageFamily ?? false)
                ? "Assign tasks with points from the home screen — they'll show up here."
                : "Your family will assign chores you can earn points for."
        }

        private func earningRow(_ t: TaskItem) -> some View {
            let assignee = members.first(where: { $0.name.lowercased() == (t.assignee ?? "").lowercased() })
            let isMineOrIManage = (myMember?.canManageFamily ?? false) ||
                ((myMember?.name.lowercased() ?? "") == (t.assignee ?? "").lowercased())

            // For bundles: total pts = bonus + sum of all incomplete child chore pts
            let isBundle = t.isChoreBundle
            let allBundleChildren = isBundle ? allTodos.filter { $0.parentUid == t.uid } : []
            let doneChildren = allBundleChildren.filter { $0.isCompleted }
            let openChildren = allBundleChildren.filter { !$0.isCompleted }
            let totalChildPts = openChildren.reduce(0) { $0 + Int($1.points) }
            let displayPts = isBundle ? (Int(t.points) + totalChildPts) : Int(t.points)
            let allChildrenDone = isBundle && !allBundleChildren.isEmpty && openChildren.isEmpty

            let row = HStack(spacing: 12) {
                if let a = assignee {
                    LeveledAvatar(member: a, size: 32)
                } else {
                    ZStack {
                        Circle().fill(P.surfaceAlt).frame(width: 32, height: 32)
                        Image(systemName: "person.fill").font(.system(size: 12)).foregroundStyle(P.textMuted)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if isBundle {
                            Image(systemName: "square.stack.fill")
                                .font(.system(size: 10, weight: .heavy)).foregroundStyle(P.textMuted)
                        }
                        Text(t.task).font(.system(size: 13, weight: .heavy)).lineLimit(2)
                    }
                    HStack(spacing: 6) {
                        Text(t.assignee ?? "Unassigned").font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted)
                        if isBundle {
                            Text("·").foregroundStyle(P.textMuted)
                            Text("\(doneChildren.count)/\(allBundleChildren.count) chores done")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(allChildrenDone ? P.mint : P.textMuted)
                        } else if let due = t.dueDate {
                            Text("·").foregroundStyle(P.textMuted)
                            Text(due, style: .date).font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted)
                        }
                    }
                }
                Spacer()
                Text("\(isBundle ? "⚡️⚡️" : "⚡") \(displayPts)").font(.system(size: 13, weight: .heavy))
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Capsule().fill(isBundle ? P.butter.opacity(0.9) : P.peach))
                    .foregroundStyle(.white)
                if isMineOrIManage && (!isBundle || allChildrenDone) {
                    Button {
                        completeEarning(t)
                    } label: {
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(allChildrenDone ? P.mint : P.peach))
                            .foregroundStyle(.white)
                    }.buttonStyle(.row)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 20).fill(P.surface))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(isBundle ? P.butter.opacity(0.4) : P.border, lineWidth: 1.5))
            .contentShape(Rectangle())

            // Bundles are tappable to see their chores
            return Group {
                if isBundle {
                    Button { earningBundleDetail = t } label: { row }
                        .buttonStyle(.plain)
                } else {
                    row
                }
            }
        }

        @ViewBuilder
        private func bundleDetailSheet(_ bundle: TaskItem) -> some View {
            let children = allTodos.filter { $0.parentUid == bundle.uid }.sorted { !$0.isCompleted && $1.isCompleted }
            let color: Color = {
                switch bundle.category.lowercased() {
                case "chores": return Color(rgb: 0x4CAF82)
                case "home": return Color(rgb: 0x5B9BD5)
                case "maintenance": return Color(rgb: 0xE8A838)
                case "family": return Color(rgb: 0xC87DD4)
                default: return Color(rgb: 0x4CAF82)
                }
            }()
            let doneCount = children.filter { $0.isCompleted }.count
            let totalCount = children.count

            NavigationStack {
                ZStack {
                    P.bg.ignoresSafeArea()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // Header
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 5, height: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bundle.task).font(.system(size: 22, weight: .heavy))
                                    Text("\(doneCount)/\(totalCount) chores done · \(bundle.assignee ?? "Unassigned")")
                                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(P.textDim)
                                }
                                Spacer()
                                if bundle.points > 0 {
                                    HStack(spacing: 3) {
                                        Text("⚡️⚡️").font(.system(size: 9))
                                        Text("+\(bundle.points) bonus")
                                    }
                                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Capsule().fill(P.butter.opacity(0.9)))
                                }
                            }
                            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 16)

                            // Progress bar
                            if totalCount > 0 {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4).fill(P.surfaceAlt).frame(height: 6)
                                        RoundedRectangle(cornerRadius: 4).fill(color)
                                            .frame(width: geo.size.width * CGFloat(doneCount) / CGFloat(totalCount), height: 6)
                                    }
                                }
                                .frame(height: 6)
                                .padding(.horizontal, 20).padding(.bottom, 16)
                            }

                            // Chore list
                            VStack(spacing: 0) {
                                ForEach(children, id: \.uid) { child in
                                    HStack(spacing: 12) {
                                        if child.isCompleted {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 22)).foregroundStyle(color)
                                        } else {
                                            Circle().stroke(color, lineWidth: 2).frame(width: 22, height: 22)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(child.task)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(child.isCompleted ? P.textDim : P.text)
                                                .strikethrough(child.isCompleted, color: P.textDim)
                                            if child.points > 0 {
                                                Text("+\(child.points) pts").font(.system(size: 10, weight: .heavy)).foregroundStyle(P.textDim)
                                            }
                                        }
                                        Spacer()
                                        if child.isCompleted {
                                            Text("Done").font(.system(size: 10, weight: .heavy)).foregroundStyle(color)
                                        }
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 12)
                                    .background(child.isCompleted ? color.opacity(0.06) : P.surface)
                                    Divider().padding(.leading, 50)
                                }
                            }
                            .background(RoundedRectangle(cornerRadius: 16).fill(P.surface))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(P.border, lineWidth: 1))
                            .padding(.horizontal, 16)
                            .padding(.bottom, 32)
                        }
                    }
                }
                .navigationTitle("Bundle details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { earningBundleDetail = nil }
                    }
                }
            }
        }

        private func completeEarning(_ t: TaskItem) {
            // Guard: already completed — no double-awarding
            guard !t.isCompleted else { return }

            if t.isChoreBundle {
                // Bundles: repeatKind="bundle" would make FamilyPoints.toggle roll forward
                // instead of completing. Handle bundles directly — award bonus, mark done.
                let bonusPts = Int(t.points)
                if bonusPts > 0, let name = t.assignee,
                   let member = members.first(where: { $0.name.lowercased() == name.lowercased() }) {
                    member.points += Int64(bonusPts)
                    member.lifetimePoints += Int64(bonusPts)
                }
                t.isCompleted = true
                t.completedAt = Date()
                try? modelContext.save()
                if bonusPts > 0 {
                    celebrateLabel = "Bundle done! +\(bonusPts) bonus! 🎉"
                    celebrateEmoji = "⭐"
                    celebrate = true
                }
            } else {
                // Regular task: one-way complete, never un-complete from this screen
                let pts = Int(t.points)
                FamilyPoints.toggle(t, in: members)
                try? modelContext.save()
                if pts > 0 {
                    celebrateLabel = "+\(pts) pts!"
                    celebrate = true
                }
            }
        }

        private func adjustPoints(_ m: FamilyMember, by delta: Int) {
            m.points = max(0, m.points + Int64(delta))
            try? modelContext.save()
        }

    }
}

extension CasalistCottage {

    public struct MyToDo: View {
        @Environment(\.colorScheme) private var sys
        @Environment(\.dismiss) private var dismiss
        @Environment(\.managedObjectContext) private var modelContext
        @AppStorage("userName") private var userName: String = ""
        @AppStorage("meUid") private var meUid: String = ""
        @State private var darkOverride: Bool? = nil
        @State private var timeFilter: String = "All"   // All / Today / This week
        @State private var kindFilter: String = "All"   // All / Chores / Home / Maintenance
        /// Admin-only toggle: "Mine" shows only my assigned chores (default),
        /// "Everyone" shows all family chores grouped by assignee.
        @State private var scope: String = "Mine"
        @State private var showAddTodo = false
        @State private var showSettings = false
        @State private var showInbox = false
        @State private var editingTask: TaskItem? = nil
        @State private var celebrate: Bool = false
        @State private var celebrateLabel: String = ""
        @State private var newItem: String = ""
        @State private var expandedBundles: Set<String> = []
        @State private var showAddBundle: Bool = false
        @State private var bundleNewItem: [String: String] = [:]
        @State private var bundleDraftItemPoints: [String: Int] = [:]
        @State private var bundleInlinePoints: [String: Int] = [:]
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.dueDate, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil")) private var todos: FetchedResults<TaskItem>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil")) private var members: FetchedResults<FamilyMember>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyGoal.createdAt, ascending: false)], predicate: NSPredicate(format: "deletedAt == nil")) private var allGoals: FetchedResults<FamilyGoal>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil")) private var households: FetchedResults<Household>
        public var onHome: (() -> Void)?
        private var dark: Bool { darkOverride ?? (sys == .dark) }
        @AppStorage("paletteName") private var paletteName: String = "vivid"
        private var P: Palette { Palette.resolveForPreview(paletteName, dark: dark) }
        public init(onHome: (() -> Void)? = nil) { self.onHome = onHome }

        private func isModuleCategory(_ cat: String) -> Bool {
            ["groceries", "maintenance", "reminders"].contains(cat.lowercased())
        }
        private func isMine(_ t: TaskItem) -> Bool {
            let myName = (FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)?.name ?? userName)
                .trimmingCharacters(in: .whitespaces).lowercased()
            guard !myName.isEmpty else { return false }
            return (t.assignee ?? "").trimmingCharacters(in: .whitespaces).lowercased() == myName
        }
        private var iAmAdmin: Bool {
            FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)?.canManageFamily ?? false
        }
        private var scopeAllowsEveryone: Bool { iAmAdmin && scope == "Everyone" }
        private func passesScope(_ t: TaskItem) -> Bool { scopeAllowsEveryone ? true : isMine(t) }

        private var incomplete: [TaskItem] {
            // Regular open tasks (not module categories, not containers, not bundle children)
            let regular = todos.filter {
                !$0.isCompleted && !isModuleCategory($0.category) && passesScope($0)
                && !$0.isContainer && !$0.isChoreBundle && $0.parentUid.isEmpty
            }
            // Bundle containers — show if assigned to me, unassigned (anyone), or admin sees all.
            // Unassigned bundles always appear in Mine mode since they're open for anyone to work.
            let bundles = todos.filter {
                guard $0.isChoreBundle else { return false }
                if scopeAllowsEveryone { return true }
                let assignee = ($0.assignee ?? "").trimmingCharacters(in: .whitespaces)
                return assignee.isEmpty || isMine($0)
            }
            return regular + bundles
        }
        private var completed: [TaskItem] {
            todos.filter {
                $0.isCompleted && !isModuleCategory($0.category) && passesScope($0)
                && !$0.isContainer && !$0.isChoreBundle && $0.parentUid.isEmpty
            }
        }

        private func isToday(_ d: Date?) -> Bool {
            guard let d else { return false }
            return Calendar.current.isDateInToday(d)
        }
        private func isThisWeek(_ d: Date?) -> Bool {
            guard let d else { return false }
            return Calendar.current.isDate(d, equalTo: Date(), toGranularity: .weekOfYear)
        }

        private func passesKind(_ t: TaskItem) -> Bool {
            kindFilter == "All" || t.category.lowercased() == kindFilter.lowercased()
        }
        private func passesTime(_ t: TaskItem) -> Bool {
            switch timeFilter {
            case "Today":     return isToday(t.dueDate)
            case "This week": return isThisWeek(t.dueDate)
            default:          return true
            }
        }
        private var visibleItems: [TaskItem] {
            incomplete.filter { $0.repeatKind != "bundle-draft" && passesKind($0) && ($0.isChoreBundle || passesTime($0)) }
        }

        private var doneTodayCount: Int { completed.filter { isToday($0.dueDate) }.count }
        private var totalTodayCount: Int { todos.filter { isToday($0.dueDate) && !isModuleCategory($0.category) && passesScope($0) }.count }
        private var donePercent: Double {
            guard totalTodayCount > 0 else { return 0 }
            return Double(doneTodayCount) / Double(totalTodayCount)
        }

        private func categoryColor(_ cat: String) -> Color {
            switch cat.lowercased() {
            case "chores": return P.mint
            case "homework": return P.lavender
            case "home": return P.butter
            case "groceries": return P.coral
            case "maintenance": return P.peach
            case "family": return P.coral
            default: return P.peach
            }
        }
        private func memberFor(_ assignee: String?) -> CLFamilyMember? {
            guard let assignee, !assignee.isEmpty else { return nil }
            return members.first { $0.name.lowercased() == assignee.lowercased() }?.asCLMember
        }
        private func whenString(_ d: Date) -> String {
            let cal = Calendar.current
            let comps = cal.dateComponents([.hour, .minute], from: d)
            let hasTime = (comps.hour ?? 0) != 0 || (comps.minute ?? 0) != 0
            let f = DateFormatter()
            if cal.isDateInToday(d) {
                if hasTime { f.dateFormat = "h:mm a"; return "Today \(f.string(from: d))" }
                return "Today"
            }
            if cal.isDateInTomorrow(d) {
                if hasTime { f.dateFormat = "h:mm a"; return "Tomorrow \(f.string(from: d))" }
                return "Tomorrow"
            }
            f.dateFormat = hasTime ? "EEE MMM d · h:mm a" : "EEE MMM d"
            return f.string(from: d)
        }

        public var body: some View {
            ZStack {
                P.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                    ScrollView { content }
                        .scrollIndicators(.hidden)
                        .refreshable {
                            try? await Task.sleep(for: .seconds(2))
                            modelContext.refreshAllObjects()
                        }
                }
            }
            .foregroundStyle(P.text)
            .preferredColorScheme(dark ? .dark : .light)
            .navigationBarBackButtonHidden()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddTodo) { AddTaskView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showInbox) { InboxView() }
            .sheet(item: $editingTask) { t in TaskDetailView(task: t) }
            .sheet(isPresented: $showAddBundle) { AddTaskView(startMode: "bundle") }
            .celebration(visible: $celebrate, label: celebrateLabel)
            .swipeBack { if let onHome { onHome() } else { dismiss() } }
        }

        private func completeTask(_ t: TaskItem) {
            let wasCompleted = t.isCompleted
            let isRecurring = !t.effectiveRepeatKind.isEmpty && !t.isChoreBundle
            let pts = Int(t.points)
            FamilyPoints.toggle(t, in: members)
            try? modelContext.save()
            let earned = isRecurring || (!wasCompleted && t.isCompleted)
            if earned && pts > 0 {
                celebrateLabel = "+\(pts) pts!"
                celebrate = true
            }
            // Check if completing this child finishes a bundle
            checkBundleCompletion(for: t)
        }

        private func checkBundleCompletion(for child: TaskItem) {
            guard !child.parentUid.isEmpty else { return }
            guard let bundle = todos.first(where: { $0.uid == child.parentUid && $0.isChoreBundle }) else { return }
            let siblings = todos.filter { $0.parentUid == bundle.uid }
            guard !siblings.isEmpty, siblings.allSatisfy({ $0.isCompleted }) else { return }
            guard bundle.points > 0 else { return }
            let bonusPts = Int(bundle.points)
            let recipientName = bundle.assignee ?? child.assignee ?? ""
            if !recipientName.isEmpty, let member = FamilyPoints.match(name: recipientName, in: members) {
                member.points += Int64(bonusPts)
                member.lifetimePoints += Int64(bonusPts)
            }
            try? modelContext.save()
            celebrateLabel = "Bundle done! +\(bonusPts) bonus!"
            celebrate = true
        }

        private func addChoreToBundle(_ bundle: TaskItem) {
            let text = (bundleNewItem[bundle.uid] ?? "").trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return }
            let pts = bundleInlinePoints[bundle.uid] ?? 10
            let myName = FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)?.name ?? userName
            let chore = TaskItem(
                context: modelContext,
                task: text,
                category: bundle.category,
                points: pts,
                createdBy: myName.trimmingCharacters(in: .whitespaces)
            )
            chore.parentUid = bundle.uid
            chore.assignee = bundle.assignee
            if let h = households.preferredTarget {
                modelContext.assign(chore, toStoreOf: h)
                chore.household = h
            }
            try? modelContext.save()
            bundleNewItem[bundle.uid] = ""
        }

        private func addInlineItem() {
            let name = newItem.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }
            let myName = FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)?.name ?? userName
            let it = TaskItem(
                context: modelContext,
                task: name,
                category: "Chores",
                points: 5,
                createdBy: myName.trimmingCharacters(in: .whitespaces)
            )
            it.assignee = myName.trimmingCharacters(in: .whitespaces)
            if let h = households.preferredTarget {
                modelContext.assign(it, toStoreOf: h)
                it.household = h
            }
            try? modelContext.save()
            newItem = ""
        }

        private var inboxBadgeCount: Int {
            let me = FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)
            let pending = allGoals.filter { GoalApproval.isPending($0) && !$0.isRedeemed }
            if me?.canManageFamily == true { return pending.count }
            let lc = (me?.name.lowercased() ?? userName.lowercased())
            return pending.filter { GoalApproval.realOwnerName($0).lowercased() == lc }.count
        }

        private var topBar: some View {
            HStack(spacing: 10) {
                Button { if let onHome { onHome() } else { dismiss() } } label: {
                    Image(systemName: "house.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(P.text)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(P.surfaceAlt))
                }
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill").font(.system(size: 14)).foregroundStyle(P.text)
                        .frame(width: 38, height: 38).background(Circle().fill(P.surfaceAlt))
                }
                Button { showInbox = true } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "tray.full.fill").font(.system(size: 14)).foregroundStyle(P.text)
                            .frame(width: 38, height: 38).background(Circle().fill(P.surfaceAlt))
                        if inboxBadgeCount > 0 {
                            Text("\(inboxBadgeCount)").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Capsule().fill(P.peach)).offset(x: 6, y: -2)
                        }
                    }
                }
                Button { showAddTodo = true } label: {
                    Image(systemName: "plus").font(.system(size: 19, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(P.peach))
                        .shadow(color: P.peach.opacity(0.4), radius: 8, y: 4)
                }
            }.padding(.horizontal, 16).padding(.bottom, 12)
        }

        private var bundlesInProgress: [TaskItem] {
            todos.filter {
                guard $0.repeatKind == "bundle-draft" && $0.parentUid.isEmpty else { return false }
                if scopeAllowsEveryone { return true }
                let assignee = ($0.assignee ?? "").trimmingCharacters(in: .whitespaces)
                return assignee.isEmpty || isMine($0)
            }
        }

        private var content: some View {
            VStack(alignment: .leading, spacing: 14) {
                greeting
                progressHero
                addPills
                if iAmAdmin { scopeToggle }
                quickAddRow
                kindFilters
                taskList
                recentlyDone
            }.padding(.horizontal, 20).padding(.bottom, 28)
        }

        /// First-name greeting that varies by time of day.
        private var greeting: some View {
            let hour = Calendar.current.component(.hour, from: Date())
            let timeWord: String
            let emoji: String
            switch hour {
            case 5..<12:  (timeWord, emoji) = ("Good morning", "☀️")
            case 12..<17: (timeWord, emoji) = ("Good afternoon", "👋")
            case 17..<22: (timeWord, emoji) = ("Good evening", "🌙")
            default:      (timeWord, emoji) = ("Hey", "👋")
            }
            let firstName = (FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)?.name ?? userName)
                .trimmingCharacters(in: .whitespaces)
                .split(separator: " ").first.map(String.init) ?? ""
            let line = firstName.isEmpty ? "\(timeWord) \(emoji)" : "\(timeWord), \(firstName) \(emoji)"
            return Text(line)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(P.text)
                .padding(.top, 4)
                .padding(.leading, 4)
        }

        /// Subtitle for the progress hero that varies with how far you are.
        private var heroSubtitle: String {
            if totalTodayCount == 0 { return "Nothing due today 🌿" }
            if doneTodayCount == 0 { return "Let's get started 💪" }
            let pct = donePercent
            if pct >= 1.0  { return "Crushing it 🎉" }
            if pct >= 0.75 { return "Almost done!" }
            if pct >= 0.5  { return "Halfway there 💪" }
            return "\(doneTodayCount) of \(totalTodayCount) done today"
        }

        private var addPills: some View {
            HStack(spacing: 10) {
                Button { showAddTodo = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 11, weight: .heavy))
                        Text("New Task").font(.system(size: 13, weight: .heavy))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Capsule().fill(P.peach))
                }.buttonStyle(.row)
                Spacer()
            }
        }

        // MARK: – Hero

        private var progressHero: some View {
            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.22), lineWidth: 7).frame(width: 86, height: 86)
                    Circle().trim(from: 0, to: donePercent)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 86, height: 86)
                        .animation(.easeInOut(duration: 0.5), value: donePercent)
                    VStack(spacing: -2) {
                        Text("\(Int(donePercent * 100))%").font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("done").font(.system(size: 10, weight: .medium)).opacity(0.8)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(scopeAllowsEveryone ? "Family to-do" : "My to-do")
                        .font(.system(size: 13, weight: .semibold, design: .rounded)).opacity(0.85)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(visibleItems.count)")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                        Text(visibleItems.count == 1 ? "task waiting" : "tasks waiting")
                            .font(.system(size: 14, weight: .medium, design: .rounded)).opacity(0.85)
                    }
                    Text(heroSubtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded)).opacity(0.85)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22).padding(.vertical, 22)
            .background(
                LinearGradient(
                    colors: [P.peach, P.coral],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: P.coral.opacity(0.28), radius: 18, x: 0, y: 8)
        }

        // MARK: – Scope toggle (admin only)

        private var scopeToggle: some View {
            HStack(spacing: 8) {
                ForEach(["Mine", "Everyone"], id: \.self) { opt in
                    let active = scope == opt
                    Button { scope = opt } label: {
                        HStack(spacing: 6) {
                            Image(systemName: opt == "Mine" ? "person.fill" : "person.3.fill")
                                .font(.system(size: 11, weight: .heavy))
                            Text(opt).font(.system(size: 13, weight: .heavy))
                        }
                        .foregroundStyle(active ? .white : P.textDim)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(active ? P.coral : P.surfaceAlt))
                    }.buttonStyle(.row)
                }
                Spacer()
            }
        }

        // MARK: – Inline quick-add

        private var quickAddRow: some View {
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle").font(.system(size: 18)).foregroundStyle(P.textDim)
                    TextField("Quick task...", text: $newItem)
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
        }

        // MARK: – Kind + time filter chips

        private var kindFilters: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Time filters
                    timeChip("All", icon: "tray.fill")
                    timeChip("Today", icon: "sun.max.fill")
                    timeChip("This week", icon: "calendar")
                    Divider().frame(height: 20).padding(.horizontal, 2)
                    // Kind filters — pulled from GameRulesStore so new
                    // categories (Homework, etc.) automatically appear.
                    ForEach(GameRulesStore.shared.rules.categoryRules) { rule in
                        kindChip(rule.category,
                                 icon: kindIcon(for: rule.category),
                                 color: kindColor(for: rule.category))
                    }
                }
            }
        }

        /// SF Symbol per category. Falls back to a generic icon for
        /// custom categories the user adds in GameRulesView.
        private func kindIcon(for cat: String) -> String {
            switch cat.lowercased() {
            case "chores":      return "checkmark.circle.fill"
            case "homework":    return "book.fill"
            case "home":        return "house.fill"
            case "maintenance": return "wrench.fill"
            case "family":      return "person.3.fill"
            default:            return "tag.fill"
            }
        }

        /// Palette tint per category. Reuses categoryColor() under the
        /// hood so the filter chip and the task-card stripe match.
        private func kindColor(for cat: String) -> Color {
            categoryColor(cat)
        }

        private func timeChip(_ label: String, icon: String) -> some View {
            let active = timeFilter == label
            return Button {
                timeFilter = label
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: icon).font(.system(size: 11, weight: .heavy))
                    Text(label).font(.system(size: 12, weight: .heavy))
                }
                .foregroundStyle(active ? .white : P.textDim)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(active ? P.peach : P.surfaceAlt))
            }.buttonStyle(.row)
        }

        private func kindChip(_ label: String, icon: String, color: Color) -> some View {
            let active = kindFilter == label
            return Button {
                kindFilter = kindFilter == label ? "All" : label
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: icon).font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(active ? .white : color)
                    Text(label).font(.system(size: 12, weight: .heavy))
                }
                .foregroundStyle(active ? .white : P.textDim)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(active ? color : P.surfaceAlt))
                .overlay(Capsule().stroke(active ? color : P.border, lineWidth: 1.5))
            }.buttonStyle(.row)
        }

        // MARK: – Task list

        private var taskList: some View {
            VStack(alignment: .leading, spacing: 14) {
                if visibleItems.isEmpty {
                    emptyState
                } else {
                    groupedTaskList
                }
            }
        }

        /// Friendly empty-state card with a real SF Symbol illustration.
        /// Tap to open the add-task sheet.
        private var emptyState: some View {
            Button { showAddTodo = true } label: {
                VStack(spacing: 14) {
                    ZStack {
                        Circle().fill(P.mint.opacity(0.18)).frame(width: 80, height: 80)
                        Image(systemName: "sparkles")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(P.mint)
                    }
                    Text("All clear!").font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text("Nothing on your plate. Tap + to add something.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(P.textDim)
                }
                .foregroundStyle(P.text)
                .frame(maxWidth: .infinity).padding(.vertical, 32).padding(.horizontal, 24)
                .background(RoundedRectangle(cornerRadius: 24).fill(P.surface))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            }.buttonStyle(.row)
        }

        /// Bucket type for the grouped task list. Order is canonical:
        /// Today → Tomorrow → This week → Later → No date → Bundles.
        private enum TaskBucket: Int, CaseIterable {
            case overdue, today, tomorrow, thisWeek, later, noDate, bundles
            var title: String {
                switch self {
                case .overdue:  return "Overdue"
                case .today:    return "Today"
                case .tomorrow: return "Tomorrow"
                case .thisWeek: return "This week"
                case .later:    return "Later"
                case .noDate:   return "No date"
                case .bundles:  return "Bundles"
                }
            }
        }

        /// Slot a task into the right bucket based on its due date.
        /// Bundles get their own bucket regardless of date so they don't
        /// get scattered through the day buckets.
        private func bucket(for t: TaskItem) -> TaskBucket {
            if t.isChoreBundle { return .bundles }
            guard let d = t.dueDate else { return .noDate }
            let cal = Calendar.current
            let now = Date()
            if d < cal.startOfDay(for: now) { return .overdue }
            if cal.isDateInToday(d) { return .today }
            if cal.isDateInTomorrow(d) { return .tomorrow }
            if cal.isDate(d, equalTo: now, toGranularity: .weekOfYear) { return .thisWeek }
            return .later
        }

        /// Visible items grouped by bucket, preserving the natural
        /// dueDate-ascending order within each bucket.
        private var bucketedItems: [(TaskBucket, [TaskItem])] {
            var groups: [TaskBucket: [TaskItem]] = [:]
            for t in visibleItems { groups[bucket(for: t), default: []].append(t) }
            return TaskBucket.allCases.compactMap { b in
                guard let items = groups[b], !items.isEmpty else { return nil }
                return (b, items)
            }
        }

        /// Task list grouped by Today / Tomorrow / This week / etc.
        /// Each section has a sentence-case header in the same friendly
        /// rounded family as the rest of the screen.
        private var groupedTaskList: some View {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(bucketedItems, id: \.0) { (bucket, items) in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(bucket.title)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(bucket == .overdue ? P.coral : P.textDim)
                                .padding(.leading, 4)
                            Spacer()
                            Text("\(items.count)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(P.textMuted).padding(.trailing, 4)
                        }
                        VStack(spacing: 10) {
                            ForEach(items, id: \.uid) { t in
                                if t.isChoreBundle {
                                    choreBundleCard(t)
                                } else {
                                    taskCard(t)
                                }
                            }
                        }
                    }
                }
            }
        }

        private var listHeader: String {
            let kind = kindFilter == "All" ? "" : kindFilter.capitalized + " · "
            switch timeFilter {
            case "Today":     return "\(kind)Today"
            case "This week": return "\(kind)This week"
            default:          return kindFilter == "All" ? "Open" : kindFilter.capitalized
            }
        }

        private func taskCard(_ t: TaskItem) -> some View {
            let color = categoryColor(t.category)
            return Button { editingTask = t } label: {
                HStack(spacing: 14) {
                    // Soft circular badge with the category icon — replaces the
                    // industrial side stripe with something that reads as a
                    // friendly category cue.
                    ZStack {
                        Circle().fill(color.opacity(0.18)).frame(width: 40, height: 40)
                        Image(systemName: kindIcon(for: t.category))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(color)
                    }
                    // Complete button
                    Button {
                        completeTask(t)
                    } label: {
                        if t.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 26)).foregroundStyle(color)
                        } else {
                            Circle().stroke(color.opacity(0.55), lineWidth: 2)
                                .frame(width: 26, height: 26)
                        }
                    }.buttonStyle(.row)

                    // Text
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t.task)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(P.text)
                            .lineLimit(2)
                        HStack(spacing: 6) {
                            if let d = t.dueDate {
                                Text(whenString(d))
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(P.textDim)
                                Text("·").foregroundStyle(P.textMuted)
                            }
                            Text(t.category.capitalized)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(P.textDim)
                        }
                    }

                    Spacer(minLength: 4)

                    // Right side: avatar + points
                    VStack(alignment: .trailing, spacing: 6) {
                        if let cl = memberFor(t.assignee) { CLAvatar(cl, size: 28) }
                        if t.points > 0 {
                            Text("+\(t.points)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(color)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(color.opacity(0.15)))
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(P.surface)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
            }.buttonStyle(.row)
        }

        // MARK: – Bundles in progress

        private var bundlesInProgressSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Bundles in progress ⚡")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(P.text).padding(.leading, 4)
                    Spacer()
                    Text("\(bundlesInProgress.count)")
                        .font(.system(size: 11, weight: .heavy)).foregroundStyle(P.textMuted).padding(.trailing, 4)
                }
                ForEach(bundlesInProgress) { bundle in
                    draftBundleCard(bundle)
                }
            }
        }

        private func draftBundleCard(_ bundle: TaskItem) -> some View {
            let color = categoryColor(bundle.category)
            let children = todos.filter { $0.parentUid == bundle.uid }
            let newItemKey = bundle.uid
            let newItemBinding = Binding<String>(
                get: { bundleNewItem[newItemKey] ?? "" },
                set: { bundleNewItem[newItemKey] = $0 }
            )
            let newPtsBinding = Binding<Int>(
                get: { bundleDraftItemPoints[newItemKey] ?? 10 },
                set: { bundleDraftItemPoints[newItemKey] = $0 }
            )

            return VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack(alignment: .firstTextBaseline) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 4, height: 16)
                        Text(bundle.task).font(.system(size: 16, weight: .heavy))
                    }
                    Spacer()
                    if bundle.points > 0 {
                        HStack(spacing: 3) {
                            Text("⚡️⚡️").font(.system(size: 8))
                            Text("+\(bundle.points) bonus")
                        }
                        .font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(P.butter.opacity(0.9)))
                    }
                    // Finalize button
                    Button {
                        bundle.repeatKind = "bundle"
                        try? modelContext.save()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy))
                            Text("Finalize").font(.system(size: 11, weight: .heavy))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(P.mint))
                    }.buttonStyle(.row)
                }

                // Chore list
                if children.isEmpty {
                    Text("No chores yet — add below")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textMuted).padding(.leading, 4)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(children.enumerated()), id: \.element.uid) { i, child in
                            HStack(spacing: 10) {
                                Circle().stroke(color, lineWidth: 1.5).frame(width: 16, height: 16)
                                    .opacity(0.5)
                                Text(child.task)
                                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(P.text)
                                Spacer()
                                if child.points > 0 {
                                    Text("+\(child.points)")
                                        .font(.system(size: 10, weight: .heavy)).foregroundStyle(P.textMuted)
                                }
                                Button { child.softDelete(); try? modelContext.save() } label: {
                                    Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(P.textMuted)
                                }.buttonStyle(.row)
                            }
                            .padding(.vertical, 8).padding(.leading, 4)
                            .overlay(alignment: .top) {
                                if i > 0 { Rectangle().fill(P.border).frame(height: 1) }
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(P.surfaceAlt.opacity(0.5)))
                }

                // Inline add with per-item points
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle").font(.system(size: 15)).foregroundStyle(P.textDim)
                    TextField("Add a chore…", text: newItemBinding)
                        .font(.system(size: 13, weight: .semibold))
                        .submitLabel(.done)
                        .onSubmit { addChoreToDraft(bundle) }
                    // Points picker — cycles 5 → 10 → 15 → 0
                    HStack(spacing: 4) {
                        Button { newPtsBinding.wrappedValue = max(0, newPtsBinding.wrappedValue - 5) } label: {
                            Image(systemName: "minus").font(.system(size: 10, weight: .heavy))
                        }.buttonStyle(.row)
                        Text("\(newPtsBinding.wrappedValue)pt")
                            .font(.system(size: 11, weight: .heavy)).foregroundStyle(P.text)
                            .frame(minWidth: 28)
                        Button { newPtsBinding.wrappedValue = min(50, newPtsBinding.wrappedValue + 5) } label: {
                            Image(systemName: "plus").font(.system(size: 10, weight: .heavy))
                        }.buttonStyle(.row)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(P.surfaceAlt))
                    Button { addChoreToDraft(bundle) } label: {
                        Image(systemName: "arrow.up").font(.system(size: 12, weight: .heavy)).foregroundStyle(.white)
                            .frame(width: 26, height: 26).background(Circle().fill(color))
                    }.buttonStyle(.row)
                }
                .padding(.horizontal, 12).padding(.vertical, 6).padding(.trailing, 4)
                .background(Capsule().fill(P.surfaceAlt))
                .overlay(Capsule().stroke(P.border, lineWidth: 1.5))

                HStack {
                    Text("\(children.count) chore\(children.count == 1 ? "" : "s") added")
                        .font(.system(size: 10, weight: .heavy)).foregroundStyle(P.textMuted).padding(.leading, 4)
                    Spacer()
                    Button {
                        children.forEach { $0.softDelete() }
                        bundle.softDelete()
                        try? modelContext.save()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash").font(.system(size: 10, weight: .heavy))
                            Text("Delete bundle").font(.system(size: 11, weight: .heavy))
                        }
                        .foregroundStyle(Color.red.opacity(0.8))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Color.red.opacity(0.12)))
                    }.buttonStyle(.row)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(color.opacity(0.4), lineWidth: 1.5))
        }

        private func addChoreToDraft(_ bundle: TaskItem) {
            let key = bundle.uid
            let text = (bundleNewItem[key] ?? "").trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return }
            let pts = bundleDraftItemPoints[key] ?? 10
            let myName = FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)?.name ?? userName
            let chore = TaskItem(
                context: modelContext,
                task: text,
                category: bundle.category,
                points: pts,
                createdBy: myName.trimmingCharacters(in: .whitespaces)
            )
            chore.parentUid = bundle.uid
            chore.assignee = bundle.assignee
            if let h = households.preferredTarget {
                modelContext.assign(chore, toStoreOf: h)
                chore.household = h
            }
            try? modelContext.save()
            bundleNewItem[key] = ""
        }

        // MARK: – Bundle card

        private func choreBundleCard(_ bundle: TaskItem) -> some View {
            let color = categoryColor(bundle.category)
            let children = todos.filter { $0.parentUid == bundle.uid }.sorted { !$0.isCompleted && $1.isCompleted }
            let doneCount = children.filter { $0.isCompleted }.count
            let totalCount = children.count
            let allDone = totalCount > 0 && doneCount == totalCount
            let isExpanded = expandedBundles.contains(bundle.uid)

            return VStack(spacing: 0) {
                // Bundle header — tap to expand/collapse
                Button {
                    if isExpanded { expandedBundles.remove(bundle.uid) }
                    else { expandedBundles.insert(bundle.uid) }
                } label: {
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 3).fill(color)
                            .frame(width: 5).padding(.vertical, 10)
                        HStack(spacing: 12) {
                            // Progress ring
                            ZStack {
                                Circle().stroke(color.opacity(0.25), lineWidth: 3).frame(width: 28, height: 28)
                                if totalCount > 0 {
                                    Circle()
                                        .trim(from: 0, to: CGFloat(doneCount) / CGFloat(totalCount))
                                        .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                        .frame(width: 28, height: 28)
                                        .rotationEffect(.degrees(-90))
                                }
                                if allDone {
                                    Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(color)
                                } else {
                                    Text("\(doneCount)").font(.system(size: 9, weight: .heavy)).foregroundStyle(color)
                                }
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(bundle.task).font(.system(size: 15, weight: .heavy)).foregroundStyle(allDone ? P.textDim : P.text)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .heavy))
                                        .foregroundStyle(P.textDim)
                                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                                }
                                Text("\(doneCount)/\(totalCount) done").font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textDim)
                            }

                            Spacer(minLength: 4)

                            VStack(alignment: .trailing, spacing: 4) {
                                if let cl = memberFor(bundle.assignee) { CLAvatar(cl, size: 26) }
                                if bundle.points > 0 {
                                    HStack(spacing: 2) {
                                        Text("⚡️⚡️").font(.system(size: 8))
                                        Text("+\(bundle.points) bonus")
                                    }
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Capsule().fill(P.butter.opacity(0.9)))
                                }
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                    }
                }.buttonStyle(.row)

                // Expanded child chores + inline add
                if isExpanded {
                    VStack(spacing: 0) {
                        Rectangle().fill(P.border).frame(height: 1).padding(.leading, 19)
                        ForEach(children, id: \.uid) { child in
                            HStack(spacing: 12) {
                                Button { completeTask(child) } label: {
                                    if child.isCompleted {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 22)).foregroundStyle(color)
                                    } else {
                                        Circle().stroke(color, lineWidth: 2).frame(width: 22, height: 22)
                                    }
                                }.buttonStyle(.row)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(child.task)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(child.isCompleted ? P.textDim : P.text)
                                        .strikethrough(child.isCompleted, color: P.textDim)
                                    if child.points > 0 {
                                        Text("+\(child.points) pts").font(.system(size: 10, weight: .heavy)).foregroundStyle(P.textDim)
                                    }
                                }
                                Spacer()
                                if let cl = memberFor(child.assignee) { CLAvatar(cl, size: 22) }
                            }
                            .padding(.leading, 54).padding(.trailing, 14).padding(.vertical, 10)
                            .background(P.surfaceAlt.opacity(0.5))
                            Rectangle().fill(P.border).frame(height: 1).padding(.leading, 54)
                        }
                        // Assignee picker (admin, shown when unassigned or to reassign)
                        if iAmAdmin {
                            HStack(spacing: 10) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 12, weight: .heavy))
                                    .foregroundStyle(P.sky)
                                Text("Assigned to").font(.system(size: 12, weight: .semibold)).foregroundStyle(P.textDim)
                                Spacer()
                                Menu {
                                    Button("Anyone") { bundle.assignee = nil; try? modelContext.save() }
                                    ForEach(members, id: \.uid) { m in
                                        Button(m.name) { bundle.assignee = m.name; try? modelContext.save() }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(bundle.assignee ?? "Anyone")
                                            .font(.system(size: 12, weight: .heavy)).foregroundStyle(P.text)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 9, weight: .heavy)).foregroundStyle(P.textDim)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Capsule().fill(P.surfaceAlt))
                                }
                            }
                            .padding(.leading, 14).padding(.trailing, 10).padding(.vertical, 8)
                            .background(P.surfaceAlt.opacity(0.2))
                            Rectangle().fill(P.border).frame(height: 1).padding(.leading, 14)
                        }
                        // Bonus points editor (admin only)
                        if iAmAdmin {
                            HStack(spacing: 10) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 12, weight: .heavy))
                                    .foregroundStyle(P.butter)
                                Text("Bonus pts").font(.system(size: 12, weight: .semibold)).foregroundStyle(P.textDim)
                                Spacer()
                                HStack(spacing: 8) {
                                    Button { bundle.points = max(0, bundle.points - 5); try? modelContext.save() } label: {
                                        Image(systemName: "minus").font(.system(size: 11, weight: .heavy))
                                            .frame(width: 26, height: 26).background(Circle().fill(P.surfaceAlt))
                                    }.buttonStyle(.row)
                                    Text("\(bundle.points) pts")
                                        .font(.system(size: 13, weight: .heavy)).foregroundStyle(P.text)
                                        .frame(minWidth: 50, alignment: .center)
                                    Button { bundle.points = min(500, bundle.points + 5); try? modelContext.save() } label: {
                                        Image(systemName: "plus").font(.system(size: 11, weight: .heavy))
                                            .frame(width: 26, height: 26).background(Circle().fill(P.surfaceAlt))
                                    }.buttonStyle(.row)
                                }
                            }
                            .padding(.leading, 14).padding(.trailing, 10).padding(.vertical, 8)
                            .background(P.surfaceAlt.opacity(0.2))
                            Rectangle().fill(P.border).frame(height: 1).padding(.leading, 14)
                        }

                        // Inline add-chore row with points picker
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(color.opacity(0.6))
                            TextField("Add a chore to this bundle…",
                                      text: Binding(
                                        get: { bundleNewItem[bundle.uid] ?? "" },
                                        set: { bundleNewItem[bundle.uid] = $0 }
                                      ))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(P.text)
                                .onSubmit { addChoreToBundle(bundle) }
                            // Points picker
                            HStack(spacing: 4) {
                                Button { bundleInlinePoints[bundle.uid] = max(0, (bundleInlinePoints[bundle.uid] ?? 10) - 5) } label: {
                                    Image(systemName: "minus").font(.system(size: 9, weight: .heavy))
                                }.buttonStyle(.row)
                                Text("\(bundleInlinePoints[bundle.uid] ?? 10)pt")
                                    .font(.system(size: 10, weight: .heavy)).foregroundStyle(P.text)
                                    .frame(minWidth: 26)
                                Button { bundleInlinePoints[bundle.uid] = min(100, (bundleInlinePoints[bundle.uid] ?? 10) + 5) } label: {
                                    Image(systemName: "plus").font(.system(size: 9, weight: .heavy))
                                }.buttonStyle(.row)
                            }
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(P.surfaceAlt))
                            Button { addChoreToBundle(bundle) } label: {
                                Image(systemName: "arrow.up").font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
                                    .frame(width: 24, height: 24).background(Circle().fill(color))
                            }.buttonStyle(.row)
                        }
                        .padding(.leading, 14).padding(.trailing, 10).padding(.vertical, 8)
                        .background(P.surfaceAlt.opacity(0.3))

                        // Admin delete button
                        if iAmAdmin {
                            Button {
                                children.forEach { $0.softDelete() }
                                bundle.softDelete()
                                try? modelContext.save()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash").font(.system(size: 10, weight: .heavy))
                                    Text("Delete bundle").font(.system(size: 11, weight: .heavy))
                                }
                                .foregroundStyle(Color.red.opacity(0.8))
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                                .background(Color.red.opacity(0.08))
                            }.buttonStyle(.row)
                        }
                    }
                }
            }
            .background(P.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(allDone ? color.opacity(0.5) : P.border, lineWidth: 1.5))
        }

        // MARK: – Recently done

        private var recentlyDone: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Recently done").font(.system(size: 13, weight: .heavy)).foregroundStyle(P.text).padding(.leading, 4)
                    Spacer()
                    if !completed.isEmpty {
                        Text("\(completed.count) done").font(.system(size: 12, weight: .heavy)).foregroundStyle(P.peach).padding(.trailing, 4)
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
        private enum TripSheet: Identifiable {
            case new, edit(TaskItem)
            var id: String {
                switch self { case .new: return "new"; case .edit(let t): return t.uid }
            }
        }
        @State private var tripSheet: TripSheet? = nil
        @State private var newItemByTrip: [String: String] = [:]
        @AppStorage("userName") private var userName: String = ""
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: false)], predicate: NSPredicate(format: "deletedAt == nil")) private var allTasks: FetchedResults<TaskItem>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil")) private var members: FetchedResults<FamilyMember>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil")) private var households: FetchedResults<Household>
        private var dark: Bool { darkOverride ?? (sys == .dark) }
        @AppStorage("paletteName") private var paletteName: String = "vivid"
        private var P: Palette { Palette.resolveForPreview(paletteName, dark: dark) }
        public init() {}

        private var groceryTasks: [TaskItem] { allTasks.filter { $0.category.lowercased() == "groceries" } }
        // A "trip" is a top-level grocery task that's either explicitly
        // a container (created via AddGroceryTripView, stamped points = -1)
        // OR has a dueDate (legacy outings created before the sentinel).
        private var trips: [TaskItem] {
            groceryTasks.filter { $0.parentUid.isEmpty && ($0.isContainer || $0.dueDate != nil) }
                .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        }
        // Flat items: top-level quick-add grocery items (no parent,
        // no date, not a container). Stays in the existing inline-add bucket.
        private var flatActive: [TaskItem] {
            groceryTasks.filter { $0.parentUid.isEmpty && $0.dueDate == nil && !$0.isContainer && !$0.isCompleted }
        }
        private var flatBought: [TaskItem] {
            groceryTasks.filter { $0.parentUid.isEmpty && $0.dueDate == nil && !$0.isContainer && $0.isCompleted }
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
                    ScrollView { content }
                        .scrollIndicators(.hidden)
                        .refreshable {
                            // Pull-to-refresh: wait briefly so CloudKit can
                            // land pending shared-zone changes, then drop
                            // cached objects so @FetchRequests re-read.
                            try? await Task.sleep(for: .seconds(2))
                            modelContext.refreshAllObjects()
                        }
                }
            }
            .foregroundStyle(P.text)
            .preferredColorScheme(dark ? .dark : .light)
            .sheet(item: $tripSheet) { mode in
                switch mode {
                case .new: AddGroceryTripView()
                case .edit(let trip): AddGroceryTripView(editing: trip)
                }
            }
            .swipeToDismiss()
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
                Button { tripSheet = .new } label: {
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
                staplesGrid
                if !trips.isEmpty { tripsSection }
                flatActiveSection
                boughtSection
            }.padding(.horizontal, 20).padding(.bottom, 28)
        }

        // MARK: – Staples grid

        private static let staples: [(name: String, emoji: String)] = [
            ("Milk",          "🥛"),
            ("Eggs",          "🥚"),
            ("Bread",         "🍞"),
            ("Butter",        "🧈"),
            ("Cheese",        "🧀"),
            ("Chicken",       "🍗"),
            ("Ground beef",   "🥩"),
            ("Apples",        "🍎"),
            ("Bananas",       "🍌"),
            ("Broccoli",      "🥦"),
            ("Tomatoes",      "🍅"),
            ("Onions",        "🧅"),
            ("Potatoes",      "🥔"),
            ("Garlic",        "🧄"),
            ("Lemons",        "🍋"),
            ("Rice",          "🍚"),
            ("Pasta",         "🍝"),
            ("Cereal",        "🥣"),
            ("Coffee",        "☕"),
            ("Juice",         "🧃"),
            ("Toilet paper",  "🧻"),
            ("Dish soap",     "🧴"),
            ("Sponges",       "🧽"),
            ("Paper towels",  "🪣"),
        ]

        private var staplesGrid: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("STAPLES").font(.system(size: 11, weight: .heavy)).tracking(1.2)
                    .foregroundStyle(P.textDim).padding(.leading, 4)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Self.staples, id: \.name) { staple in
                        let alreadyOn = flatActive.contains { $0.task.lowercased() == staple.name.lowercased() }
                        Button {
                            if !alreadyOn { addStaple(staple.name) }
                        } label: {
                            VStack(spacing: 4) {
                                Text(staple.emoji).font(.system(size: 24))
                                Text(staple.name)
                                    .font(.system(size: 11, weight: .heavy))
                                    .foregroundStyle(alreadyOn ? P.textMuted : P.text)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12).padding(.horizontal, 6)
                            .background(RoundedRectangle(cornerRadius: 16)
                                .fill(alreadyOn ? P.surfaceAlt.opacity(0.5) : P.surface))
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .stroke(alreadyOn ? P.mint.opacity(0.6) : P.border, lineWidth: 1.5))
                        }
                        .buttonStyle(.row)
                        .disabled(alreadyOn)
                    }
                }
            }
        }

        private func addStaple(_ name: String) {
            let it = TaskItem(
                context: modelContext,
                task: name,
                category: "groceries",
                points: 0,
                createdBy: userName.trimmingCharacters(in: .whitespaces)
            )
            if let h = households.preferredTarget {
                modelContext.assign(it, toStoreOf: h)
                it.household = h
            }
            try? modelContext.save()
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
            // BUG FIX: previously used allTasks.first?.household which
            // returned nil for a household with zero existing tasks,
            // leaving the new grocery item orphaned (no household =
            // doesn't sync to the share). Use households.preferredTarget
            // which falls through to the shared store (joiner) or the
            // private/share-root household (owner).
            if let h = households.preferredTarget {
                modelContext.assign(it, toStoreOf: h)
                it.household = h
            }
            try? modelContext.save()
            newItem = ""
        }

        private func tripDateText(_ d: Date) -> String {
            let cal = Calendar.current
            let comps = cal.dateComponents([.hour, .minute], from: d)
            let hasTime = (comps.hour ?? 0) != 0 || (comps.minute ?? 0) != 0
            if cal.isDateInToday(d) {
                if hasTime {
                    let f = DateFormatter(); f.dateFormat = "'Today' h:mm a"
                    return f.string(from: d)
                }
                return "Today"
            }
            let f = DateFormatter()
            if cal.isDateInTomorrow(d) {
                f.dateFormat = hasTime ? "'Tmrw' h:mm a" : "'Tmrw'"
            } else {
                f.dateFormat = hasTime ? "MMM d · h:mm a" : "MMM d"
            }
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
                        for it in tripItems { it.softDelete() }
                        trip.softDelete()
                        try? modelContext.save()
                    } label: {
                        Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(P.textMuted)
                    }.buttonStyle(.row)
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
                                }.buttonStyle(.row)
                                Text(t.task)
                                    .font(.system(size: 13, weight: .semibold))
                                    .strikethrough(t.isCompleted)
                                    .foregroundStyle(t.isCompleted ? P.textDim : P.text)
                                Spacer()
                                Button { t.softDelete(); try? modelContext.save() } label: {
                                    Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(P.textMuted)
                                }.buttonStyle(.row)
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
            .contentShape(RoundedRectangle(cornerRadius: 22))
            .onTapGesture { tripSheet = .edit(trip) }
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
                }.buttonStyle(.row)
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
                }.buttonStyle(.row)
                Text(t.task).font(.system(size: 14, weight: .heavy))
                Spacer()
                Button { t.softDelete(); try? modelContext.save() } label: {
                    Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(P.textMuted)
                }.buttonStyle(.row)
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
                                }.buttonStyle(.row)
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
            for t in flatBought { t.softDelete() }
            try? modelContext.save()
        }
    }

    public struct Maintenance: View {
        @Environment(\.colorScheme) private var sys
        @Environment(\.dismiss) private var dismiss
        @Environment(\.managedObjectContext) private var modelContext
        @State private var darkOverride: Bool? = nil
        @State private var showAdd = false
        /// Category pill — "Home" or "Maintenance". The dashboard tile is now
        /// labeled "Home" and lands here; default to the home category so the
        /// view title matches what the user just tapped.
        @State private var categoryPill: String = "Home"
        @State private var quickAddTarget: DefaultChore? = nil
        @State private var newItem: String = ""
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.dueDate, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil")) private var allTasks: FetchedResults<TaskItem>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil")) private var members: FetchedResults<FamilyMember>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil")) private var households: FetchedResults<Household>
        @AppStorage("userName") private var userName: String = ""
        private var dark: Bool { darkOverride ?? (sys == .dark) }
        @AppStorage("paletteName") private var paletteName: String = "vivid"
        private var P: Palette { Palette.resolveForPreview(paletteName, dark: dark) }
        public init() {}

        // MARK: – Default chore catalogue

        struct DefaultChore: Identifiable {
            let id = UUID()
            let name: String
            let emoji: String
            let points: Int
            let category: String   // "home" or "maintenance"
        }

        private static let homeDefaults: [DefaultChore] = [
            DefaultChore(name: "Vacuum floors",    emoji: "🧹", points: 15, category: "home"),
            DefaultChore(name: "Mop floors",       emoji: "🪣", points: 15, category: "home"),
            DefaultChore(name: "Clean bathrooms",  emoji: "🚿", points: 20, category: "home"),
            DefaultChore(name: "Do laundry",       emoji: "🧺", points: 10, category: "home"),
            DefaultChore(name: "Change bed sheets",emoji: "🛏️", points: 10, category: "home"),
            DefaultChore(name: "Take out trash",   emoji: "🗑️", points: 10, category: "home"),
            DefaultChore(name: "Clean kitchen",    emoji: "🍽️", points: 15, category: "home"),
            DefaultChore(name: "Clean windows",    emoji: "🪟", points: 15, category: "home"),
            DefaultChore(name: "Dust surfaces",    emoji: "🪶", points: 10, category: "home"),
            DefaultChore(name: "Wipe counters",    emoji: "🧽", points: 10, category: "home"),
        ]

        private static let maintenanceDefaults: [DefaultChore] = [
            DefaultChore(name: "Change air filter",  emoji: "💨", points: 20, category: "maintenance"),
            DefaultChore(name: "Test smoke alarms",  emoji: "🔋", points: 15, category: "maintenance"),
            DefaultChore(name: "Check under sinks",  emoji: "💧", points: 10, category: "maintenance"),
            DefaultChore(name: "Clean gutters",      emoji: "🍂", points: 25, category: "maintenance"),
            DefaultChore(name: "Replace light bulbs",emoji: "💡", points: 10, category: "maintenance"),
            DefaultChore(name: "Clean dryer vent",   emoji: "🌀", points: 20, category: "maintenance"),
            DefaultChore(name: "Check water heater", emoji: "🌡️", points: 15, category: "maintenance"),
            DefaultChore(name: "Pest check",         emoji: "🐛", points: 15, category: "maintenance"),
            DefaultChore(name: "Caulk & seals",      emoji: "🔩", points: 20, category: "maintenance"),
            DefaultChore(name: "Check fire extinguisher", emoji: "🧯", points: 15, category: "maintenance"),
        ]

        private var currentDefaults: [DefaultChore] {
            categoryPill == "Maintenance" ? Self.maintenanceDefaults : Self.homeDefaults
        }

        private var activeCategoryTag: String {
            categoryPill == "Maintenance" ? "maintenance" : "home"
        }
        private var maintenanceTasks: [TaskItem] { allTasks.filter { $0.category.lowercased() == activeCategoryTag } }
        private var active: [TaskItem] { maintenanceTasks.filter { !$0.isCompleted } }
        private var done: [TaskItem] { maintenanceTasks.filter { $0.isCompleted } }
        private var overdue: [TaskItem] {
            let startOfToday = Calendar.current.startOfDay(for: Date())
            return active.filter { ($0.dueDate ?? .distantFuture) < startOfToday }
        }
        private var dueSoon: [TaskItem] {
            let startOfToday = Calendar.current.startOfDay(for: Date())
            let weekOut = Calendar.current.date(byAdding: .day, value: 7, to: startOfToday) ?? startOfToday
            return active.filter { ($0.dueDate ?? .distantFuture) >= startOfToday && ($0.dueDate ?? .distantFuture) <= weekOut }
        }
        private var laterItems: [TaskItem] {
            let startOfToday = Calendar.current.startOfDay(for: Date())
            let weekOut = Calendar.current.date(byAdding: .day, value: 7, to: startOfToday) ?? startOfToday
            return active.filter { ($0.dueDate ?? .distantFuture) > weekOut }
        }

        public var body: some View {
            ZStack {
                P.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                    ScrollView { content }
                        .scrollIndicators(.hidden)
                        .refreshable {
                            // Pull-to-refresh: wait briefly so CloudKit can
                            // land pending shared-zone changes, then drop
                            // cached objects so @FetchRequests re-read.
                            try? await Task.sleep(for: .seconds(2))
                            modelContext.refreshAllObjects()
                        }
                }
            }
            .foregroundStyle(P.text)
            .preferredColorScheme(dark ? .dark : .light)
            .sheet(isPresented: $showAdd) {
                AddTaskView(defaultCategory: categoryPill == "Maintenance" ? "Maintenance" : "home")
            }
            .sheet(item: $quickAddTarget) { chore in
                quickAddSheet(chore)
            }
            .swipeToDismiss()
        }

        private var pill: some View {
            HStack(spacing: 8) {
                ForEach(["Home", "Maintenance"], id: \.self) { opt in
                    let active = categoryPill == opt
                    Button { categoryPill = opt } label: {
                        HStack(spacing: 6) {
                            Image(systemName: opt == "Home" ? "house.fill" : "wrench.and.screwdriver.fill")
                                .font(.system(size: 11, weight: .heavy))
                            Text(opt).font(.system(size: 13, weight: .heavy))
                        }
                        .foregroundStyle(active ? .white : P.textDim)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(active ? P.lavender : P.surfaceAlt))
                    }.buttonStyle(.row)
                }
                Spacer()
            }
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
                pill
                quickAddRow
                quickAddGrid
                if !active.isEmpty || !done.isEmpty {
                    section(title: "OVERDUE ⚠️", items: overdue, color: P.coral)
                    section(title: "DUE THIS WEEK 📅", items: dueSoon, color: P.butter)
                    section(title: "UPCOMING", items: laterItems, color: P.lavender)
                    section(title: "DONE ✓", items: done.suffix(5).map { $0 }, color: P.mint, completed: true)
                }
            }.padding(.horizontal, 20).padding(.bottom, 28)
        }

        private var quickAddRow: some View {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle").font(.system(size: 18)).foregroundStyle(P.textDim)
                TextField("Quick task...", text: $newItem)
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
            let myName = (members.first(where: { $0.name == userName })?.name ?? userName)
                .trimmingCharacters(in: .whitespaces)
            let cat = categoryPill.lowercased()
            let it = TaskItem(
                context: modelContext,
                task: name,
                category: cat,
                points: 10,
                createdBy: myName
            )
            it.assignee = myName
            if let h = households.preferredTarget {
                modelContext.assign(it, toStoreOf: h)
                it.household = h
            }
            try? modelContext.save()
            newItem = ""
        }

        private var quickAddGrid: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("QUICK ADD").font(.system(size: 11, weight: .heavy)).tracking(1.2)
                    .foregroundStyle(P.textDim).padding(.leading, 4)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(currentDefaults) { chore in
                        Button { quickAddTarget = chore } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(chore.emoji).font(.system(size: 32))
                                Spacer()
                                Text(chore.name)
                                    .font(.system(size: 15, weight: .heavy))
                                    .foregroundStyle(P.text)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                Text("\(chore.points) pts")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(P.lavender)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .frame(minHeight: 120)
                            .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
                            .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
                        }
                        .buttonStyle(.row)
                    }
                }
            }
        }

        private func quickAddSheet(_ chore: DefaultChore) -> some View {
            QuickChoreSheet(chore: chore, members: Array(members), households: Array(households),
                            userName: userName, palette: P, moc: modelContext) {
                quickAddTarget = nil
            }
        }

        private var hero: some View {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.2)).frame(width: 76, height: 76)
                    Image(systemName: categoryPill == "Maintenance" ? "wrench.and.screwdriver.fill" : "house.fill")
                        .font(.system(size: 32)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(categoryPill.uppercased()).font(.system(size: 11, weight: .heavy)).tracking(0.8).opacity(0.85)
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
                    Text(categoryPill == "Maintenance" ? "🔧" : "🏠").font(.system(size: 36))
                    Text("Nothing scheduled").font(.system(size: 14, weight: .heavy))
                    Text(categoryPill == "Maintenance"
                         ? "Tap + to add a maintenance task"
                         : "Tap + to add a home task")
                        .font(.system(size: 11, weight: .semibold)).opacity(0.7)
                }
                .foregroundStyle(P.text)
                .frame(maxWidth: .infinity).padding(24)
                .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
            }.buttonStyle(.row)
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
                                }.buttonStyle(.row)
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
                                Button { t.softDelete() } label: {
                                    Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(P.textMuted)
                                }.buttonStyle(.row)
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

    // MARK: – Quick Chore Sheet

    private struct QuickChoreSheet: View {
        let chore: Maintenance.DefaultChore
        let members: [FamilyMember]
        let households: [Household]
        let userName: String
        let palette: Palette
        let moc: NSManagedObjectContext
        let onDone: () -> Void

        @State private var points: Int
        @State private var assignee: String = ""
        @State private var dueDate: Date = Calendar.current.startOfDay(for: Date())
        @State private var hasDueDate: Bool = true

        init(chore: Maintenance.DefaultChore, members: [FamilyMember], households: [Household],
             userName: String, palette: Palette, moc: NSManagedObjectContext, onDone: @escaping () -> Void) {
            self.chore = chore
            self.members = members
            self.households = households
            self.userName = userName
            self.palette = palette
            self.moc = moc
            self.onDone = onDone
            _points = State(initialValue: chore.points)
        }

        private var P: Palette { palette }

        var body: some View {
            NavigationStack {
                ZStack {
                    P.bg.ignoresSafeArea()
                    VStack(spacing: 0) {
                        // Header
                        VStack(spacing: 6) {
                            Text(chore.emoji).font(.system(size: 52))
                            Text(chore.name).font(.system(size: 22, weight: .heavy)).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)

                        // Options
                        VStack(spacing: 0) {
                            // Points row
                            HStack {
                                Label("Points", systemImage: "star.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(P.text)
                                Spacer()
                                Stepper("\(points) pts", value: $points, in: 5...500, step: 5)
                                    .labelsHidden()
                                Text("\(points) pts")
                                    .font(.system(size: 14, weight: .heavy))
                                    .foregroundStyle(P.lavender)
                                    .frame(width: 56, alignment: .trailing)
                            }
                            .padding(.horizontal, 20).padding(.vertical, 14)
                            Divider().padding(.leading, 20)

                            // Assignee row
                            HStack {
                                Label("Assign to", systemImage: "person.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(P.text)
                                Spacer()
                                Picker("", selection: $assignee) {
                                    Text("Anyone").tag("")
                                    ForEach(members, id: \.uid) { m in
                                        Text(m.name).tag(m.name)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(P.lavender)
                            }
                            .padding(.horizontal, 20).padding(.vertical, 14)
                            Divider().padding(.leading, 20)

                            // Due date row
                            HStack {
                                Label("Due", systemImage: "calendar")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(P.text)
                                Spacer()
                                if hasDueDate {
                                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                                        .datePickerStyle(.compact).labelsHidden()
                                }
                                Toggle("", isOn: $hasDueDate).labelsHidden()
                            }
                            .padding(.horizontal, 20).padding(.vertical, 14)
                        }
                        .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
                        .padding(.horizontal, 20)

                        Spacer()

                        // Add button
                        Button {
                            addChore()
                        } label: {
                            Text("Add to List")
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Capsule().fill(P.lavender))
                        }
                        .buttonStyle(.row)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                }
                .foregroundStyle(P.text)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { onDone() }
                            .foregroundStyle(P.text)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }

        private func addChore() {
            let task = TaskItem(
                context: moc,
                task: chore.name,
                assignee: assignee.isEmpty ? nil : assignee,
                dueDate: hasDueDate ? dueDate : nil,
                category: chore.category,
                isCompleted: false,
                points: points,
                createdBy: userName,
                repeatHours: 0,
                repeatKind: ""
            )
            if let h = households.preferredTarget {
                moc.assign(task, toStoreOf: h)
                task.household = h
            }
            try? moc.save()
            Task { await NotificationsManager.scheduleNow(for: task) }
            onDone()
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
        @State private var showHistory: Bool = false
        @State private var showTemplates: Bool = false
        @State private var pendingTemplate: ReminderTemplate? = nil
        @State private var expandedHourlyIds: Set<NSManagedObjectID> = []
        /// Mirror of the user's linked Apple Reminders list (read-only).
        /// Empty when no list is linked or access wasn't granted.
        @State private var linkedReminders: [EKReminder] = []
        @AppStorage("userName") private var userName: String = ""
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: false)], predicate: NSPredicate(format: "deletedAt == nil")) private var allTasks: FetchedResults<TaskItem>
        private var dark: Bool { darkOverride ?? (sys == .dark) }
        @AppStorage("paletteName") private var paletteName: String = "vivid"
        private var P: Palette { Palette.resolveForPreview(paletteName, dark: dark) }
        public init() {}

        private var allReminders: [TaskItem] { allTasks.filter { $0.category.lowercased() == "reminders" } }
        private var hourlyReminders: [TaskItem] {
            allReminders.filter { $0.effectiveRepeatKind == "hourly" }
        }
        private var otherReminders: [TaskItem] {
            allReminders.filter { !$0.isCompleted && $0.effectiveRepeatKind != "hourly" }
        }
        /// Pinned reminders, sorted by the device-local order store
        /// first (long-press → Pin to top / Send to bottom rewrites
        /// that), then by createdAt desc for anything the user hasn't
        /// explicitly reordered.
        private var pinned: [TaskItem] {
            otherReminders.sorted { a, b in
                let oa = ReminderOrderStore.order(for: a.uid)
                let ob = ReminderOrderStore.order(for: b.uid)
                if oa != ob { return oa < ob }
                return a.createdAt > b.createdAt
            }
        }

        private func reminderPriorityColor(_ p: Int64) -> Color {
            switch p {
            case 1: return .blue
            case 2: return .orange
            case 3: return .red
            default: return .clear
            }
        }

        private func iconFor(_ t: TaskItem) -> String {
            if !t.effectiveRepeatKind.isEmpty { return "arrow.triangle.2.circlepath" }
            if t.dueDate != nil { return "clock.fill" }
            return "pin.fill"
        }

        private func scheduleDetail(_ t: TaskItem) -> String? {
            let kind = t.effectiveRepeatKind
            let f = DateFormatter()
            // For cadence kinds, append " · until <time>" if the user set a
            // stop time on this reminder.
            let stopSuffix: String = {
                let mins = Int(t.repeatEndMinutes)
                guard mins > 0 else { return "" }
                let cal = Calendar.current
                let base = cal.startOfDay(for: Date())
                guard let stop = cal.date(byAdding: .minute, value: mins, to: base) else { return "" }
                let stopF = DateFormatter()
                stopF.dateFormat = "h:mm a"
                return " · until \(stopF.string(from: stop))"
            }()
            switch kind {
            case "hourly":   return "Every hour\(stopSuffix)"
            case "every2h":  return "Every 2h\(stopSuffix)"
            case "every4h":  return "Every 4h\(stopSuffix)"
            case "every8h":  return "Every 8h\(stopSuffix)"
            case "every12h": return "Every 12h\(stopSuffix)"
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
                    ScrollView { content }
                        .scrollIndicators(.hidden)
                        .refreshable {
                            // Pull-to-refresh: wait briefly so CloudKit can
                            // land pending shared-zone changes, then drop
                            // cached objects so @FetchRequests re-read.
                            try? await Task.sleep(for: .seconds(2))
                            modelContext.refreshAllObjects()
                        }
                }
            }
            .foregroundStyle(P.text)
            .preferredColorScheme(dark ? .dark : .light)
            .sheet(isPresented: $showAddReminder) {
                AddReminderView(template: pendingTemplate)
                    .onDisappear { pendingTemplate = nil }
            }
            .sheet(item: $editingReminder) { reminder in AddReminderView(editing: reminder) }
            .sheet(isPresented: $showHistory) { ReminderHistoryView() }
            .sheet(isPresented: $showTemplates) { ReminderTemplatePicker(onPick: applyTemplate) }
            .swipeToDismiss()
            .onAppear { Task { await refreshLinkedReminders() } }
            .onChange(of: allTasks.count) { _, _ in
                Task { await refreshLinkedReminders() }
            }
        }

        /// Pull EKReminders from the user's linked Apple Reminders list.
        /// Filtered to drop our own mirror items so we don't show them
        /// twice. No-op when no list is linked.
        private func refreshLinkedReminders() async {
            let svc = ReminderLinkService.shared
            let fetched = await svc.fetchReminders(includeCompleted: false)
            await MainActor.run {
                linkedReminders = fetched.filter { ek in
                    !(ek.notes ?? "").hasPrefix("Casalist:")
                }
            }
        }

        private var topBar: some View {
            HStack(spacing: 8) {
                Button { dismiss() } label: {
                    Image(systemName: "house.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(P.text)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(P.surfaceAlt))
                }
                Spacer()
                Button { showHistory = true } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(P.text)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(P.surfaceAlt))
                }
                Button { showTemplates = true } label: {
                    Image(systemName: "square.stack.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(P.text)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(P.surfaceAlt))
                }
                Button { showAddReminder = true } label: {
                    Image(systemName: "plus").font(.system(size: 19, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(P.peach))
                        .shadow(color: P.peach.opacity(0.4), radius: 8, y: 4)
                }
            }.padding(.horizontal, 16).padding(.bottom, 12)
        }

        /// Bridge: tap a template → present AddReminderView pre-filled
        /// via the template-seed initializer.
        private func applyTemplate(_ template: ReminderTemplate) {
            showTemplates = false
            // Defer a beat so the templates sheet finishes dismissing
            // before the new-reminder sheet animates in.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                pendingTemplate = template
                showAddReminder = true
            }
        }

        /// Clone the tapped reminder — copies every cadence / location /
        /// assignee / repeat-end attribute over a fresh TaskItem with a
        /// new UID. Device-local attributes (color tag, sound, photo)
        /// also carry over. Title gets a "(copy)" suffix so the user
        /// can find it quickly in the pinned grid before editing.
        private func duplicateReminder(_ src: TaskItem) {
            let dup = TaskItem(
                context: modelContext,
                task: src.task + " (copy)",
                assignee: src.assignee,
                dueDate: src.dueDate,
                category: "reminders",
                points: 0,
                createdBy: userName.trimmingCharacters(in: .whitespaces),
                repeatHours: 0,
                repeatKind: src.effectiveRepeatKind
            )
            dup.repeatEndMinutes = src.repeatEndMinutes
            dup.locationLat = src.locationLat
            dup.locationLng = src.locationLng
            dup.locationRadius = src.locationRadius
            dup.locationOnArrive = src.locationOnArrive
            dup.locationName = src.locationName
            if let h = src.household {
                modelContext.assign(dup, toStoreOf: h)
                dup.household = h
            }
            try? modelContext.save()
            // Carry device-local attributes by UID.
            let srcTag = ReminderColorTagStore.tag(for: src.uid)
            if srcTag != .none {
                ReminderColorTagStore.set(srcTag, for: dup.uid)
            }
            ReminderSoundStore.setPlaysSound(
                ReminderSoundStore.playsSound(for: src.uid),
                for: dup.uid
            )
            if let img = ReminderPhotoStore.image(for: src.uid) {
                ReminderPhotoStore.save(img, for: dup.uid)
            }
            Task { await NotificationsManager.scheduleNow(for: dup) }
            ReminderLinkService.shared.mirror(dup)
            LocationReminderService.shared.resyncMonitoredRegions(in: modelContext)
        }

        private var content: some View {
            VStack(alignment: .leading, spacing: 14) {
                hero
                quickAddRow
                listSection
                if !linkedReminders.isEmpty {
                    linkedSection
                }
            }.padding(.horizontal, 20).padding(.bottom, 28)
        }

        private var linkedSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("FROM YOUR APPLE REMINDERS 🔔")
                        .font(.system(size: 11, weight: .heavy)).tracking(1.2)
                        .foregroundStyle(P.textDim).padding(.leading, 4)
                    Spacer()
                    Text("\(linkedReminders.count)")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(P.textMuted).padding(.trailing, 4)
                }
                VStack(spacing: 0) {
                    ForEach(linkedReminders, id: \.calendarItemIdentifier) { ek in
                        linkedReminderRow(ek)
                    }
                }
                .padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
            }
        }

        private func linkedReminderRow(_ ek: EKReminder) -> some View {
            HStack(spacing: 12) {
                Image(systemName: ek.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(cgColor: ek.calendar.cgColor))
                VStack(alignment: .leading, spacing: 3) {
                    Text(ek.title ?? "Untitled")
                        .font(.system(size: 15, weight: .heavy))
                        .strikethrough(ek.isCompleted)
                        .foregroundStyle(ek.isCompleted ? P.textDim : P.text)
                    if let due = linkedReminderDue(ek) {
                        Text(due)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(P.textDim)
                    }
                }
                Spacer()
                Image(systemName: "checklist")
                    .font(.system(size: 11))
                    .foregroundStyle(P.textMuted)
            }
            .padding(.vertical, 10)
        }

        private func linkedReminderDue(_ ek: EKReminder) -> String? {
            guard let comps = ek.dueDateComponents,
                  let date = Calendar.current.date(from: comps) else { return nil }
            let f = DateFormatter()
            if Calendar.current.isDateInToday(date) {
                f.dateFormat = "'Today' h:mm a"
            } else if Calendar.current.isDateInTomorrow(date) {
                f.dateFormat = "'Tmrw' h:mm a"
            } else {
                f.dateFormat = "MMM d · h:mm a"
            }
            return f.string(from: date)
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
            // Mirror to the user's linked Apple Reminders list, same
            // as AddReminderView. No-op if no list is linked.
            ReminderLinkService.shared.mirror(it)
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
                    }.buttonStyle(.row)
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
                    .buttonStyle(.row)
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
            .buttonStyle(.row)
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
                                        // Priority badge
                                        if t.reminderPriority > 0 {
                                            Text(String(repeating: "!", count: Int(t.reminderPriority)))
                                                .font(.system(size: 11, weight: .black))
                                                .foregroundStyle(reminderPriorityColor(t.reminderPriority))
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10, weight: .heavy))
                                            .foregroundStyle(P.textMuted)
                                    }
                                    Text(t.task)
                                        .font(.system(size: 14, weight: .heavy))
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(4)
                                        .foregroundStyle(P.text)
                                    if let img = ReminderPhotoStore.image(for: t.uid) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 70)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    Spacer(minLength: 0)
                                    // Per-reminder 🔥 streak — only renders
                                    // when the reminder has a cadence
                                    // supporting streaks (daily/weekly/monthly/
                                    // yearly) AND the user has completed at
                                    // least once on schedule.
                                    let streak = ReminderStreak.current(for: t.uid)
                                    if streak > 0 {
                                        HStack(spacing: 4) {
                                            Text("🔥\(streak)")
                                                .font(.system(size: 11, weight: .heavy))
                                                .foregroundStyle(P.peach)
                                            let best = ReminderStreak.best(for: t.uid)
                                            if best > streak {
                                                Text("· best \(best)")
                                                    .font(.system(size: 9, weight: .heavy))
                                                    .foregroundStyle(P.textMuted)
                                            }
                                        }
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Capsule().fill(P.peach.opacity(0.15)))
                                    }
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                                .background(RoundedRectangle(cornerRadius: 26).fill(P.surface))
                                .overlay(alignment: .leading) {
                                    // Color-tag stripe along the left
                                    // edge — invisible when no tag set.
                                    let tag = ReminderColorTagStore.tag(for: t.uid)
                                    if tag != .none {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(tag.swiftUIColor)
                                            .frame(width: 4)
                                            .padding(.vertical, 10)
                                            .padding(.leading, 4)
                                    }
                                }
                                .overlay(RoundedRectangle(cornerRadius: 26).stroke(P.border, lineWidth: 1.5))
                            }
                            .buttonStyle(.row)
                            .contextMenu {
                                Button {
                                    ReminderOrderStore.pinToTop(t.uid)
                                } label: {
                                    Label("Pin to top", systemImage: "arrow.up.to.line.compact")
                                }
                                Button {
                                    ReminderOrderStore.sendToBottom(t.uid)
                                } label: {
                                    Label("Send to bottom", systemImage: "arrow.down.to.line.compact")
                                }
                                Button {
                                    duplicateReminder(t)
                                } label: {
                                    Label("Duplicate", systemImage: "doc.on.doc")
                                }
                            }
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
        @State private var linkedEvents: [EKEvent] = []
        @State private var newEventTitle: String = ""
        @State private var selectedDay: Date? = nil   // nil = show all
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyEvent.startDate, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil")) private var allEvents: FetchedResults<FamilyEvent>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil")) private var members: FetchedResults<FamilyMember>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil")) private var households: FetchedResults<Household>
        @AppStorage("userName") private var userName: String = ""
        @AppStorage("meUid") private var meUid: String = ""
        private var dark: Bool { darkOverride ?? (sys == .dark) }
        @AppStorage("paletteName") private var paletteName: String = "vivid"
        private var P: Palette { Palette.resolveForPreview(paletteName, dark: dark) }
        private var canAddEvents: Bool {
            FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)?.canCreateEvents ?? true
        }
        public init() {}

        // MARK: – Computed lists

        private var upcoming: [FamilyEvent] {
            allEvents.filter { $0.startDate >= Calendar.current.startOfDay(for: Date()) }
                .sorted { $0.startDate < $1.startDate }
        }
        private var past: [FamilyEvent] {
            allEvents.filter { $0.startDate < Calendar.current.startOfDay(for: Date()) }
                .sorted { $0.startDate > $1.startDate }
        }
        private var nextEvent: FamilyEvent? { upcoming.first }

        private func isSameDay(_ a: Date, _ b: Date) -> Bool {
            Calendar.current.isDate(a, inSameDayAs: b)
        }

        /// Events to show — filtered by selected day strip if one is picked.
        private var filteredUpcoming: [FamilyEvent] {
            guard let day = selectedDay else { return upcoming }
            return upcoming.filter { isSameDay($0.startDate, day) }
        }

        private var todayEvents: [FamilyEvent] { upcoming.filter { Calendar.current.isDateInToday($0.startDate) } }

        /// Next 7 calendar days starting today for the day strip.
        private var stripDays: [Date] {
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            // Always start the strip on the Saturday of the current week.
            // weekday: 1=Sun 2=Mon 3=Tue 4=Wed 5=Thu 6=Fri 7=Sat
            // daysBack to most-recent Saturday: weekday % 7
            // Sat(7)->0  Sun(1)->1  Mon(2)->2  ...  Fri(6)->6
            let weekday = cal.component(.weekday, from: today)
            let daysBack = weekday % 7
            let saturday = cal.date(byAdding: .day, value: -daysBack, to: today) ?? today
            return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: saturday) }
        }

        private func eventColor(_ e: FamilyEvent) -> Color {
            if Calendar.current.isDateInToday(e.startDate) { return P.peach }
            let cal = Calendar.current
            let weekOut = cal.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            if e.startDate <= weekOut { return P.butter }
            return P.sky
        }

        // MARK: – Body

        public var body: some View {
            ZStack {
                P.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                    ScrollView { content }
                        .scrollIndicators(.hidden)
                        .refreshable {
                            try? await Task.sleep(for: .seconds(2))
                            modelContext.refreshAllObjects()
                        }
                }
            }
            .foregroundStyle(P.text)
            .preferredColorScheme(dark ? .dark : .light)
            .sheet(isPresented: $showAdd) { AddEventView() }
            .sheet(item: $editingEvent) { event in AddEventView(editing: event) }
            .swipeToDismiss()
            .onAppear { refreshLinkedEvents() }
            .onChange(of: allEvents.count) { _, _ in refreshLinkedEvents() }
        }

        private func refreshLinkedEvents() {
            let svc = CalendarLinkService.shared
            let start = Calendar.current.startOfDay(for: Date())
            let end = Calendar.current.date(byAdding: .day, value: 30, to: start) ?? start
            linkedEvents = svc.fetchEvents(from: start, to: end).filter { !($0.notes ?? "").hasPrefix("Casalist:") }
        }

        private func addQuickEvent() {
            let name = newEventTitle.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }
            let myName = FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)?.name ?? userName
            let ev = FamilyEvent(context: modelContext)
            ev.uid = UUID()
            ev.title = name
            ev.startDate = Calendar.current.startOfDay(for: Date())
            ev.isAllDay = true
            ev.location = ""
            ev.attendees = ""
            ev.notes = ""
            ev.repeatKind = ""
            ev.createdBy = myName.trimmingCharacters(in: .whitespaces)
            ev.createdAt = Date()
            if let h = households.preferredTarget {
                modelContext.assign(ev, toStoreOf: h)
                ev.household = h
            }
            try? modelContext.save()
            Task { await NotificationsManager.scheduleEvent(for: ev) }
            CalendarLinkService.shared.mirror(ev)
            newEventTitle = ""
        }

        // MARK: – Top bar

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
                if canAddEvents {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus").font(.system(size: 19, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(P.peach))
                            .shadow(color: P.peach.opacity(0.4), radius: 8, y: 4)
                    }
                }
            }.padding(.horizontal, 16).padding(.bottom, 12)
        }

        // MARK: – Content

        private var content: some View {
            VStack(alignment: .leading, spacing: 14) {
                hero
                dayStrip
                if canAddEvents { quickAddRow }
                if allEvents.isEmpty && linkedEvents.isEmpty {
                    emptyCard
                } else {
                    eventList
                }
                if !linkedEvents.isEmpty { linkedSection }
            }.padding(.horizontal, 20).padding(.bottom, 28)
        }

        // MARK: – Hero

        private var hero: some View {
            HStack(spacing: 16) {
                // Month/day badge
                VStack(spacing: 0) {
                    Text(Date().formatted(.dateTime.month(.abbreviated)).uppercased())
                        .font(.system(size: 10, weight: .heavy)).tracking(1).opacity(0.85)
                    Text(Date().formatted(.dateTime.day()))
                        .font(.system(size: 34, weight: .heavy))
                    Text(Date().formatted(.dateTime.weekday(.wide)).uppercased())
                        .font(.system(size: 8, weight: .heavy)).tracking(0.8).opacity(0.85)
                }
                .foregroundStyle(.white)
                .frame(width: 76, height: 76)
                .background(Circle().fill(Color.white.opacity(0.2)))

                VStack(alignment: .leading, spacing: 4) {
                    Text("SCHEDULE").font(.system(size: 11, weight: .heavy)).tracking(0.8).opacity(0.85)
                    Text("\(upcoming.count) upcoming").font(.system(size: 22, weight: .heavy))
                    if let next = nextEvent {
                        Text("Next: \(next.title)").font(.system(size: 12, weight: .semibold)).opacity(0.85).lineLimit(1)
                    } else {
                        Text("Nothing scheduled").font(.system(size: 12, weight: .semibold)).opacity(0.85)
                    }
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white).padding(20)
            .background(P.sky)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }

        // MARK: – Day strip

        private var dayStrip: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // "All" pill
                    let allActive = selectedDay == nil
                    Button { selectedDay = nil } label: {
                        VStack(spacing: 2) {
                            Text("ALL").font(.system(size: 9, weight: .heavy)).tracking(0.5)
                            Image(systemName: "calendar").font(.system(size: 16, weight: .heavy))
                        }
                        .foregroundStyle(allActive ? .white : P.textDim)
                        .frame(width: 48, height: 56)
                        .background(RoundedRectangle(cornerRadius: 14).fill(allActive ? P.sky : P.surfaceAlt))
                    }.buttonStyle(.row)

                    ForEach(stripDays, id: \.self) { day in
                        let isSelected = selectedDay.map { isSameDay($0, day) } ?? false
                        let isToday = Calendar.current.isDateInToday(day)
                        let count = upcoming.filter { isSameDay($0.startDate, day) }.count
                        Button { selectedDay = isSelected ? nil : day } label: {
                            VStack(spacing: 2) {
                                Text(day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                                    .font(.system(size: 9, weight: .heavy)).tracking(0.5)
                                Text(day.formatted(.dateTime.day()))
                                    .font(.system(size: 15, weight: .heavy))
                                if count > 0 {
                                    Circle().fill(isSelected ? .white : P.peach).frame(width: 5, height: 5)
                                } else {
                                    Circle().fill(Color.clear).frame(width: 5, height: 5)
                                }
                            }
                            .foregroundStyle(isSelected ? .white : (isToday ? P.sky : P.textDim))
                            .frame(width: 48, height: 56)
                            .background(RoundedRectangle(cornerRadius: 14)
                                .fill(isSelected ? P.sky : (isToday ? P.sky.opacity(0.15) : P.surfaceAlt)))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isToday && !isSelected ? P.sky : Color.clear, lineWidth: 1.5))
                        }.buttonStyle(.row)
                    }
                }
            }
        }

        // MARK: – Quick-add

        private var quickAddRow: some View {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle").font(.system(size: 18)).foregroundStyle(P.textDim)
                TextField("Add an event...", text: $newEventTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .submitLabel(.done)
                    .onSubmit(addQuickEvent)
                Button { addQuickEvent() } label: {
                    Image(systemName: "arrow.up").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white)
                        .frame(width: 32, height: 32).background(Circle().fill(P.peach))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 4).padding(.trailing, 4)
            .background(Capsule().fill(P.surface))
            .overlay(Capsule().stroke(P.border, lineWidth: 1.5))
        }

        // MARK: – Event list

        private var eventList: some View {
            VStack(alignment: .leading, spacing: 8) {
                if let day = selectedDay {
                    let label = Calendar.current.isDateInToday(day) ? "TODAY" : day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()).uppercased()
                    HStack {
                        Text(label).font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                        Spacer()
                        Text("\(filteredUpcoming.count)").font(.system(size: 11, weight: .heavy)).foregroundStyle(P.textMuted).padding(.trailing, 4)
                    }
                }
                if filteredUpcoming.isEmpty && selectedDay != nil {
                    Text("No events on this day").font(.system(size: 13, weight: .semibold)).foregroundStyle(P.textDim)
                        .frame(maxWidth: .infinity).padding(20)
                        .background(RoundedRectangle(cornerRadius: 16).fill(P.surface))
                } else {
                    VStack(spacing: 10) {
                        ForEach(filteredUpcoming) { e in
                            eventCard(e, isPast: false)
                        }
                        if selectedDay == nil {
                            ForEach(past.prefix(5).map { $0 }) { e in
                                eventCard(e, isPast: true)
                            }
                        }
                    }
                }
            }
        }

        private func eventCard(_ e: FamilyEvent, isPast: Bool) -> some View {
            let color = isPast ? P.textMuted : eventColor(e)
            return Button { editingEvent = e } label: {
                HStack(spacing: 0) {
                    // Left color stripe
                    RoundedRectangle(cornerRadius: 3).fill(color)
                        .frame(width: 5).padding(.vertical, 10)
                    HStack(spacing: 12) {
                        // Date badge
                        VStack(spacing: 1) {
                            Text(dayLabel(e.startDate)).font(.system(size: 18, weight: .heavy)).foregroundStyle(color)
                            Text(monthLabel(e.startDate)).font(.system(size: 9, weight: .heavy)).tracking(0.5).foregroundStyle(P.textDim)
                        }
                        .frame(width: 40)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.12)))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(e.title)
                                .font(.system(size: 15, weight: .heavy))
                                .foregroundStyle(isPast ? P.textDim : P.text)
                                .strikethrough(isPast)
                                .lineLimit(2)
                            HStack(spacing: 6) {
                                Image(systemName: "clock").font(.system(size: 9, weight: .semibold)).foregroundStyle(P.textDim)
                                Text(timeLabel(e)).font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textDim)
                                if !e.location.isEmpty {
                                    Text("·").foregroundStyle(P.textMuted)
                                    Image(systemName: "mappin").font(.system(size: 9)).foregroundStyle(P.textMuted)
                                    Text(e.location).font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textDim).lineLimit(1)
                                }
                            }
                            if !e.attendees.isEmpty {
                                Text(e.attendees).font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted).lineLimit(1)
                            }
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .heavy)).foregroundStyle(P.textMuted)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                }
                .background(P.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(P.border, lineWidth: 1.5))
                .opacity(isPast ? 0.6 : 1)
            }.buttonStyle(.row)
        }

        // MARK: – Apple Calendar section

        private var linkedSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("FROM APPLE CALENDAR").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                    Spacer()
                    Text("\(linkedEvents.count)").font(.system(size: 11, weight: .heavy)).foregroundStyle(P.textMuted).padding(.trailing, 4)
                }
                VStack(spacing: 10) {
                    ForEach(linkedEvents, id: \.eventIdentifier) { ek in
                        linkedEventCard(ek)
                    }
                }
            }
        }

        private func linkedEventCard(_ ek: EKEvent) -> some View {
            let cal = Color(cgColor: ek.calendar.cgColor)
            return HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3).fill(cal).frame(width: 5).padding(.vertical, 10)
                HStack(spacing: 12) {
                    VStack(spacing: 1) {
                        Text(dayLabel(ek.startDate)).font(.system(size: 18, weight: .heavy)).foregroundStyle(cal)
                        Text(monthLabel(ek.startDate)).font(.system(size: 9, weight: .heavy)).tracking(0.5).foregroundStyle(P.textDim)
                    }
                    .frame(width: 40).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 10).fill(cal.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(ek.title ?? "Untitled").font(.system(size: 15, weight: .heavy)).lineLimit(2)
                        Text(linkedSubtitle(ek)).font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textDim)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "calendar").font(.system(size: 11)).foregroundStyle(P.textMuted)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
            .background(P.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(P.border, lineWidth: 1.5))
        }

        private func linkedSubtitle(_ ek: EKEvent) -> String {
            let f = DateFormatter()
            f.dateFormat = ek.isAllDay ? "EEE MMM d 'all day'" : "EEE MMM d 'at' h:mm a"
            return f.string(from: ek.startDate)
        }

        private var emptyCard: some View {
            Button { if canAddEvents { showAdd = true } } label: {
                VStack(spacing: 8) {
                    Text("📅").font(.system(size: 36))
                    Text("No events scheduled").font(.system(size: 14, weight: .heavy))
                    Text(canAddEvents ? "Tap + to add a family event" : "Ask a parent to add events").font(.system(size: 11, weight: .semibold)).opacity(0.7)
                }
                .foregroundStyle(P.text).frame(maxWidth: .infinity).padding(24)
                .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
            }.buttonStyle(.row)
        }

        // MARK: – Helpers

        private func dayLabel(_ d: Date) -> String { d.formatted(.dateTime.day()) }
        private func monthLabel(_ d: Date) -> String { d.formatted(.dateTime.month(.abbreviated)).uppercased() }
        private func timeLabel(_ e: FamilyEvent) -> String {
            if e.isAllDay { return "All day" }
            return e.startDate.formatted(.dateTime.hour().minute())
        }
    }
}

extension CasalistCottage {
    // MARK: – Kids (starfield)
    /// Full-screen, simplified UI shown to FamilyMembers with role == .kid.
    public struct Kids: View {
        @Environment(\.managedObjectContext) private var moc
        @AppStorage("userName") private var userName: String = ""
        @AppStorage("meUid") private var meUid: String = ""
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil")) private var members: FetchedResults<FamilyMember>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.dueDate, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil")) private var allTodos: FetchedResults<TaskItem>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyGoal.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil")) private var goals: FetchedResults<FamilyGoal>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil")) private var households: FetchedResults<Household>
        @State private var redeemTarget: FamilyGoal? = nil
        @State private var celebrate: Bool = false
        @State private var confettiFlying: Bool = false
        @State private var celebrateLabel: String = ""
        @State private var showSuggest: Bool = false
        @AppStorage("starfieldTheme") private var themeName: String = "space"
        @AppStorage("starfieldTier") private var tier: String = "tween"
        @State private var completingUids: Set<String> = []
        @State private var showSettings: Bool = false
        @State private var showPersonalCard: Bool = false

        private var P: Palette {
            switch themeName {
            case "ocean":    return Palette.starfieldOcean()
            case "garden":   return Palette.starfieldGarden()
            case "orchid": return Palette.starfieldOrchid()
            default:         return Palette.starfield()
            }
        }
        private var isLittle: Bool { tier == "little" }

        private var me: FamilyMember? {
            FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)
        }
        private var myName: String { me?.name ?? userName }
        private var myPoints: Int { Int(me?.points ?? 0) }

        private var myChores: [TaskItem] {
            let lc = myName.lowercased()
            return allTodos.filter { t in
                !t.isCompleted
                && t.points > 0
                && (t.assignee ?? "").lowercased() == lc
                && !["reminders", "groceries", "maintenance"].contains(t.category.lowercased())
            }
        }
        private var myActiveGoals: [FamilyGoal] {
            // Includes both approved (ownerName == me) AND pending (ownerName
            // == "PENDING:me") so the kid sees their own suggestion sitting
            // in the shelf with a "waiting for parent" badge.
            let lc = myName.lowercased()
            return goals.filter { !$0.isRedeemed && GoalApproval.realOwnerName($0).lowercased() == lc && $0.isLive }
                .sorted { $0.targetPoints < $1.targetPoints }
        }
        private var myRedeemedGoals: [FamilyGoal] {
            let lc = myName.lowercased()
            return goals.filter { $0.isRedeemed && GoalApproval.realOwnerName($0).lowercased() == lc }
                .sorted { ($0.redeemedAt ?? .distantPast) > ($1.redeemedAt ?? .distantPast) }
        }
        private var nextGoal: FamilyGoal? {
            myActiveGoals.first(where: { Int($0.targetPoints) > myPoints }) ?? myActiveGoals.last
        }

        public init() {}

        public var body: some View {
            ZStack {
                LinearGradient(colors: [P.bg, P.surfaceHi], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        header
                        choresSection
                        if !isLittle { statsCard }
                        pointsSection
                        if !isLittle && !familyPeek.isEmpty { familyPeekSection }
                        winsSection
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 18).padding(.top, 8)
                }
                .scrollIndicators(.hidden)
                if celebrate { celebrateOverlay }
            }
            .foregroundStyle(P.text)
            .preferredColorScheme(.dark)
            .sheet(item: $redeemTarget) { g in redeemSheet(g) }
            .sheet(isPresented: $showSuggest) { suggestSheet }
            .sheet(isPresented: $showSettings) { settingsSheet }
            .fullScreenCover(isPresented: $showPersonalCard) { PersonalCardView() }
        }

        // MARK: – Suggest-a-goal (kid)

        @State private var suggestLabel: String = ""
        @State private var suggestNote: String = ""

        private var suggestSheet: some View {
            NavigationStack {
                ZStack {
                    P.bg.ignoresSafeArea()
                    ScrollView {
                        VStack(spacing: 18) {
                            Spacer().frame(height: 8)
                            Text("🎁").font(.system(size: 56))
                            Text("Ask for a reward").font(.system(size: 22, weight: .heavy))
                            Text("Tell a parent what you'd like. They'll decide if yes — and how many points it should cost.")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(P.textDim)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("What do you want?").font(.system(size: 11, weight: .heavy)).foregroundStyle(P.textDim)
                                TextField("e.g. Sleepover with Sam", text: $suggestLabel)
                                    .textInputAutocapitalization(.sentences)
                                    .padding(12)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(P.surface))
                                    .foregroundStyle(P.text)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Why? (optional)").font(.system(size: 11, weight: .heavy)).foregroundStyle(P.textDim)
                                    Spacer()
                                    Text("\(suggestNote.count)/120")
                                        .font(.system(size: 10, weight: .heavy))
                                        .foregroundStyle(P.textMuted)
                                }
                                TextField("Make your case…", text: $suggestNote, axis: .vertical)
                                    .lineLimit(2...4)
                                    .textInputAutocapitalization(.sentences)
                                    .padding(12)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(P.surface))
                                    .foregroundStyle(P.text)
                                    .onChange(of: suggestNote) { _, new in
                                        if new.count > 120 { suggestNote = String(new.prefix(120)) }
                                    }
                            }

                            HStack(spacing: 12) {
                                Button("Cancel") {
                                    suggestLabel = ""; suggestNote = ""
                                    showSuggest = false
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Capsule().fill(P.surfaceAlt)).foregroundStyle(P.text)

                                Button {
                                    submitSuggestion()
                                } label: {
                                    Text("Send to parent").font(.system(size: 15, weight: .heavy))
                                        .foregroundStyle(Color(rgb: 0x1B1E4A))
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Capsule().fill(P.butter))
                                .disabled(suggestLabel.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                            .padding(.horizontal, 4)
                            Spacer(minLength: 30)
                        }
                        .padding(20)
                    }
                }
                .foregroundStyle(P.text)
            }
            .presentationDetents([.medium, .large])
        }

        private func submitSuggestion() {
            let trimmed = suggestLabel.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            let g = FamilyGoal(context: moc)
            g.label = trimmed
            // targetPoints = 0 signals "parent hasn't set a price yet". The
            // approval flow will set the real number.
            g.targetPoints = 0
            g.note = suggestNote.trimmingCharacters(in: .whitespaces)
            g.ownerName = GoalApproval.makePendingOwnerName(myName)
            if let h = households.preferredTarget {
                moc.assign(g, toStoreOf: h)
                g.household = h
            }
            try? moc.save()
            suggestLabel = ""
            suggestNote = ""
            showSuggest = false
            triggerCelebrate("Sent to parent ✨")
        }

        private var header: some View {
            HStack(spacing: 14) {
                Button { showPersonalCard = true } label: {
                    if let m = me {
                        CLAvatar(m.asCLMember, size: 56)
                    } else {
                        Circle().fill(P.peach).frame(width: 56, height: 56)
                    }
                }
                .buttonStyle(.row)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hi, \(myName) 👋").font(.system(size: 22, weight: .heavy))
                    Text("Let's earn some points").font(.system(size: 12, weight: .semibold)).foregroundStyle(P.textDim)
                }
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(P.textMuted)
                }
                .buttonStyle(.row)
            }
            .padding(.top, 8)
        }

        private var choresSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("MY STUFF TO DO", emoji: "✨", color: P.butter)
                if myChores.isEmpty {
                    emptyCard("🎉", title: "All caught up!", subtitle: "Nothing to do right now. Go play.", tint: P.mint)
                } else if isLittle {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(myChores, id: \.uid) { littleChoreTile($0) }
                    }
                } else {
                    VStack(spacing: 10) { ForEach(myChores, id: \.uid) { choreTile($0) } }
                }
            }
        }

        private func choreTile(_ t: TaskItem) -> some View {
            let overdue: Bool = {
                guard let d = t.dueDate else { return false }
                return d < Date().addingTimeInterval(-3600) && !Calendar.current.isDateInToday(d)
            }()
            let dueToday = t.dueDate.map { Calendar.current.isDateInToday($0) } ?? false
            let completing = completingUids.contains(t.uid)
            return HStack(spacing: 14) {
                Button { completeChore(t) } label: {
                    ZStack {
                        if completing {
                            Circle()
                                .fill(P.mint)
                                .frame(width: 52, height: 52)
                            Image(systemName: "checkmark")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            // Empty outlined circle in the resting state — the kid
                            // can clearly tell the chore isn't done yet.
                            Circle()
                                .stroke(P.mint, lineWidth: 3)
                                .frame(width: 52, height: 52)
                            // Faint inner mint fill so it still feels tappable.
                            Circle()
                                .fill(P.mint.opacity(0.12))
                                .frame(width: 46, height: 46)
                        }
                    }
                }.buttonStyle(.row)
                VStack(alignment: .leading, spacing: 4) {
                    Text(t.task).font(.system(size: 17, weight: .heavy)).lineLimit(2)
                    if dueToday {
                        Text("Today").font(.system(size: 11, weight: .heavy))
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Capsule().fill(P.butter)).foregroundStyle(Color(rgb: 0x1B1E4A))
                    } else if overdue {
                        Text("Overdue").font(.system(size: 11, weight: .heavy))
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Capsule().fill(P.peach)).foregroundStyle(.white)
                    }
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("\(t.points)").font(.system(size: 22, weight: .heavy)).foregroundStyle(P.butter)
                    Text("pts").font(.system(size: 9, weight: .heavy)).foregroundStyle(P.textDim)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
            .scaleEffect(completing ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: completing)
        }

        private func completeChore(_ t: TaskItem) {
            let pts = Int(t.points)
            completingUids.insert(t.uid)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                FamilyPoints.toggle(t, in: members)
                try? moc.save()
                completingUids.remove(t.uid)
                if pts > 0 { triggerCelebrate("+\(pts) pts!") }
            }
        }

        /// Show the overlay, fire haptics, then animate confetti outward on the
        /// next runloop so the view exists long enough to animate FROM its
        /// initial state.
        private func triggerCelebrate(_ label: String) {
            celebrateLabel = label
            confettiFlying = false
            celebrate = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeOut(duration: 1.2)) {
                    confettiFlying = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                celebrate = false
                confettiFlying = false
            }
        }

        private var pointsSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("MY POINTS", emoji: "⭐", color: P.sky)
                ZStack {
                    RoundedRectangle(cornerRadius: 28).fill(
                        LinearGradient(colors: [P.lavender, P.sky], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(myPoints)").font(.system(size: 56, weight: .heavy)).foregroundStyle(.white)
                            Text("points").font(.system(size: 13, weight: .heavy)).foregroundStyle(.white.opacity(0.85))
                        }
                        Spacer()
                        if let g = nextGoal { progressRing(for: g) }
                    }
                    .padding(22)
                }
                if myActiveGoals.isEmpty {
                    emptyCard("🎯", title: "No goals yet", subtitle: "Ask a parent to set a goal — or suggest your own.", tint: P.peach)
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(myActiveGoals.prefix(5)), id: \.uid) { g in
                            goalCard(g)
                        }
                    }
                }
                Button { showSuggest = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill").font(.system(size: 13, weight: .heavy))
                        Text("Suggest a goal").font(.system(size: 14, weight: .heavy))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Capsule().fill(P.surfaceAlt))
                    .foregroundStyle(P.text)
                }.buttonStyle(.row)
            }
        }

        private func progressRing(for g: FamilyGoal) -> some View {
            let progress = min(1.0, Double(myPoints) / Double(max(Int(g.targetPoints), 1)))
            return ZStack {
                Circle().stroke(Color.white.opacity(0.25), lineWidth: 8).frame(width: 84, height: 84)
                Circle().trim(from: 0, to: progress)
                    .stroke(P.butter, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 84, height: 84).rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int(progress * 100))%").font(.system(size: 16, weight: .heavy)).foregroundStyle(.white)
                    Text("of \(g.targetPoints)").font(.system(size: 9, weight: .heavy)).foregroundStyle(.white.opacity(0.85))
                }
            }
        }

        private func goalCard(_ g: FamilyGoal) -> some View {
            let target = Int(g.targetPoints)
            let canRedeem = target > 0 && myPoints >= target
            let progress = min(1.0, Double(myPoints) / Double(max(target, 1)))
            let remaining = max(0, target - myPoints)
            let isPending = GoalApproval.isPending(g)
            let needsPrice = isPending && target == 0
            return VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    Text(needsPrice ? "💬"
                         : isPending ? "⏳"
                         : canRedeem ? "🎁"
                         : "🔒").font(.system(size: 26))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(g.label).font(.system(size: 15, weight: .heavy)).lineLimit(1)
                        Text(needsPrice
                             ? "Sent — waiting for a parent to set the price"
                             : isPending
                                ? "Waiting for a parent to approve · \(target) pts"
                                : canRedeem
                                    ? "Ready to redeem · \(target) pts"
                                    : "Need \(remaining) more pts")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(needsPrice ? P.sky : isPending ? P.sky : canRedeem ? P.butter : P.textDim)
                    }
                    Spacer()
                    if canRedeem && !isPending {
                        Button { redeemTarget = g } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "gift.fill").font(.system(size: 12, weight: .heavy))
                                Text("Redeem").font(.system(size: 13, weight: .heavy))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(Capsule().fill(P.butter)).foregroundStyle(Color(rgb: 0x1B1E4A))
                        }.buttonStyle(.row)
                    }
                }
                if !isPending && target > 0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(P.surfaceHi).frame(height: 8)
                            Capsule()
                                .fill(canRedeem ? P.butter : P.mint)
                                .frame(width: max(8, geo.size.width * CGFloat(progress)), height: 8)
                        }
                    }.frame(height: 8)
                    HStack {
                        Text("\(myPoints) / \(target) pts")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(P.textMuted)
                        Spacer()
                        if !canRedeem {
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(P.textMuted)
                        }
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
            .overlay(RoundedRectangle(cornerRadius: 22)
                .stroke(isPending ? P.sky.opacity(0.6)
                        : (canRedeem ? P.butter.opacity(0.6) : P.border),
                        lineWidth: 1.5))
            .opacity(isPending ? 0.85 : 1.0)
        }

        private func redeemSheet(_ g: FamilyGoal) -> some View {
            NavigationStack {
                ZStack {
                    P.bg.ignoresSafeArea()
                    VStack(spacing: 18) {
                        Spacer().frame(height: 8)
                        Image(systemName: "gift.fill").font(.system(size: 50)).foregroundStyle(P.butter)
                        Text("Redeem \(g.label)?").font(.system(size: 22, weight: .heavy)).multilineTextAlignment(.center)
                        Text("\(g.targetPoints) pts will be spent.")
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(P.textDim)
                        HStack(spacing: 12) {
                            Button("Not yet") { redeemTarget = nil }
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Capsule().fill(P.surfaceAlt)).foregroundStyle(P.text)
                            Button {
                                if let mine = me { mine.points = max(0, mine.points - g.targetPoints) }
                                g.isRedeemed = true
                                g.redeemedAt = Date()
                                try? moc.save()
                                redeemTarget = nil
                                triggerCelebrate("🎉 Redeemed!")
                            } label: {
                                Text("Redeem").font(.system(size: 15, weight: .heavy)).foregroundStyle(Color(rgb: 0x1B1E4A))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Capsule().fill(P.butter))
                        }
                        .padding(.horizontal, 20)
                        Spacer()
                    }
                    .padding(20)
                }
                .foregroundStyle(P.text)
            }
            .presentationDetents([.medium])
        }

        // MARK: – Family peek (Phase 3)

        /// Other family members + their nearest goal, so the kid sees what
        /// the rest of the family is working toward. Subtle, non-competitive.
        private struct FamilyPeekEntry: Identifiable {
            let id: String
            let member: FamilyMember
            let goalLabel: String?
            let goalProgress: Double?   // 0...1
            let pointsToGo: Int?
        }

        private var familyPeek: [FamilyPeekEntry] {
            let lc = myName.lowercased()
            return members.filter {
                $0.deletedAt == nil
                && $0.isKid
                && $0.name.lowercased() != lc
                && !$0.name.trimmingCharacters(in: .whitespaces).isEmpty
            }.prefix(4).map { m in
                // Find their nearest unredeemed approved goal above their points,
                // or fall back to their highest unredeemed.
                let theirGoals = goals.filter { g in
                    !g.isRedeemed
                    && g.isLive
                    && !GoalApproval.isPending(g)
                    && g.ownerName.lowercased() == m.name.lowercased()
                }.sorted { $0.targetPoints < $1.targetPoints }
                let nearest = theirGoals.first(where: { Int($0.targetPoints) > Int(m.points) }) ?? theirGoals.last
                if let g = nearest {
                    let target = Int(g.targetPoints)
                    let progress = min(1.0, Double(m.points) / Double(max(target, 1)))
                    let toGo = max(0, target - Int(m.points))
                    return FamilyPeekEntry(id: m.uid.uuidString, member: m, goalLabel: g.label, goalProgress: progress, pointsToGo: toGo)
                } else {
                    return FamilyPeekEntry(id: m.uid.uuidString, member: m, goalLabel: nil, goalProgress: nil, pointsToGo: nil)
                }
            }
        }

        @ViewBuilder
        private var familyPeekSection: some View {
            let entries = familyPeek
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("MY FAMILY", emoji: "🌟", color: P.mint)
                if entries.isEmpty {
                    emptyCard("👯", title: "Just you for now", subtitle: "When other kids join the family, you'll see what they're working toward here.", tint: P.mint)
                } else {
                    VStack(spacing: 8) {
                        ForEach(entries) { e in familyPeekRow(e) }
                    }
                }
            }
        }

        private func familyPeekRow(_ e: FamilyPeekEntry) -> some View {
            HStack(spacing: 12) {
                CLAvatar(e.member.asCLMember, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.member.name).font(.system(size: 14, weight: .heavy))
                    if let label = e.goalLabel, let toGo = e.pointsToGo {
                        Text(toGo == 0
                             ? "Ready to redeem · \(label)"
                             : "\(toGo) pts from \(label)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(P.textDim).lineLimit(1)
                    } else {
                        Text("\(e.member.points) pts").font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textDim)
                    }
                }
                Spacer()
                if let progress = e.goalProgress {
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.15), lineWidth: 4).frame(width: 32, height: 32)
                        Circle().trim(from: 0, to: progress)
                            .stroke(P.mint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 32, height: 32).rotationEffect(.degrees(-90))
                    }
                } else {
                    Text("\(e.member.points)").font(.system(size: 14, weight: .heavy)).foregroundStyle(P.butter)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 18).fill(P.surface))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(P.border, lineWidth: 1.5))
        }

        /// A unified entry in My Wins — either a chore completion (🏆) or a
        /// goal redemption (🎁). Sorted by date desc; cap at 8.
        private enum WinEntry: Identifiable {
            case chore(TaskItem)
            case redemption(FamilyGoal)
            var id: String {
                switch self {
                case .chore(let t): return "c-\(t.uid)-\(t.completedAt?.timeIntervalSince1970 ?? 0)"
                case .redemption(let g): return "r-\(g.uid)"
                }
            }
            var when: Date {
                switch self {
                case .chore(let t): return t.completedAt ?? t.createdAt
                case .redemption(let g): return g.redeemedAt ?? g.createdAt
                }
            }
        }

        private var myWinEntries: [WinEntry] {
            let lc = myName.lowercased()
            let chores: [WinEntry] = allTodos.filter { t in
                (t.assignee ?? "").lowercased() == lc
                && t.points > 0
                && t.completedAt != nil
            }.map { .chore($0) }
            let redemptions: [WinEntry] = goals.filter { g in
                g.isRedeemed && g.ownerName.lowercased() == lc
            }.map { .redemption($0) }
            return (chores + redemptions).sorted { $0.when > $1.when }
        }

        private var winsSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("MY WINS", emoji: "🏆", color: P.peach)
                let entries = myWinEntries
                if entries.isEmpty {
                    emptyCard("🏅", title: "No wins yet", subtitle: "Check off a chore to start your win streak.", tint: P.lavender)
                } else {
                    VStack(spacing: 8) {
                        ForEach(entries.prefix(8)) { winRow($0) }
                    }
                }
            }
        }

        @ViewBuilder
        private func winRow(_ entry: WinEntry) -> some View {
            switch entry {
            case .chore(let t):
                winRowCard(emoji: "🏆", title: t.task, when: t.completedAt, pointsLabel: "+\(t.points) pts", pointsColor: P.butter)
            case .redemption(let g):
                winRowCard(emoji: "🎁", title: g.label, when: g.redeemedAt, pointsLabel: "Redeemed · \(g.targetPoints) pts", pointsColor: P.peach)
            }
        }

        private func winRowCard(emoji: String, title: String, when: Date?, pointsLabel: String, pointsColor: Color) -> some View {
            HStack(spacing: 12) {
                Text(emoji).font(.system(size: 24))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .heavy)).lineLimit(1)
                    if let d = when {
                        Text(d, style: .relative).font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textDim)
                    }
                }
                Spacer()
                Text(pointsLabel).font(.system(size: 12, weight: .heavy)).foregroundStyle(pointsColor)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 18).fill(P.surface))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(P.border, lineWidth: 1.5))
        }

        // MARK: – Little-mode tile (2-column grid)

        private func littleChoreTile(_ t: TaskItem) -> some View {
            let completing = completingUids.contains(t.uid)
            return Button { completeChore(t) } label: {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(completing ? P.mint : P.mint.opacity(0.2))
                            .frame(width: 70, height: 70)
                        if completing {
                            Image(systemName: "checkmark")
                                .font(.system(size: 30, weight: .heavy))
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: "star.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(P.butter)
                        }
                    }
                    Text(t.task)
                        .font(.system(size: 16, weight: .heavy))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .foregroundStyle(P.text)
                    Text("\(t.points) pts")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(P.butter)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 24).fill(P.surface))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(P.border, lineWidth: 1.5))
                .scaleEffect(completing ? 1.06 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: completing)
                .contentShape(Rectangle())
            }
            .buttonStyle(.row)
        }

        // MARK: – Stats card (tween only)

        private var statsCard: some View {
            let lc = myName.lowercased()
            let allTimeChores = allTodos.filter { ($0.assignee ?? "").lowercased() == lc && $0.points > 0 && $0.completedAt != nil }.count
            let weekAgo = Date().addingTimeInterval(-7 * 86400)
            let weekPoints = allTodos.filter { t in
                (t.assignee ?? "").lowercased() == lc
                && t.points > 0
                && (t.completedAt.map { $0 >= weekAgo } ?? false)
            }.reduce(0) { $0 + Int($1.points) }
            let currentStreak: Int = {
                let completedDays: Set<String> = Set(
                    allTodos.compactMap { t -> String? in
                        guard (t.assignee ?? "").lowercased() == lc,
                              t.points > 0,
                              let d = t.completedAt else { return nil }
                        let fmt = DateFormatter()
                        fmt.dateFormat = "yyyy-MM-dd"
                        return fmt.string(from: d)
                    }
                )
                var streak = 0
                var cal = Calendar.current
                cal.firstWeekday = 1
                var day = cal.startOfDay(for: Date())
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd"
                while completedDays.contains(fmt.string(from: day)) {
                    streak += 1
                    day = cal.date(byAdding: .day, value: -1, to: day) ?? day.addingTimeInterval(-86400)
                }
                return streak
            }()
            return VStack(alignment: .leading, spacing: 10) {
                sectionTitle("MY STATS", emoji: "📊", color: P.sky)
                HStack(spacing: 0) {
                    statBubble(value: allTimeChores, label: "chores done")
                    Divider().frame(height: 44).background(P.border)
                    statBubble(value: weekPoints, label: "pts this week")
                    Divider().frame(height: 44).background(P.border)
                    statBubble(value: currentStreak, label: "day streak")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
            }
        }

        private func statBubble(value: Int, label: String) -> some View {
            VStack(spacing: 4) {
                Text("\(value)").font(.system(size: 28, weight: .heavy)).foregroundStyle(P.butter)
                Text(label).font(.system(size: 10, weight: .heavy)).foregroundStyle(P.textMuted).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }

        // MARK: – Settings sheet (theme + tier)

        private var settingsSheet: some View {
            ZStack {
                P.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Spacer().frame(height: 4)
                        Text("My Settings")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(P.text)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // ── Theme section ──
                        VStack(alignment: .leading, spacing: 10) {
                            Text("THEME")
                                .font(.system(size: 11, weight: .heavy))
                                .tracking(1.4)
                                .foregroundStyle(P.textMuted)

                            ForEach([
                                ("space",  "Space",  Color(rgb: 0x1B1E4A), Color(rgb: 0xB084F5)),
                                ("ocean",  "Ocean",  Color(rgb: 0x0A1628), Color(rgb: 0x00CED4)),
                                ("garden", "Garden", Color(rgb: 0x1A2A1A), Color(rgb: 0x7ED96F)),
                                ("orchid", "Orchid", Color(rgb: 0x2A0A3A), Color(rgb: 0xFF69B4))
                            ], id: \.0) { key, label, bgColor, accentColor in
                                Button {
                                    themeName = key
                                } label: {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle().fill(bgColor).frame(width: 40, height: 40)
                                            Circle().fill(accentColor).frame(width: 18, height: 18)
                                        }
                                        Text(label)
                                            .font(.system(size: 16, weight: .heavy))
                                            .foregroundStyle(P.text)
                                        Spacer()
                                        if themeName == key {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .heavy))
                                                .foregroundStyle(P.mint)
                                        }
                                    }
                                    .padding(14)
                                    .background(RoundedRectangle(cornerRadius: 18).fill(themeName == key ? P.surfaceAlt : P.surface))
                                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(themeName == key ? P.mint.opacity(0.5) : P.border, lineWidth: 1.5))
                                }
                                .buttonStyle(.row)
                            }
                        }

                        // ── Age / style section ──
                        VStack(alignment: .leading, spacing: 10) {
                            Text("MY STYLE")
                                .font(.system(size: 11, weight: .heavy))
                                .tracking(1.4)
                                .foregroundStyle(P.textMuted)

                            ForEach([
                                ("little", "Simple", "Big buttons, just the fun stuff"),
                                ("tween",  "Full",   "Stats, family, the whole thing")
                            ], id: \.0) { key, label, subtitle in
                                Button {
                                    tier = key
                                } label: {
                                    HStack(spacing: 14) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(label).font(.system(size: 16, weight: .heavy)).foregroundStyle(P.text)
                                            Text(subtitle).font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textDim)
                                        }
                                        Spacer()
                                        if tier == key {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .heavy))
                                                .foregroundStyle(P.mint)
                                        }
                                    }
                                    .padding(14)
                                    .background(RoundedRectangle(cornerRadius: 18).fill(tier == key ? P.surfaceAlt : P.surface))
                                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(tier == key ? P.mint.opacity(0.5) : P.border, lineWidth: 1.5))
                                }
                                .buttonStyle(.row)
                            }
                        }

                        Spacer(minLength: 30)
                    }
                    .padding(20)
                }
            }
            .foregroundStyle(P.text)
            .preferredColorScheme(.dark)
            .presentationDetents([.medium])
        }

        private func sectionTitle(_ text: String, emoji: String, color: Color) -> some View {
            HStack(spacing: 8) {
                Text(emoji).font(.system(size: 22))
                Text(text).font(.system(size: 13, weight: .heavy)).tracking(1.4).foregroundStyle(color)
                Spacer()
            }.padding(.horizontal, 4)
        }

        private func emptyCard(_ emoji: String, title: String, subtitle: String, tint: Color) -> some View {
            VStack(spacing: 8) {
                Text(emoji).font(.system(size: 44))
                Text(title).font(.system(size: 16, weight: .heavy))
                Text(subtitle).font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textDim)
            }
            .frame(maxWidth: .infinity).padding(24)
            .background(RoundedRectangle(cornerRadius: 22).fill(tint.opacity(0.25)))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(tint.opacity(0.5), lineWidth: 1.5))
        }

        private var celebrateOverlay: some View {
            ZStack {
                Color.black.opacity(0.25).ignoresSafeArea()
                // Label moved to top so the center of the screen is a clear
                // canvas for the confetti to fly across.
                VStack {
                    Text(celebrateLabel)
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28).padding(.vertical, 16)
                        .background(Capsule().fill(P.lavender))
                        .scaleEffect(celebrate ? 1.0 : 0.5)
                        .opacity(celebrate ? 1.0 : 0.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: celebrate)
                        .padding(.top, 110)
                    Spacer()
                }
                // Confetti drawn LAST so it sails on top of the label.
                ForEach(0..<14, id: \.self) { i in
                    confettiBit(index: i)
                }
            }
            .transition(.opacity)
        }

        private func confettiBit(index: Int) -> some View {
            let emojis = ["🎉", "✨", "⭐️", "🎊", "💫", "🌟"]
            let emoji = emojis[index % emojis.count]
            // Deterministic-per-index pseudo-random spread so each bit takes
            // a different path without re-randomizing on view rebuilds.
            let angle = Double(index) * (2 * .pi / 14)
            let distance: Double = 160 + Double((index * 17) % 80)
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance - 50
            return Text(emoji)
                .font(.system(size: 32))
                .offset(x: confettiFlying ? dx : 0, y: confettiFlying ? dy : 0)
                .opacity(confettiFlying ? 0.0 : 1.0)
                .scaleEffect(confettiFlying ? 0.4 : 1.4)
                .rotationEffect(.degrees(confettiFlying ? Double(index) * 30 : 0))
        }
    }

    public struct Root: View {
        @State private var page: Int = 0
        @Environment(\.managedObjectContext) private var moc
        @AppStorage("userName") private var userName: String = ""
        @AppStorage("meUid") private var meUid: String = ""
        @AppStorage("appearancePref") private var appearancePref: String = "system"
        // Forces the entire shell to re-render when the user picks a different
        // theme in Settings. We don't use the value directly; we just need
        // SwiftUI to observe it. Palette.resolve(_:) reads it from
        // UserDefaults at body-eval time.
        @AppStorage("paletteName") private var paletteName: String = Palette.defaultName
        @AppStorage("hasSeenTutorial") private var hasSeenTutorial: Bool = false
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
        private var members: FetchedResults<FamilyMember>
        @State private var showNamePrompt: Bool = false
        @State private var pendingName: String = ""
        @State private var showTutorial: Bool = false
        public init() {}

        private var meIsKid: Bool {
            FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)?.isKid ?? false
        }

        private var preferredScheme: ColorScheme? {
            switch appearancePref {
            case "light": return .light
            case "dark":  return .dark
            default:      return nil
            }
        }

        public var body: some View {
            Group {
                if meIsKid {
                    Kids()
                } else {
                    adultShell
                }
            }
            .preferredColorScheme(preferredScheme)
            .task {
                evaluateNamePrompt()
                evaluateTutorial()
                reconcileMyRole()
            }
            .onChange(of: userName) { _, _ in
                evaluateNamePrompt()
                evaluateTutorial()
            }
            .onChange(of: members.map { $0.roleLevel }) { _, _ in
                reconcileMyRole()
            }
            .sheet(isPresented: $showNamePrompt) { namePromptSheet }
            .sheet(isPresented: $showTutorial) { HelpView() }
        }

        private var adultShell: some View {
            TabView(selection: $page) {
                Home().tag(0)
                Rewards(onHome: { page = 0 }).tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
        }

        private func evaluateTutorial() {
            // Show the tutorial once name is set and the user hasn't seen it.
            if !hasSeenTutorial && !userName.trimmingCharacters(in: .whitespaces).isEmpty && !showNamePrompt {
                // Tiny delay so it doesn't race the name prompt's dismiss animation.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if !hasSeenTutorial { showTutorial = true }
                }
            }
        }

        private func evaluateNamePrompt() {
            if userName.trimmingCharacters(in: .whitespaces).isEmpty {
                pendingName = ""
                showNamePrompt = true
            }
        }

        /// Keep this device's "me" record in sync with the shared store.
        ///
        /// The admin always writes to the SHARED store record.  If this device's
        /// `meUid` still points to a private-store record (the original local
        /// copy created before joining the share), we re-point it at the shared
        /// store record and mirror that record's role.  Works in BOTH directions
        /// (kid → standard AND standard → kid) because we follow the shared store
        /// unconditionally rather than just promoting.
        private func reconcileMyRole() {
            let stack = CasaCoreDataStack.shared
            guard let sharedStore = stack.sharedStore else { return }

            let myNameLower = userName.trimmingCharacters(in: .whitespaces).lowercased()
            guard !myNameLower.isEmpty else { return }

            // Find the live shared-store record for this user's name.
            guard let sharedRecord = members.first(where: {
                $0.deletedAt == nil
                && $0.name.lowercased() == myNameLower
                && $0.objectID.persistentStore == sharedStore
            }) else { return }

            // Point meUid at the shared record so currentMember() always lands
            // on the authoritative copy.
            let sharedUID = sharedRecord.uid.uuidString
            if meUid != sharedUID {
                meUid = sharedUID
            }

            // If the local private-store record has a stale role, update it too
            // (keeps dedupe from resurrecting the wrong role later).
            if let privateRecord = members.first(where: {
                $0.deletedAt == nil
                && $0.name.lowercased() == myNameLower
                && $0.objectID.persistentStore == stack.privateStore
                && $0.uid != sharedRecord.uid
            }), privateRecord.roleLevel != sharedRecord.roleLevel {
                privateRecord.roleLevel = sharedRecord.roleLevel
                try? moc.save()
            }
        }

        private var namePromptSheet: some View {
            let palette = Palette.resolve(false)
            return NavigationStack {
                ZStack {
                    palette.bg.ignoresSafeArea()
                    VStack(spacing: 20) {
                        Spacer().frame(height: 12)
                        Text("🏡").font(.system(size: 52))
                        Text("Welcome to Casalist").font(.system(size: 22, weight: .heavy))
                        Text("Tell us your name so your family sees who you are.")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        TextField("Your name", text: $pendingName)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(palette.surface))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.border, lineWidth: 1.5))
                            .padding(.horizontal, 24)
                            .onSubmit(commitName)
                        Button(action: commitName) {
                            Text("Get started").font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Capsule().fill(palette.peach))
                                .padding(.horizontal, 24)
                        }
                        .disabled(pendingName.trimmingCharacters(in: .whitespaces).isEmpty)
                        Spacer()
                    }
                    .padding(.top, 18)
                }
                .foregroundStyle(palette.text)
            }
            .interactiveDismissDisabled(true)
        }

        private func commitName() {
            let trimmed = pendingName.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            userName = trimmed

            // Case A — already auto-provisioned (joined a share before naming
            // ourselves). Just rename the existing record.
            if !meUid.isEmpty, let uuid = UUID(uuidString: meUid) {
                let req = FamilyMember.fetchRequest()
                req.predicate = NSPredicate(format: "uid == %@", uuid as CVarArg)
                if let mine = (try? moc.fetch(req))?.first {
                    if mine.name != trimmed {
                        mine.name = trimmed
                        try? moc.save()
                    }
                    showNamePrompt = false
                    return
                }
            }

            // Case B — fresh install, no claim yet. Become a FamilyMember in
            // our own household. Owner if no other members exist, otherwise
            // standard.
            HouseholdProvisioner.ensureHouseholdExists(in: moc)
            let allReq = FamilyMember.fetchRequest()
            let existing = (try? moc.fetch(allReq)) ?? []
            // Adopt-before-create: if CloudKit already synced down a
            // FamilyMember with this name into the current household, claim
            // it instead of creating a duplicate. Avoids the reinstall race
            // where two same-name records show up minutes later.
            if let already = existing.first(where: { $0.name.lowercased() == trimmed.lowercased() }) {
                meUid = already.uid.uuidString
                showNamePrompt = false
                return
            }
            let role: FamilyRole = existing.isEmpty ? .owner : .standard
            if let household = (try? moc.fetch(Household.fetchRequest()))?.preferredTarget {
                let me = FamilyMember(context: moc, name: trimmed, role: role.label, colorHex: 0xC97357, roleLevel: role)
                moc.assign(me, toStoreOf: household)
                me.household = household
                meUid = me.uid.uuidString
                try? moc.save()
                // Stamp this device's iCloud user ID onto the new
                // FamilyMember so we can dedupe by stable identity from
                // here on out. Async — runs in the background and saves
                // when the userRecordID lookup returns.
                Task { @MainActor in
                    await FamilyIdentity.stampOwnIdentity(on: me, in: moc)
                }
            }
            showNamePrompt = false
            // Follow-up dedupe pass — if CloudKit syncs an original
            // same-userID record after this commit, the cloudKitUserID-keyed
            // merge collapses them automatically.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                Task { @MainActor in
                    await FamilyIdentity.backfillSelf(in: moc)
                    FamilyDedupe.mergeByCloudKitUserID(in: moc)
                    FamilyDedupe.mergeLegacyNameDupes(in: moc)
                    FamilyDedupe.mergeDuplicateMeRecords(in: moc, userName: trimmed)
                }
            }
        }
    }

    // MARK: - Bundle Draft Sheet
    struct BundleDraftSheet: View {
        @Environment(\.managedObjectContext) private var moc
        @Environment(\.dismiss) private var dismiss
        @AppStorage("userName") private var userName: String = ""
        @AppStorage("meUid") private var meUid: String = ""
        @ObservedObject var bundle: TaskItem
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)],
                      predicate: NSPredicate(format: "deletedAt == nil"))
        private var members: FetchedResults<FamilyMember>
        @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)],
                      predicate: NSPredicate(format: "deletedAt == nil"))
        private var households: FetchedResults<Household>
        private var children: [TaskItem] {
            (try? moc.fetch({
                let r = NSFetchRequest<TaskItem>(entityName: "TaskItem")
                r.predicate = NSPredicate(format: "parentUid == %@ AND deletedAt == nil", bundle.uid)
                r.sortDescriptors = [NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: true)]
                return r
            }())) ?? []
        }

        @State private var newChore = ""
        @State private var newChorePts = 10
        @State private var selectedAssignee: String = ""

        private var dark: Bool { true }
        @Environment(\.colorScheme) private var sys
        @AppStorage("paletteName") private var paletteName: String = "vivid"
        private var P: Palette { Palette.resolve(sys == .dark) }

        init(bundle: TaskItem) {
            self.bundle = bundle
            _selectedAssignee = State(initialValue: bundle.assignee ?? "")
        }

        private var color: Color {
            switch bundle.category.lowercased() {
            case "chores": return Color(rgb: 0x4CAF82)
            case "home": return Color(rgb: 0x5B9BD5)
            case "maintenance": return Color(rgb: 0xE8A838)
            case "family": return Color(rgb: 0xC87DD4)
            default: return Color(rgb: 0x4CAF82)
            }
        }

        var body: some View {
            NavigationStack {
                ZStack {
                    P.bg.ignoresSafeArea()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // Header
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 5, height: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bundle.task)
                                        .font(.system(size: 22, weight: .heavy)).foregroundStyle(P.text)
                                    Text(bundle.category)
                                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(P.textDim)
                                }
                                Spacer()
                                // Bonus badge
                                if bundle.points > 0 {
                                    HStack(spacing: 3) {
                                        Text("⚡️⚡️").font(.system(size: 9))
                                        Text("+\(bundle.points) bonus")
                                    }
                                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Capsule().fill(Color(rgb: 0xE8B040).opacity(0.9)))
                                }
                            }
                            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 16)

                            // Chores list
                            VStack(spacing: 0) {
                                if children.isEmpty {
                                    Text("No chores yet — add one below")
                                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(P.textMuted)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 20).padding(.vertical, 14)
                                } else {
                                    ForEach(children, id: \.uid) { child in
                                        HStack(spacing: 12) {
                                            Circle().stroke(color, lineWidth: 1.5).frame(width: 18, height: 18).opacity(0.5)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(child.task).font(.system(size: 14, weight: .semibold)).foregroundStyle(P.text)
                                                if child.points > 0 {
                                                    Text("+\(child.points) pts").font(.system(size: 10, weight: .heavy)).foregroundStyle(P.textDim)
                                                }
                                            }
                                            Spacer()
                                            Button {
                                                child.softDelete()
                                                try? moc.save()
                                            } label: {
                                                Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(P.textMuted)
                                            }.buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 20).padding(.vertical, 12)
                                        .background(P.surface)
                                        Divider().padding(.leading, 50)
                                    }
                                }

                                // Inline add
                                HStack(spacing: 10) {
                                    Image(systemName: "plus.circle").font(.system(size: 16)).foregroundStyle(color.opacity(0.7))
                                    TextField("Add a chore…", text: $newChore)
                                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(P.text)
                                        .submitLabel(.done)
                                        .onSubmit { addChore() }
                                    HStack(spacing: 6) {
                                        Button { newChorePts = max(0, newChorePts - 5) } label: {
                                            Image(systemName: "minus").font(.system(size: 10, weight: .heavy))
                                        }.buttonStyle(.plain)
                                        Text("\(newChorePts)pt")
                                            .font(.system(size: 11, weight: .heavy)).foregroundStyle(P.text)
                                            .frame(minWidth: 30, alignment: .center)
                                        Button { newChorePts = min(100, newChorePts + 5) } label: {
                                            Image(systemName: "plus").font(.system(size: 10, weight: .heavy))
                                        }.buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Capsule().fill(P.surfaceAlt))
                                    Button { addChore() } label: {
                                        Image(systemName: "arrow.up").font(.system(size: 12, weight: .heavy)).foregroundStyle(.white)
                                            .frame(width: 28, height: 28).background(Circle().fill(color))
                                    }.buttonStyle(.plain)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .background(P.surface)
                            }
                            .background(RoundedRectangle(cornerRadius: 16).fill(P.surface))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(P.border, lineWidth: 1))
                            .padding(.horizontal, 16)

                            // Bonus pts
                            HStack(spacing: 12) {
                                Image(systemName: "bolt.fill").font(.system(size: 13, weight: .heavy)).foregroundStyle(Color(rgb: 0xE8B040))
                                Text("Completion bonus").font(.system(size: 14, weight: .semibold)).foregroundStyle(P.text)
                                Spacer()
                                HStack(spacing: 10) {
                                    Button { bundle.points = max(0, bundle.points - 5); try? moc.save() } label: {
                                        Image(systemName: "minus").font(.system(size: 12, weight: .heavy))
                                            .frame(width: 30, height: 30).background(Circle().fill(P.surfaceAlt))
                                    }.buttonStyle(.plain)
                                    Text("\(bundle.points) pts")
                                        .font(.system(size: 14, weight: .heavy)).foregroundStyle(P.text)
                                        .frame(minWidth: 55, alignment: .center)
                                    Button { bundle.points = min(500, bundle.points + 5); try? moc.save() } label: {
                                        Image(systemName: "plus").font(.system(size: 12, weight: .heavy))
                                            .frame(width: 30, height: 30).background(Circle().fill(P.surfaceAlt))
                                    }.buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20).padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 16).fill(P.surface))
                            .padding(.horizontal, 16).padding(.top, 12)

                            // Assignee picker
                            VStack(alignment: .leading, spacing: 6) {
                                Text("ASSIGN TO").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim)
                                    .padding(.horizontal, 20).padding(.top, 16)
                                VStack(spacing: 0) {
                                    // "Anyone" option
                                    Button {
                                        withAnimation { selectedAssignee = "" }
                                    } label: {
                                        HStack {
                                            Text("Anyone (unassigned)").font(.system(size: 14, weight: .semibold)).foregroundStyle(P.text)
                                            Spacer()
                                            if selectedAssignee.isEmpty {
                                                Image(systemName: "checkmark.circle.fill").foregroundStyle(color)
                                            }
                                        }
                                        .padding(.horizontal, 16).padding(.vertical, 12)
                                        .background(selectedAssignee.isEmpty ? color.opacity(0.08) : Color.clear)
                                        .contentShape(Rectangle())
                                    }.buttonStyle(.plain)
                                    Divider().padding(.leading, 16)
                                    ForEach(members, id: \.uid) { m in
                                        Button {
                                            withAnimation { selectedAssignee = m.name }
                                        } label: {
                                            HStack(spacing: 10) {
                                                CLAvatar(m.asCLMember, size: 28)
                                                Text(m.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(P.text)
                                                Spacer()
                                                if selectedAssignee == m.name {
                                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(color)
                                                }
                                            }
                                            .padding(.horizontal, 16).padding(.vertical, 10)
                                            .background(selectedAssignee == m.name ? color.opacity(0.08) : Color.clear)
                                            .contentShape(Rectangle())
                                        }.buttonStyle(.plain)
                                        if m != members.last { Divider().padding(.leading, 54) }
                                    }
                                }
                                .background(RoundedRectangle(cornerRadius: 16).fill(P.surface))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(P.border, lineWidth: 1))
                                .padding(.horizontal, 16)
                            }

                            // Done / Assign button
                            Button {
                                bundle.assignee = selectedAssignee.isEmpty ? nil : selectedAssignee
                                // Only finalize (leave agenda → My To-Do) when assigned to someone
                                if !selectedAssignee.isEmpty {
                                    bundle.repeatKind = "bundle"
                                }
                                // No assignee = stays as bundle-draft, remains in agenda
                                try? moc.save()
                                dismiss()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: selectedAssignee.isEmpty ? "square.stack.fill" : "checkmark.circle.fill")
                                        .font(.system(size: 15, weight: .heavy))
                                    Text(selectedAssignee.isEmpty ? "Save draft" : "Assign to \(selectedAssignee)")
                                        .font(.system(size: 15, weight: .heavy))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Capsule().fill(selectedAssignee.isEmpty ? P.textDim : color))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 32)

                            // Delete
                            Button {
                                children.forEach { $0.softDelete() }
                                bundle.softDelete()
                                try? moc.save()
                                dismiss()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash").font(.system(size: 12, weight: .heavy))
                                    Text("Delete bundle").font(.system(size: 13, weight: .heavy))
                                }
                                .foregroundStyle(Color.red.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16).padding(.bottom, 20)
                        }
                    }
                }
                .navigationTitle("Building bundle")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
            }
        }

        private func addChore() {
            let text = newChore.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return }
            let myName = FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)?.name ?? userName
            let chore = TaskItem(
                context: moc,
                task: text,
                category: bundle.category,
                points: newChorePts,
                createdBy: myName.trimmingCharacters(in: .whitespaces)
            )
            chore.parentUid = bundle.uid
            chore.assignee = bundle.assignee
            if let h = households.preferredTarget {
                moc.assign(chore, toStoreOf: h)
                chore.household = h
            }
            try? moc.save()
            newChore = ""
        }
    }
}

#Preview("Root") { CasalistCottage.Root() }
#Preview("Home") { CasalistCottage.Home() }
#Preview("Rewards") { CasalistCottage.Rewards() }
#Preview("MyToDo") { CasalistCottage.MyToDo() }
#Preview("Schedule") { CasalistCottage.Schedule() }
