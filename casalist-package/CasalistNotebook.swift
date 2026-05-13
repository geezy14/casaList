//
//  CasalistNotebook.swift
//  Casalist — "Notebook" direction (Notion-style minimal, iOS 17+)
//
//  Requires CasalistShared.swift.
//  Use as:  CasalistNotebook.Home()  or  CasalistNotebook.Rewards()
//

import SwiftUI

public enum CasalistNotebook {

    struct Palette {
        let bg, surface, surfaceAlt, surfaceHi, border, borderHi: Color
        let text, textDim, textMuted: Color
        let accent, accentSoft, green, red, amber: Color
        static func resolve(_ dark: Bool) -> Palette {
            dark ? Palette(
                bg: Color(rgb: 0x191919), surface: Color(rgb: 0x1F1F1F), surfaceAlt: Color(rgb: 0x262626), surfaceHi: Color(rgb: 0x2E2E2E),
                border: Color.white.opacity(0.10), borderHi: Color.white.opacity(0.18),
                text: Color(rgb: 0xF7F6F3), textDim: Color(rgb: 0xF7F6F3).opacity(0.6), textMuted: Color(rgb: 0xF7F6F3).opacity(0.4),
                accent: Color(rgb: 0x9B82FF), accentSoft: Color(rgb: 0x9B82FF).opacity(0.16),
                green: Color(rgb: 0x4CAA70), red: Color(rgb: 0xE5564A), amber: Color(rgb: 0xE8A422)
            ) : Palette(
                bg: .white, surface: .white, surfaceAlt: Color(rgb: 0xF7F6F3), surfaceHi: Color(rgb: 0xEFEEEA),
                border: Color.black.opacity(0.10), borderHi: Color.black.opacity(0.18),
                text: Color(rgb: 0x191919), textDim: Color(rgb: 0x191919).opacity(0.6), textMuted: Color(rgb: 0x191919).opacity(0.4),
                accent: Color(rgb: 0x6B5CE7), accentSoft: Color(rgb: 0x6B5CE7).opacity(0.10),
                green: Color(rgb: 0x287E4C), red: Color(rgb: 0xC8362F), amber: Color(rgb: 0x9C6A12)
            )
        }
    }

    public struct Home: View {
        @Environment(\.colorScheme) private var sys
        @State private var darkOverride: Bool? = nil
        private var dark: Bool { darkOverride ?? (sys == .dark) }
        private var P: Palette { Palette.resolve(dark) }
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
        }

