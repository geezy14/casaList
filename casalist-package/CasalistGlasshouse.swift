//
//  CasalistGlasshouse.swift
//  Casalist — "Glasshouse" direction (fintech glass, iOS 26+)
//
//  Requires CasalistShared.swift. Uses iOS 26 .glassEffect / glassProminent.
//  Use as:  CasalistGlasshouse.Home()  or  CasalistGlasshouse.Rewards()
//

import SwiftUI

public enum CasalistGlasshouse {

    struct Palette {
        let bg, glass, glassHi, border, text, textDim, textMuted: Color
        let blue, purple, cyan, pink, mint, amber, rose: Color

        static func resolve(_ dark: Bool) -> Palette {
            dark ? Palette(
                bg: Color(rgb: 0x0A0A14), glass: Color.white.opacity(0.06), glassHi: Color.white.opacity(0.10),
                border: Color.white.opacity(0.08),
                text: .white, textDim: Color.white.opacity(0.6), textMuted: Color.white.opacity(0.4),
                blue: Color(rgb: 0x5B9BFF), purple: Color(rgb: 0x9D7BFF), cyan: Color(rgb: 0x5CE1FF),
                pink: Color(rgb: 0xFF6FB5), mint: Color(rgb: 0x5EE6A6), amber: Color(rgb: 0xFFC85A), rose: Color(rgb: 0xFF5A78)
            ) : Palette(
                bg: Color(rgb: 0xF2F2F7), glass: Color.white.opacity(0.7), glassHi: Color.white.opacity(0.85),
                border: Color.black.opacity(0.08),
                text: Color(rgb: 0x0A0A14), textDim: Color(rgb: 0x0A0A14).opacity(0.6), textMuted: Color(rgb: 0x0A0A14).opacity(0.4),
                blue: Color(rgb: 0x2F7BF6), purple: Color(rgb: 0x7B5CE3), cyan: Color(rgb: 0x1FC1E0),
                pink: Color(rgb: 0xE5499E), mint: Color(rgb: 0x36C988), amber: Color(rgb: 0xE8A422), rose: Color(rgb: 0xE83A5C)
            )
        }
    }

