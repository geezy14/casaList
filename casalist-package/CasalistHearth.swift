//
//  CasalistHearth.swift
//  Casalist — "Hearth" direction (warm, homey, Apple-native, iOS 17+)
//
//  Requires CasalistShared.swift in the same target.
//  Use as:  CasalistHearth.Home()  or  CasalistHearth.Rewards()
//

import SwiftUI

public enum CasalistHearth {

    // MARK: – Palette ────────────────────────────────────────────────
    struct Palette {
        let bg, surface, surfaceAlt, surfaceHi, border: Color
        let text, textDim, textMuted: Color
        let terracotta, sage, amber, sky, rose: Color

        static func resolve(_ dark: Bool) -> Palette {
            dark ? Palette(
                bg: Color(rgb: 0x1A1612), surface: Color(rgb: 0x251E18),
                surfaceAlt: Color(rgb: 0x30271F), surfaceHi: Color(rgb: 0x3A2F25),
                border: Color.white.opacity(0.08),
                text: Color(rgb: 0xF5EBE0), textDim: Color(rgb: 0xF5EBE0).opacity(0.6),
                textMuted: Color(rgb: 0xF5EBE0).opacity(0.4),
                terracotta: Color(rgb: 0xE89B7C), sage: Color(rgb: 0x97AE8E),
                amber: Color(rgb: 0xF4C77E), sky: Color(rgb: 0x8FC8DE), rose: Color(rgb: 0xE89AA0)
            ) : Palette(
                bg: Color(rgb: 0xFAF6F0), surface: Color(rgb: 0xFFFFFF),
                surfaceAlt: Color(rgb: 0xF2EDE5), surfaceHi: Color(rgb: 0xE9E2D7),
                border: Color.black.opacity(0.08),
                text: Color(rgb: 0x1F1B16), textDim: Color(rgb: 0x1F1B16).opacity(0.6),
                textMuted: Color(rgb: 0x1F1B16).opacity(0.4),
                terracotta: Color(rgb: 0xC97357), sage: Color(rgb: 0x7A9070),
                amber: Color(rgb: 0xD49447), sky: Color(rgb: 0x5A95B5), rose: Color(rgb: 0xD17A82)
            )
        }
    }