        private var topBar: some View {
            HStack(spacing: 8) {
                Text("Casalist · /home").font(.system(size: 13, weight: .medium)).foregroundStyle(P.textMuted)
                Spacer()
                Button { darkOverride = !dark } label: {
                    Image(systemName: dark ? "sun.max.fill" : "moon.fill").font(.system(size: 12)).foregroundStyle(P.textDim)
                        .frame(width: 28, height: 28)
                        .background(RoundedRectangle(cornerRadius: 6).stroke(P.border, lineWidth: 1))
                }
                Button {} label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                        Text("New").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(P.accent))
                }
            }.padding(.horizontal, 16).padding(.bottom, 4)
        }

        private var content: some View {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Good evening, geezy").font(.system(size: 32, weight: .bold))
                    Text("Tuesday, May 12 · \(Casalist.family.count) family members online").font(.system(size: 13)).foregroundStyle(P.textDim)
                }.padding(.top, 18)

                familyChips.padding(.top, 14)
                section("TODAY'S AGENDA", topPadding: 26) { agendaRows }
                quickAdd.padding(.top, 18)
                featured.padding(.top, 26)
                section("MODULES", topPadding: 26) { modulesRows }
                section("ACTIVITY", topPadding: 26) { activityRows }
            }
            .padding(.horizontal, 20).padding(.bottom, 28)
        }

        private func section<T: View>(_ title: String, topPadding: CGFloat, @ViewBuilder _ content: () -> T) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 11, weight: .bold)).tracking(0.8).foregroundStyle(P.textMuted)
                content()
            }.padding(.top, topPadding)
        }

        private var familyChips: some View {
            HStack(spacing: 6) {
                ForEach(Casalist.family) { m in
                    HStack(spacing: 6) {
                        CLAvatar(m, size: 20, ring: false)
                        Text(m.label).font(.system(size: 12, weight: .semibold))
                        Text("\(m.points)").font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted)
                    }
                    .padding(.leading, 4).padding(.trailing, 10).padding(.vertical, 4)
                    .background(Capsule().fill(P.surfaceAlt))
                    .overlay(Capsule().stroke(P.border, lineWidth: 1))
                }
                Spacer()
            }
        }

        private var agendaRows: some View {
            VStack(spacing: 0) {
                ForEach(Casalist.agenda) { a in
                    HStack(spacing: 10) {
                        Text("\(a.time) \(a.ampm)").font(.system(size: 12, weight: .bold)).foregroundStyle(P.textMuted).monospacedDigit().frame(width: 56, alignment: .leading)
                        Text(a.label).font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text(a.sub).font(.system(size: 11)).foregroundStyle(P.textDim)
                    }.padding(.vertical, 10)
                    .overlay(alignment: .top) { Rectangle().fill(P.border).frame(height: 1) }
                }
            }
        }

        private var quickAdd: some View {
            HStack(spacing: 8) {
                Image(systemName: "plus").font(.system(size: 14)).foregroundStyle(P.textMuted)
                TextField("Quick add — task, item, chore…", text: .constant("")).font(.system(size: 13, weight: .medium))
                Text("⌘ + N").font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textMuted)
            }
            .padding(.horizontal, 12).padding(.vertical, 9).padding(.leading, 2)
            .background(RoundedRectangle(cornerRadius: 6).fill(P.surface))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(P.border, lineWidth: 1))
        }

        private var featured: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("🏆").font(.system(size: 14))
                    Text("CHORE REWARDS · THIS MONTH").font(.system(size: 11, weight: .bold)).tracking(0.5).foregroundStyle(P.accent)
                }
                Text("Donovan leads with 240 pts").font(.system(size: 18, weight: .bold)).padding(.bottom, 6)
                ForEach(Array(Casalist.family.sorted { $0.points > $1.points }.enumerated()), id: \.element.id) { i, m in
                    HStack(spacing: 8) {
                        Text("\(i+1)").font(.system(size: 11, weight: .bold)).foregroundStyle(P.textMuted).frame(width: 14)
                        Text(m.label).font(.system(size: 13, weight: .medium)).frame(width: 64, alignment: .leading)
                        GeometryReader { g in
                            Rectangle().fill(P.surfaceHi).overlay(alignment: .leading) {
                                Rectangle().fill(m.color).frame(width: g.size.width * CGFloat(m.points) / 240)
                            }
                        }.frame(height: 4)
                        Text("\(m.points)").font(.system(size: 12, weight: .bold)).monospacedDigit().frame(width: 38, alignment: .trailing)
                    }.padding(.vertical, 2)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 8).fill(P.accentSoft))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(P.border, lineWidth: 1))
        }

        private var modulesRows: some View {
            let items: [(String, String, String, String, String?)] = [
                ("🛒", "Grocery list",      "12 items",  Casalist.groceryPreview.prefix(3).joined(separator: ", "), nil),
                ("🔧", "Maintenance",       "3 due",     Casalist.maintenanceNext, "SOON"),
                ("✅", "My to-do",          "4 today",   Casalist.todoNext, nil),
                ("📌", "Reminders",         "7 pinned",  "Wi-Fi, Pet sitter, Emergency...", nil),
            ]
            return VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, m in
                    HStack(spacing: 12) {
                        Text(m.0).font(.system(size: 14)).frame(width: 30, height: 30)
                            .background(RoundedRectangle(cornerRadius: 6).fill(P.surfaceAlt))
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 6) {
                                Text(m.1).font(.system(size: 14, weight: .semibold))
                                if let b = m.4 {
                                    Text(b).font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(P.amber)
                                        .padding(.horizontal, 6).padding(.vertical, 1)
                                        .background(RoundedRectangle(cornerRadius: 3).fill(P.amber.opacity(0.18)))
                                }
                            }
                            Text(m.3).font(.system(size: 11)).foregroundStyle(P.textMuted).lineLimit(1)
                        }
                        Spacer()
                        Text(m.2).font(.system(size: 12, weight: .semibold)).foregroundStyle(P.textDim)
                        Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(P.textMuted)
                    }.padding(.vertical, 12)
                    .overlay(alignment: .top) { Rectangle().fill(P.border).frame(height: 1) }
                }
            }
        }

        private var activityRows: some View {
            VStack(spacing: 0) {
                ForEach(Casalist.activity) { a in
                    HStack(spacing: 10) {
                        if a.who == "system" {
                            Text("🔔").font(.system(size: 11)).frame(width: 22, height: 22).background(Circle().fill(P.surfaceAlt))
                        } else {
                            CLAvatar(Casalist.member(a.who), size: 22, ring: false)
                        }
                        (Text(a.who == "system" ? "Casalist" : Casalist.member(a.who).label).font(.system(size: 12, weight: .semibold))
                         + Text(" \(a.verb) ").font(.system(size: 12)).foregroundColor(P.textDim)
                         + Text(a.target).font(.system(size: 12, weight: .medium)))
                        .lineLimit(2)
                        Spacer()
                        Text(a.when).font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted)
                    }.padding(.vertical, 9)
                    .overlay(alignment: .top) { Rectangle().fill(P.border).frame(height: 1) }
                }
            }
        }
    }

    // MARK: – Rewards
    public struct Rewards: View {
        @Environment(\.colorScheme) private var sys
        @State private var darkOverride: Bool? = nil
        @Environment(\.dismiss) private var dismiss
        private var dark: Bool { darkOverride ?? (sys == .dark) }
        private var P: Palette { Palette.resolve(dark) }
        private var sorted: [CLFamilyMember] { Casalist.family.sorted { $0.points > $1.points } }
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
        }

        private var topBar: some View {
            HStack(spacing: 8) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 12))
                        Text("Home").font(.system(size: 13, weight: .medium))
                    }.foregroundStyle(P.textDim)
                }
                Spacer()
                Text("/rewards").font(.system(size: 13)).foregroundStyle(P.textMuted)
                Button { darkOverride = !dark } label: {
                    Image(systemName: dark ? "sun.max.fill" : "moon.fill").font(.system(size: 12)).foregroundStyle(P.textDim)
                        .frame(width: 28, height: 28)
                        .background(RoundedRectangle(cornerRadius: 6).stroke(P.border, lineWidth: 1))
                }
            }.padding(.horizontal, 16).padding(.bottom, 4)
        }

        private var content: some View {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🏆 CHORE REWARDS").font(.system(size: 11, weight: .bold)).tracking(0.8).foregroundStyle(P.accent)
                    Text("Leaderboard").font(.system(size: 32, weight: .bold))
                }.padding(.top, 14)

                winner.padding(.top, 16)
                section("STANDINGS") { standings }.padding(.top, 26)
                section("GOALS") { goalsRows }.padding(.top, 26)
                section("AVAILABLE CHORES") { availableRows }.padding(.top, 26)
                section("RECENT") { recentRows }.padding(.top, 26)
            }
            .padding(.horizontal, 20).padding(.bottom, 28)
        }

        private func section<T: View>(_ title: String, @ViewBuilder _ c: () -> T) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 11, weight: .bold)).tracking(0.8).foregroundStyle(P.textMuted)
                c()
            }
        }

        private var winner: some View {
            HStack(spacing: 12) {
                CLAvatar(sorted[0], size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("1ST PLACE · THIS MONTH").font(.system(size: 11, weight: .bold)).tracking(0.5).foregroundStyle(P.accent)
                    Text(sorted[0].label).font(.system(size: 20, weight: .bold))
                    Text("\(sorted[0].points) pts · +\(sorted[0].points - sorted[1].points) ahead of \(sorted[1].label)").font(.system(size: 12)).foregroundStyle(P.textDim)
                }
                Spacer()
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 8).fill(P.accentSoft))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(P.border, lineWidth: 1))
        }

        private var standings: some View {
            VStack(spacing: 0) {
                ForEach(Array(sorted.enumerated()), id: \.element.id) { i, m in
                    HStack(spacing: 12) {
                        Text("\(i+1)").font(.system(size: 12, weight: .bold)).foregroundStyle(P.textMuted).frame(width: 14)
                        CLAvatar(m, size: 32)
                        VStack(spacing: 4) {
                            HStack {
                                Text(m.label).font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Text("\(m.points)").font(.system(size: 13, weight: .bold)).monospacedDigit()
                            }
                            GeometryReader { g in
                                Rectangle().fill(P.surfaceHi).frame(height: 3).overlay(alignment: .leading) {
                                    Rectangle().fill(m.color).frame(width: g.size.width * CGFloat(m.points) / 240, height: 3)
                                }
                            }.frame(height: 3)
                        }
                    }.padding(.vertical, 12)
                    .overlay(alignment: .top) { Rectangle().fill(P.border).frame(height: 1) }
                }
            }
        }

        private var goalsRows: some View {
            VStack(spacing: 0) {
                ForEach(Casalist.goals) { g in
                    let m = Casalist.member(g.who)
                    HStack(spacing: 12) {
                        CLAvatar(m, size: 26, ring: false)
                        VStack(spacing: 4) {
                            HStack {
                                Text(g.label).font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text("\(g.current) / \(g.target)").font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textDim).monospacedDigit()
                            }
                            GeometryReader { gg in
                                Rectangle().fill(P.surfaceHi).overlay(alignment: .leading) {
                                    Rectangle().fill(m.color).frame(width: gg.size.width * CGFloat(g.current) / CGFloat(g.target))
                                }
                            }.frame(height: 3)
                        }
                    }.padding(.vertical, 12)
                    .overlay(alignment: .top) { Rectangle().fill(P.border).frame(height: 1) }
                }
            }
        }

        private var availableRows: some View {
            VStack(spacing: 0) {
                ForEach(Casalist.availableChores) { c in
                    HStack(spacing: 12) {
                        Image(systemName: c.symbol).font(.system(size: 13)).foregroundStyle(P.textDim)
                            .frame(width: 26, height: 26).background(RoundedRectangle(cornerRadius: 6).fill(P.surfaceAlt))
                        Text(c.label).font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("\(c.points) pts").font(.system(size: 12, weight: .bold)).foregroundStyle(P.amber).monospacedDigit()
                        Button {} label: {
                            Text("Claim").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                                .padding(.horizontal, 12).padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 6).fill(P.accent))
                        }
                    }.padding(.vertical, 11)
                    .overlay(alignment: .top) { Rectangle().fill(P.border).frame(height: 1) }
                }
            }
        }

        private var recentRows: some View {
            VStack(spacing: 0) {
                ForEach(Casalist.recentRewards) { r in
                    let m = Casalist.member(r.who)
                    HStack(spacing: 10) {
                        CLAvatar(m, size: 22, ring: false)
                        Text(r.label).font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text(r.date).font(.system(size: 11)).foregroundStyle(P.textMuted)
                        Text("+\(r.points)").font(.system(size: 12, weight: .bold)).foregroundStyle(P.green).monospacedDigit()
                    }.padding(.vertical, 10)
                    .overlay(alignment: .top) { Rectangle().fill(P.border).frame(height: 1) }
                }
            }
        }
    }
}

#Preview("Home") { CasalistNotebook.Home() }
#Preview("Rewards") { CasalistNotebook.Rewards() }