    // Aurora background
    private struct AuroraBG: View {
        let P: Palette
        let visible: Bool
        var body: some View {
            ZStack {
                if visible {
                    blob(P.purple.opacity(0.55), 360, x: -120, y: -260)
                    blob(P.blue.opacity(0.44),   380, x: 220,  y: -40)
                    blob(P.cyan.opacity(0.26),   320, x: -130, y: 260)
                }
            }.blur(radius: 30)
        }
        private func blob(_ c: Color, _ s: CGFloat, x: CGFloat, y: CGFloat) -> some View {
            Circle().fill(RadialGradient(colors: [c, .clear], center: .center, startRadius: 0, endRadius: s * 0.6))
                .frame(width: s, height: s).offset(x: x, y: y)
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
                AuroraBG(P: P, visible: dark).ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                    ScrollView { content }.scrollIndicators(.hidden)
                }
            }
            .foregroundStyle(P.text)
            .preferredColorScheme(dark ? .dark : .light)
        }

        private var topBar: some View {
            HStack(spacing: 10) {
                HStack(spacing: -8) { ForEach(Casalist.family) { CLAvatar($0, size: 32) } }
                Spacer()
                Button { darkOverride = !dark } label: {
                    Image(systemName: dark ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(P.text)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glass).clipShape(Circle())
                Button {} label: {
                    Image(systemName: "plus").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(LinearGradient(colors: [P.blue, P.purple], startPoint: .topLeading, endPoint: .bottomTrailing)))
                        .shadow(color: P.blue.opacity(0.5), radius: 10, y: 4)
                }
            }.padding(.horizontal, 20).padding(.bottom, 12)
        }

        private var content: some View {
            VStack(spacing: 12) {
                greetingCard
                quickAdd
                featuredRewards
                modules
                activity
            }.padding(.horizontal, 16).padding(.bottom, 28)
        }

        private var greetingCard: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tuesday, May 12").font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textDim)
                HStack(spacing: 0) {
                    Text("Good evening, ").font(.system(size: 26, weight: .bold))
                    Text("geezy").font(.system(size: 26, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [P.blue, P.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                HStack(spacing: 10) {
                    ForEach(Casalist.agenda) { a in
                        VStack(spacing: 4) {
                            Image(systemName: a.symbol).font(.system(size: 13)).foregroundStyle(a.color)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(a.color.opacity(0.18)))
                            Text(a.time).font(.system(size: 10, weight: .heavy)).monospacedDigit()
                            Text(a.ampm).font(.system(size: 9, weight: .semibold)).foregroundStyle(P.textDim)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(P.glassHi))
                    }
                }
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").font(.system(size: 11)).foregroundStyle(P.amber)
                    Text("\(Casalist.agenda[0].label) in 2h · \(Casalist.agenda.count) events today")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(P.textDim)
                }
            }
            .padding(18)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
        }

        private var quickAdd: some View {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle").font(.system(size: 17)).foregroundStyle(P.textDim)
                TextField("Add a task, item, chore…", text: .constant(""))
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(P.text)
                Image(systemName: "mic.fill").font(.system(size: 13)).foregroundStyle(P.textDim)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(P.glassHi))
            }
            .padding(.horizontal, 14).padding(.vertical, 6).padding(.leading, 2)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
        }

        private var featuredRewards: some View {
            Button {} label: {
                ZStack(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "trophy.fill").font(.system(size: 14))
                            Text("CHORE REWARDS").font(.system(size: 11, weight: .bold)).tracking(1.2)
                            Spacer()
                            Text("This month").font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 10).padding(.vertical, 3)
                                .background(Capsule().fill(Color.white.opacity(0.18)))
                        }
                        HStack(spacing: 14) {
                            CLAvatar(Casalist.member("donovan"), size: 56)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Donovan leads with 240 pts").font(.system(size: 19, weight: .bold))
                                Text("60 ahead of Dakodoa · 145 ahead of Lorena").font(.system(size: 12, weight: .semibold)).opacity(0.9)
                            }
                        }
                        VStack(spacing: 6) {
                            ForEach(Casalist.family.sorted { $0.points > $1.points }) { m in
                                HStack(spacing: 8) {
                                    Text(m.label).font(.system(size: 10, weight: .semibold)).opacity(0.85).frame(width: 50, alignment: .leading)
                                    GeometryReader { g in
                                        RoundedRectangle(cornerRadius: 3).fill(Color.black.opacity(0.25)).overlay(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.85))
                                                .frame(width: g.size.width * CGFloat(m.points) / 240)
                                        }
                                    }.frame(height: 5)
                                    Text("\(m.points)").font(.system(size: 11, weight: .bold)).frame(width: 32, alignment: .trailing).monospacedDigit()
                                }
                            }
                        }.padding(.top, 6)
                    }.foregroundStyle(.white).padding(20)
                }
                .background(LinearGradient(colors: [P.purple, P.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: P.purple.opacity(0.3), radius: 16, y: 8)
            }.buttonStyle(.plain)
        }

        private var modules: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("MODULES").font(.system(size: 11, weight: .bold)).tracking(1.2).foregroundStyle(P.textDim)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    tile(color: P.amber, symbol: "cart.fill",                  label: "Grocery",     big: "\(Casalist.groceryCount)", suffix: "items", sub: Casalist.groceryPreview.prefix(3).joined(separator: " · "))
                    tile(color: P.mint,  symbol: "wrench.and.screwdriver.fill", label: "Maintenance", big: "\(Casalist.maintenanceCount)", suffix: "due", sub: Casalist.maintenanceNext, badge: "SOON")
                    tile(color: P.cyan,  symbol: "checkmark.circle.fill",      label: "My To-Do",    big: "\(Casalist.todoCount)", suffix: "today", sub: Casalist.todoNext)
                    tile(color: P.pink,  symbol: "pin.fill",                   label: "Reminders",   big: "\(Casalist.reminderCount)", suffix: "pinned", sub: Casalist.reminderPreview)
                }
            }
        }

        private func tile(color: Color, symbol: String, label: String, big: String, suffix: String, sub: String, badge: String? = nil) -> some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: symbol).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(RoundedRectangle(cornerRadius: 10).fill(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                        .shadow(color: color.opacity(0.4), radius: 8, y: 4)
                    Spacer()
                    if let badge {
                        Text(badge).font(.system(size: 9, weight: .heavy)).foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(color))
                            .shadow(color: color.opacity(0.6), radius: 6)
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
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
        }

        private var activity: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("ACTIVITY").font(.system(size: 11, weight: .bold)).tracking(1.2).foregroundStyle(P.textDim)
                    Spacer()
                    Text("last 24h").font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textMuted)
                }
                VStack(spacing: 0) {
                    ForEach(Array(Casalist.activity.enumerated()), id: \.element.id) { i, a in
                        HStack(spacing: 12) {
                            if a.who == "system" {
                                Image(systemName: "bell.fill").font(.system(size: 12)).foregroundStyle(P.textDim)
                                    .frame(width: 28, height: 28).background(Circle().fill(P.glassHi))
                            } else {
                                CLAvatar(Casalist.member(a.who), size: 28)
                            }
                            (Text(a.who == "system" ? "Casalist" : Casalist.member(a.who).label)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(a.who == "system" ? P.textDim : Casalist.member(a.who).color)
                             + Text(" \(a.verb) ").font(.system(size: 13)).foregroundColor(P.textDim)
                             + Text(a.target).font(.system(size: 13, weight: .medium)))
                            .lineLimit(2)
                            Spacer()
                            Text(a.when).font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted)
                        }.padding(.vertical, 11)
                        .overlay(alignment: .top) {
                            if i > 0 { Rectangle().fill(P.border).frame(height: 1) }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
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
                AuroraBG(P: P, visible: dark).ignoresSafeArea()
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
                    }.foregroundStyle(P.text).padding(.horizontal, 12).padding(.vertical, 7)
                }.buttonStyle(.glass).clipShape(Capsule())
                Spacer()
                Button { darkOverride = !dark } label: {
                    Image(systemName: dark ? "sun.max.fill" : "moon.fill").font(.system(size: 14)).foregroundStyle(P.text)
                        .frame(width: 36, height: 36)
                }.buttonStyle(.glass).clipShape(Circle())
            }.padding(.horizontal, 16).padding(.bottom, 12)
        }

        private var content: some View {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CHORE REWARDS").font(.system(size: 11, weight: .bold)).tracking(1.5)
                        .foregroundStyle(LinearGradient(colors: [P.blue, P.purple], startPoint: .leading, endPoint: .trailing))
                    Text("Leaderboard").font(.system(size: 28, weight: .bold))
                }.padding(.leading, 4)
                podium
                standings
                goals
                availableChores
                recent
            }.padding(.horizontal, 16).padding(.bottom, 28)
        }

        private var podium: some View {
            HStack(spacing: 16) {
                ZStack(alignment: .bottomLeading) {
                    CLAvatar(sorted[0], size: 72)
                    Image(systemName: "crown.fill").font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(rgb: 0x1A0C00))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(P.amber)).overlay(Circle().stroke(.white, lineWidth: 2.5))
                        .shadow(color: P.amber.opacity(0.6), radius: 8)
                        .offset(x: -4, y: 4)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("1ST PLACE").font(.system(size: 11, weight: .bold)).tracking(1.2).opacity(0.85)
                    Text(sorted[0].label).font(.system(size: 26, weight: .bold))
                    Text("\(sorted[0].points) pts · +\(sorted[0].points - sorted[1].points) ahead").font(.system(size: 14, weight: .bold)).opacity(0.95).padding(.top, 4)
                }
                Spacer()
            }
            .foregroundStyle(.white).padding(20)
            .background(LinearGradient(colors: [P.purple, P.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: P.purple.opacity(0.3), radius: 16, y: 8)
        }

        private var standings: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("STANDINGS").font(.system(size: 11, weight: .bold)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                VStack(spacing: 0) {
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { i, m in
                        HStack(spacing: 12) {
                            Text("\(i+1)").font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(i == 0 ? Color(rgb: 0x1A0C00) : (i == 1 ? Color(rgb: 0x002A30) : P.text))
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(i == 0 ? P.amber : (i == 1 ? P.cyan : P.glassHi)))
                            CLAvatar(m, size: 36)
                            VStack(spacing: 5) {
                                HStack {
                                    Text(m.label).font(.system(size: 14, weight: .bold))
                                    Spacer()
                                    Text("\(m.points)").font(.system(size: 14, weight: .bold)).foregroundStyle(m.color).monospacedDigit()
                                }
                                GeometryReader { g in
                                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.06)).overlay(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(LinearGradient(colors: [m.color, m.color.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                                            .frame(width: g.size.width * CGFloat(m.points) / 240)
                                            .shadow(color: m.color.opacity(0.4), radius: 4)
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
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
            }
        }

        private var goals: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("GOALS").font(.system(size: 11, weight: .bold)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Casalist.goals) { g in
                        let m = Casalist.member(g.who)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) { CLAvatar(m, size: 28); Text(m.label).font(.system(size: 12, weight: .bold)) }
                            Text(g.label).font(.system(size: 13, weight: .semibold)).lineLimit(2)
                            Text("\(g.current) / \(g.target) pts").font(.system(size: 11)).foregroundStyle(P.textMuted)
                            GeometryReader { gg in
                                RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.06)).overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3).fill(m.color)
                                        .frame(width: gg.size.width * CGFloat(g.current) / CGFloat(g.target))
                                }
                            }.frame(height: 5).padding(.top, 4)
                        }
                        .padding(14)
                        .glassEffect(.regular, in: .rect(cornerRadius: 18))
                    }
                }
            }
        }

        private var availableChores: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("AVAILABLE CHORES").font(.system(size: 11, weight: .bold)).tracking(1.2).foregroundStyle(P.textDim)
                    Spacer()
                    Text("Claim to earn").font(.system(size: 11, weight: .bold)).foregroundStyle(P.blue)
                }.padding(.horizontal, 4)
                VStack(spacing: 0) {
                    ForEach(Array(Casalist.availableChores.enumerated()), id: \.element.id) { i, c in
                        HStack(spacing: 12) {
                            Image(systemName: c.symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(RoundedRectangle(cornerRadius: 10).fill(LinearGradient(colors: [P.blue, P.purple], startPoint: .topLeading, endPoint: .bottomTrailing)))
                            Text(c.label).font(.system(size: 14, weight: .semibold))
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill").font(.system(size: 11)).foregroundStyle(P.amber)
                                Text("\(c.points)").font(.system(size: 12, weight: .bold)).foregroundStyle(P.amber)
                            }.padding(.horizontal, 10).padding(.vertical, 3)
                            .background(Capsule().fill(P.amber.opacity(0.18)))
                            Button {} label: {
                                Text("Claim").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                                    .padding(.horizontal, 14).padding(.vertical, 6)
                                    .background(Capsule().fill(LinearGradient(colors: [P.blue, P.purple], startPoint: .leading, endPoint: .trailing)))
                            }
                        }.padding(.vertical, 10)
                        .overlay(alignment: .top) {
                            if i > 0 { Rectangle().fill(P.border).frame(height: 1) }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
            }
        }

        private var recent: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("RECENT REWARDS").font(.system(size: 11, weight: .bold)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
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
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
            }
        }
    }
}

#Preview("Home") { CasalistGlasshouse.Home() }
#Preview("Rewards") { CasalistGlasshouse.Rewards() }