    // MARK: – Home ───────────────────────────────────────────────────
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
                    ScrollView { content }
                        .scrollIndicators(.hidden)
                }
            }
            .foregroundStyle(P.text)
            .preferredColorScheme(dark ? .dark : .light)
            .animation(.smooth(duration: 0.25), value: dark)
        }

        private var topBar: some View {
            HStack(spacing: 10) {
                HStack(spacing: -8) {
                    ForEach(Casalist.family) { CLAvatar($0, size: 32) }
                }
                Spacer()
                Button { darkOverride = !dark } label: {
                    Image(systemName: dark ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(P.text)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(P.surface))
                        .overlay(Circle().stroke(P.border, lineWidth: 1))
                }
                Button {} label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(P.terracotta))
                        .shadow(color: P.terracotta.opacity(0.4), radius: 8, y: 4)
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 12)
        }

        private var content: some View {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tuesday, May 12").font(.system(size: 12, weight: .medium)).foregroundStyle(P.textDim)
                    HStack(spacing: 0) {
                        Text("Good evening, ").font(.system(size: 28, weight: .bold))
                        Text("geezy").font(.system(size: 28, weight: .bold)).foregroundStyle(P.terracotta)
                    }
                }
                agendaCard
                featuredRewards
                modulesGrid
                activityCard
            }
            .padding(.horizontal, 20).padding(.bottom, 28)
        }

        private var agendaCard: some View {
            VStack(spacing: 0) {
                HStack {
                    Text("TODAY'S AGENDA").font(.system(size: 11, weight: .bold)).tracking(1.2).foregroundStyle(P.textDim)
                    Spacer()
                    Text("\(Casalist.agenda.count) events").font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textMuted)
                }.padding(.bottom, 12)
                ForEach(Array(Casalist.agenda.enumerated()), id: \.element.id) { i, a in
                    HStack(spacing: 12) {
                        Image(systemName: a.symbol)
                            .font(.system(size: 14)).foregroundStyle(a.color)
                            .frame(width: 36, height: 36)
                            .background(RoundedRectangle(cornerRadius: 10).fill(a.color.opacity(0.18)))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(a.label).font(.system(size: 14, weight: .semibold))
                            Text(a.sub).font(.system(size: 11)).foregroundStyle(P.textMuted)
                        }
                        Spacer()
                        HStack(spacing: 2) {
                            Text(a.time).font(.system(size: 13, weight: .bold)).monospacedDigit()
                            Text(a.ampm).font(.system(size: 10, weight: .bold)).foregroundStyle(P.textMuted)
                        }
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .top) {
                        if i > 0 { Rectangle().fill(P.border).frame(height: 1) }
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(P.surface))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(P.border, lineWidth: 1))
        }

        private var featuredRewards: some View {
            Button {} label: {
                ZStack(alignment: .topLeading) {
                    Circle().fill(Color.white.opacity(0.12))
                        .frame(width: 140, height: 140).offset(x: 180, y: -30)
                        .clipped()
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "trophy.fill").font(.system(size: 14))
                            Text("CHORE REWARDS").font(.system(size: 11, weight: .bold)).tracking(1.2)
                        }
                        Text("Donovan's in the lead").font(.system(size: 22, weight: .bold)).padding(.top, 6)
                        Text("240 pts · 60 ahead of Dakodoa").font(.system(size: 12, weight: .semibold)).opacity(0.9)
                        VStack(spacing: 8) {
                            ForEach(Array(Casalist.family.sorted { $0.points > $1.points }.prefix(3).enumerated()), id: \.element.id) { i, m in
                                HStack(spacing: 10) {
                                    Text("\(i+1)").font(.system(size: 11, weight: .heavy)).frame(width: 14).opacity(i == 0 ? 1 : 0.7)
                                    CLAvatar(m, size: 24, ring: false)
                                    Text(m.label).font(.system(size: 13, weight: .semibold))
                                    Spacer()
                                    Text("\(m.points) pts").font(.system(size: 13, weight: .bold)).monospacedDigit()
                                }
                            }
                        }
                        .padding(.top, 14)
                        HStack(spacing: 4) {
                            Text("See full leaderboard").font(.system(size: 12, weight: .bold))
                            Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                        }.padding(.top, 12)
                    }
                    .foregroundStyle(.white)
                    .padding(20)
                }
                .background(LinearGradient(colors: [P.terracotta, P.amber], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: P.terracotta.opacity(0.3), radius: 16, y: 8)
            }
        }

        private var modulesGrid: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("MODULES").font(.system(size: 11, weight: .bold)).tracking(1.2).foregroundStyle(P.textDim)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    tile(color: P.amber, symbol: "cart.fill", label: "Grocery", big: "\(Casalist.groceryCount)", suffix: "items", sub: Casalist.groceryPreview.prefix(3).joined(separator: " · "))
                    tile(color: P.sage,  symbol: "wrench.and.screwdriver.fill", label: "Maintenance", big: "\(Casalist.maintenanceCount)", suffix: "due", sub: Casalist.maintenanceNext, badge: "SOON")
                    tile(color: P.sky,   symbol: "checkmark.circle.fill", label: "My To-Do", big: "\(Casalist.todoCount)", suffix: "today", sub: Casalist.todoNext)
                    tile(color: P.rose,  symbol: "pin.fill", label: "Reminders", big: "\(Casalist.reminderCount)", suffix: "pinned", sub: Casalist.reminderPreview)
                }
            }
        }

        private func tile(color: Color, symbol: String, label: String, big: String, suffix: String, sub: String, badge: String? = nil) -> some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: symbol).font(.system(size: 16)).foregroundStyle(color)
                        .frame(width: 34, height: 34)
                        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.18)))
                    Spacer()
                    if let badge {
                        Text(badge).font(.system(size: 9, weight: .heavy)).foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(color))
                    }
                }.padding(.bottom, 10)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(big).font(.system(size: 26, weight: .bold)).foregroundStyle(color)
                    Text(suffix).font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textDim)
                }
                Text(label).font(.system(size: 13, weight: .semibold))
                Text(sub).font(.system(size: 11)).foregroundStyle(P.textMuted).lineLimit(2).frame(height: 28, alignment: .top)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(P.surface))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(P.border, lineWidth: 1))
        }

        private var activityCard: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("ACTIVITY").font(.system(size: 11, weight: .bold)).tracking(1.2).foregroundStyle(P.textDim)
                    Spacer()
                    Text("last 24 hours").font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textMuted)
                }
                VStack(spacing: 0) {
                    ForEach(Array(Casalist.activity.enumerated()), id: \.element.id) { i, a in
                        HStack(spacing: 12) {
                            if a.who == "system" {
                                Image(systemName: "bell.fill").font(.system(size: 12)).foregroundStyle(P.textDim)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(P.surfaceAlt))
                            } else {
                                CLAvatar(Casalist.member(a.who), size: 28)
                            }
                            (Text(a.who == "system" ? "Casalist" : Casalist.member(a.who).label)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(a.who == "system" ? P.textDim : Casalist.member(a.who).color)
                             + Text(" \(a.verb) ").font(.system(size: 13)).foregroundColor(P.textDim)
                             + Text(a.target).font(.system(size: 13, weight: .medium)).foregroundColor(P.text))
                                .lineLimit(2)
                            Spacer()
                            Text(a.when).font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted)
                        }
                        .padding(.vertical, 11)
                        .overlay(alignment: .top) {
                            if i > 0 { Rectangle().fill(P.border).frame(height: 1) }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(P.surface))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(P.border, lineWidth: 1))
            }
        }
    }

    // MARK: – Rewards ────────────────────────────────────────────────
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
            HStack {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold))
                        Text("Home").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(P.text)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(P.surface))
                    .overlay(Capsule().stroke(P.border, lineWidth: 1))
                }
                Spacer()
                Button { darkOverride = !dark } label: {
                    Image(systemName: dark ? "sun.max.fill" : "moon.fill").font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(P.text).frame(width: 36, height: 36)
                        .background(Circle().fill(P.surface)).overlay(Circle().stroke(P.border, lineWidth: 1))
                }
            }.padding(.horizontal, 16).padding(.bottom, 12)
        }

        private var content: some View {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CHORE REWARDS").font(.system(size: 12, weight: .bold)).tracking(1.2).foregroundStyle(P.terracotta)
                    Text("Leaderboard").font(.system(size: 28, weight: .bold))
                }
                podium
                standings
                goals
                availableChores
                recentRewards
            }
            .padding(.horizontal, 20).padding(.bottom, 28)
        }

        private var podium: some View {
            HStack(spacing: 14) {
                Circle().fill(Color.white.opacity(0.22)).frame(width: 70, height: 70)
                    .overlay(Image(systemName: "crown.fill").font(.system(size: 30)).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 2) {
                    Text("THIS MONTH").font(.system(size: 11, weight: .bold)).tracking(1.2).opacity(0.85)
                    Text(sorted[0].label).font(.system(size: 26, weight: .bold))
                    Text("\(sorted[0].points) pts · \(sorted[0].points - sorted[1].points) ahead").font(.system(size: 13, weight: .semibold)).opacity(0.95).padding(.top, 4)
                }
                Spacer()
            }
            .foregroundStyle(.white).padding(18)
            .background(LinearGradient(colors: [P.terracotta, P.amber], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: P.terracotta.opacity(0.3), radius: 16, y: 8)
        }

        private var standings: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("STANDINGS").font(.system(size: 11, weight: .bold)).tracking(1.2).foregroundStyle(P.textDim)
                VStack(spacing: 0) {
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { i, m in
                        HStack(spacing: 12) {
                            Text("\(i+1)").font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(i < 2 ? .white : P.text)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(i == 0 ? P.amber : (i == 1 ? P.textMuted : P.surfaceAlt)))
                            CLAvatar(m, size: 36)
                            VStack(spacing: 5) {
                                HStack {
                                    Text(m.label).font(.system(size: 14, weight: .bold))
                                    Spacer()
                                    Text("\(m.points) pts").font(.system(size: 14, weight: .bold)).foregroundStyle(m.color).monospacedDigit()
                                }
                                GeometryReader { g in
                                    RoundedRectangle(cornerRadius: 3).fill(P.surfaceAlt).overlay(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3).fill(m.color)
                                            .frame(width: g.size.width * CGFloat(m.points) / 240)
                                    }
                                }.frame(height: 5)
                            }
                        }.padding(.vertical, 10)
                        .overlay(alignment: .top) {
                            if i > 0 { Rectangle().fill(P.border).frame(height: 1) }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(P.surface))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(P.border, lineWidth: 1))
            }
        }

        private var goals: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("GOALS").font(.system(size: 11, weight: .bold)).tracking(1.2).foregroundStyle(P.textDim)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Casalist.goals) { g in
                        let m = Casalist.member(g.who)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                CLAvatar(m, size: 28)
                                Text(m.label).font(.system(size: 12, weight: .bold))
                            }.padding(.bottom, 4)
                            Text(g.label).font(.system(size: 13, weight: .semibold)).lineLimit(2)
                            Text("\(g.current) / \(g.target) pts").font(.system(size: 11)).foregroundStyle(P.textMuted)
                            GeometryReader { gg in
                                RoundedRectangle(cornerRadius: 3).fill(P.surfaceAlt).overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3).fill(m.color)
                                        .frame(width: gg.size.width * CGFloat(g.current) / CGFloat(g.target))
                                }
                            }.frame(height: 5).padding(.top, 4)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(P.surface))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(P.border, lineWidth: 1))
                    }
                }
            }
        }

        private var availableChores: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("AVAILABLE CHORES").font(.system(size: 11, weight: .bold)).tracking(1.2).foregroundStyle(P.textDim)
                    Spacer()
                    Text("Claim to earn").font(.system(size: 11, weight: .semibold)).foregroundStyle(P.terracotta)
                }
                VStack(spacing: 0) {
                    ForEach(Array(Casalist.availableChores.enumerated()), id: \.element.id) { i, c in
                        HStack(spacing: 12) {
                            Image(systemName: c.symbol).font(.system(size: 14)).foregroundStyle(P.terracotta)
                                .frame(width: 32, height: 32)
                                .background(RoundedRectangle(cornerRadius: 10).fill(P.terracotta.opacity(0.18)))
                            Text(c.label).font(.system(size: 14, weight: .semibold))
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill").font(.system(size: 11)).foregroundStyle(P.amber)
                                Text("\(c.points)").font(.system(size: 12, weight: .bold)).foregroundStyle(P.amber)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 3)
                            .background(Capsule().fill(P.amber.opacity(0.18)))
                            Button {} label: {
                                Text("Claim").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                                    .padding(.horizontal, 14).padding(.vertical, 6)
                                    .background(Capsule().fill(P.terracotta))
                            }
                        }.padding(.vertical, 10)
                        .overlay(alignment: .top) {
                            if i > 0 { Rectangle().fill(P.border).frame(height: 1) }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(P.surface))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(P.border, lineWidth: 1))
            }
        }

        private var recentRewards: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("RECENT REWARDS").font(.system(size: 11, weight: .bold)).tracking(1.2).foregroundStyle(P.textDim)
                VStack(spacing: 0) {
                    ForEach(Array(Casalist.recentRewards.enumerated()), id: \.element.id) { i, r in
                        let m = Casalist.member(r.who)
                        HStack(spacing: 12) {
                            CLAvatar(m, size: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.label).font(.system(size: 13, weight: .semibold))
                                (Text(m.label).font(.system(size: 11, weight: .bold)).foregroundColor(m.color)
                                 + Text(" · \(r.date)").font(.system(size: 11)).foregroundColor(P.textMuted))
                            }
                            Spacer()
                            Text("+\(r.points)").font(.system(size: 12, weight: .bold)).foregroundStyle(P.amber).monospacedDigit()
                        }.padding(.vertical, 11)
                        .overlay(alignment: .top) {
                            if i > 0 { Rectangle().fill(P.border).frame(height: 1) }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(P.surface))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(P.border, lineWidth: 1))
            }
        }
    }
}

#Preview("Home") { CasalistHearth.Home() }
#Preview("Rewards") { CasalistHearth.Rewards() }
