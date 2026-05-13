//
//  CasalistNeon.swift
//  Casalist — "Neon" direction (bold expressive color blocks, iOS 17+)
//
//  Requires CasalistShared.swift.
//  Use as:  CasalistNeon.Home()  or  CasalistNeon.Rewards()
//

import SwiftUI

public enum CasalistNeon {

    struct Palette {
        let bg, surface, surfaceAlt, surfaceHi, border, text, textDim, textMuted: Color
        let lime, magenta, blue, orange, cyan: Color
        let onLime: Color
        static func resolve(_ dark: Bool) -> Palette {
            dark ? Palette(
                bg: .black, surface: Color(rgb: 0x0E0E0E), surfaceAlt: Color(rgb: 0x1A1A1A), surfaceHi: Color(rgb: 0x252525),
                border: Color.white.opacity(0.10),
                text: .white, textDim: Color.white.opacity(0.6), textMuted: Color.white.opacity(0.4),
                lime: Color(rgb: 0xC0FF45), magenta: Color(rgb: 0xFF1FA7), blue: Color(rgb: 0x0085FF),
                orange: Color(rgb: 0xFF7A1F), cyan: Color(rgb: 0x1FFFE0),
                onLime: Color(rgb: 0x0E1A00)
            ) : Palette(
                bg: Color(rgb: 0xFAFAFA), surface: .white, surfaceAlt: Color(rgb: 0xF0F0F0), surfaceHi: Color(rgb: 0xE0E0E0),
                border: Color.black.opacity(0.10),
                text: .black, textDim: Color.black.opacity(0.6), textMuted: Color.black.opacity(0.4),
                lime: Color(rgb: 0x9AE600), magenta: Color(rgb: 0xE10090), blue: Color(rgb: 0x0066D9),
                orange: Color(rgb: 0xE55C00), cyan: Color(rgb: 0x0FBFB0),
                onLime: Color(rgb: 0x0E1A00)
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
                Text("● CASALIST").font(.system(size: 11, weight: .black)).tracking(1.5).foregroundStyle(P.lime)
                Spacer()
                Button { darkOverride = !dark } label: {
                    Image(systemName: dark ? "sun.max.fill" : "moon.fill").font(.system(size: 14)).foregroundStyle(P.text)
                        .frame(width: 36, height: 36).background(P.surfaceAlt)
                        .overlay(Rectangle().stroke(P.border, lineWidth: 1))
                }
                Button {} label: {
                    Image(systemName: "plus").font(.system(size: 18, weight: .black)).foregroundStyle(P.onLime)
                        .frame(width: 36, height: 36).background(P.lime)
                }
            }.padding(.horizontal, 16).padding(.bottom, 12)
        }

        private var content: some View {
            VStack(spacing: 0) {
                hero
                todayBlock.padding(.top, 10)
                quickAdd.padding(.top, 10)
                Group {
                    sectionHead("● LEADERBOARD").padding(.top, 18)
                    leaderboard.padding(.top, 4)
                    sectionHead("● MODULES").padding(.top, 18)
                    modulesGrid.padding(.top, 4)
                    sectionHead("● ACTIVITY").padding(.top, 18)
                    activityBlock.padding(.top, 4)
                }
            }.padding(.horizontal, 16).padding(.bottom, 28)
        }

        private var hero: some View {
            VStack(alignment: .leading, spacing: 0) {
                Text("TUE · MAY 12").font(.system(size: 11, weight: .black)).tracking(1.5)
                Text("HEY,\nGEEZY.").font(.system(size: 44, weight: .black)).tracking(-1.5).lineSpacing(-8).padding(.top, 4)
                HStack(spacing: -8) {
                    ForEach(Casalist.family) { CLAvatar($0, size: 32) }
                    Text("FAMILY OF 4").font(.system(size: 12, weight: .heavy)).padding(.leading, 18)
                }.padding(.top, 14)
            }
            .foregroundStyle(P.onLime).padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(P.lime)
        }

        private var todayBlock: some View {
            VStack(spacing: 0) {
                HStack {
                    Text("TODAY · \(Casalist.agenda.count) EVENTS").font(.system(size: 11, weight: .black)).tracking(1.5).foregroundStyle(P.textDim)
                    Spacer()
                }.padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 6)
                ForEach(Array(Casalist.agenda.enumerated()), id: \.element.id) { i, a in
                    HStack(spacing: 12) {
                        Image(systemName: a.symbol).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 32, height: 32).background(a.color)
                        Text(a.label).font(.system(size: 14, weight: .heavy))
                        Spacer()
                        Text("\(a.time) \(a.ampm)").font(.system(size: 12, weight: .black)).monospacedDigit()
                    }.padding(.horizontal, 14).padding(.vertical, 8)
                    .overlay(alignment: .top) {
                        if i > 0 { Rectangle().fill(P.border).frame(height: 1) }
                    }
                }
                Color.clear.frame(height: 8)
            }
            .background(P.surface).overlay(Rectangle().stroke(P.border, lineWidth: 1))
        }

        private var quickAdd: some View {
            HStack(spacing: 10) {
                Image(systemName: "plus").font(.system(size: 14, weight: .heavy)).foregroundStyle(P.text)
                TextField("", text: .constant(""), prompt: Text("ADD A TASK").foregroundStyle(P.textMuted)
                    .font(.system(size: 13, weight: .heavy)).tracking(0.5))
                    .font(.system(size: 13, weight: .heavy)).tracking(0.5)
                Button {} label: {
                    Text("ADD").font(.system(size: 11, weight: .black)).tracking(1).foregroundStyle(P.bg)
                        .padding(.horizontal, 14).padding(.vertical, 8).background(P.text)
                }
            }.padding(.horizontal, 14).padding(.vertical, 6).padding(.leading, 0)
            .background(P.surface).overlay(Rectangle().stroke(P.border, lineWidth: 1))
        }

        private func sectionHead(_ s: String) -> some View {
            Text(s).font(.system(size: 11, weight: .black)).tracking(1.5).foregroundStyle(P.textDim)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 2)
        }

        private var leaderboard: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text("1ST PLACE").font(.system(size: 11, weight: .black)).tracking(1.5).opacity(0.85)
                Text("DONOVAN").font(.system(size: 36, weight: .black)).tracking(-1.5).padding(.top, 4)
                Text("240 PTS · +60 AHEAD").font(.system(size: 14, weight: .heavy)).padding(.top, 4)
                VStack(spacing: 6) {
                    ForEach(Casalist.family.sorted { $0.points > $1.points }) { m in
                        HStack(spacing: 8) {
                            Text("#\(Casalist.family.sorted { $0.points > $1.points }.firstIndex(where: { $0.id == m.id })! + 1)")
                                .font(.system(size: 11, weight: .black)).frame(width: 18, alignment: .leading)
                            Text(m.label.uppercased()).font(.system(size: 13, weight: .heavy)).frame(maxWidth: .infinity, alignment: .leading)
                            GeometryReader { g in
                                Rectangle().fill(Color.black.opacity(0.25)).overlay(alignment: .leading) {
                                    Rectangle().fill(.white).frame(width: g.size.width * CGFloat(m.points) / 240)
                                }
                            }.frame(width: 100, height: 5)
                            Text("\(m.points)").font(.system(size: 13, weight: .black)).monospacedDigit().frame(width: 32, alignment: .trailing)
                        }
                    }
                }.padding(.top, 14)
            }
            .foregroundStyle(.white).padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(P.magenta)
        }

        private var modulesGrid: some View {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                tile(bg: P.orange, fg: .white,                icon: "cart.fill",                  label: "GROCERY",   big: "12", suffix: "ITEMS", sub: "MILK · EGGS · BREAD")
                tile(bg: P.blue,   fg: .white,                icon: "wrench.and.screwdriver.fill", label: "MAINT",     big: "3",  suffix: "DUE",   sub: "HVAC FILTER · IN 3 DAYS", badge: "SOON")
                tile(bg: P.cyan,   fg: .black,                icon: "checkmark.circle.fill",      label: "MY TO-DO",  big: "4",  suffix: "TODAY", sub: "PICK UP DRY CLEANING")
                tile(bg: P.lime,   fg: P.onLime,              icon: "pin.fill",                   label: "REMINDERS", big: "7",  suffix: "PINNED", sub: "WI-FI · PETS · 911")
            }
        }

        private func tile(bg: Color, fg: Color, icon: String, label: String, big: String, suffix: String, sub: String, badge: String? = nil) -> some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(fg)
                    Spacer()
                    if let badge {
                        Text(badge).font(.system(size: 9, weight: .black)).foregroundStyle(bg)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(fg)
                    }
                }.padding(.bottom, 6)
                Text(big).font(.system(size: 42, weight: .black)).tracking(-1.5)
                Text(suffix).font(.system(size: 10, weight: .black)).tracking(1.2).opacity(0.9).padding(.top, 2)
                Text(label).font(.system(size: 12, weight: .heavy)).tracking(0.5).padding(.top, 6)
                Text(sub).font(.system(size: 10, weight: .bold)).opacity(0.8).lineLimit(2).frame(height: 24, alignment: .top).padding(.top, 4)
            }
            .foregroundStyle(fg).padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bg)
        }

        private var activityBlock: some View {
            VStack(spacing: 0) {
                ForEach(Array(Casalist.activity.enumerated()), id: \.element.id) { i, a in
                    HStack(spacing: 10) {
                        if a.who == "system" {
                            Text("🔔").font(.system(size: 11)).frame(width: 26, height: 26).background(P.surfaceAlt)
                        } else {
                            CLAvatar(Casalist.member(a.who), size: 26)
                        }
                        (Text(a.who == "system" ? "SYSTEM" : Casalist.member(a.who).label.uppercased())
                            .font(.system(size: 12, weight: .black)).tracking(0.4)
                         + Text(" \(a.verb) ").font(.system(size: 12)).foregroundColor(P.textDim)
                         + Text(a.target).font(.system(size: 12, weight: .heavy)))
                        .lineLimit(2)
                        Spacer()
                        Text(a.when.uppercased()).font(.system(size: 10, weight: .black)).foregroundStyle(P.textMuted)
                    }.padding(.horizontal, 14).padding(.vertical, 11)
                    .overlay(alignment: .top) {
                        if i > 0 { Rectangle().fill(P.border).frame(height: 1) }
                    }
                }
            }
            .background(P.surface).overlay(Rectangle().stroke(P.border, lineWidth: 1))
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
            }.foregroundStyle(P.text).preferredColorScheme(dark ? .dark : .light)
        }

        private var topBar: some View {
            HStack(spacing: 8) {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .black))
                        Text("HOME").font(.system(size: 11, weight: .black)).tracking(1)
                    }.foregroundStyle(P.text).padding(.horizontal, 14).padding(.vertical, 7)
                    .overlay(Rectangle().stroke(P.border, lineWidth: 1))
                }
                Spacer()
                Button { darkOverride = !dark } label: {
                    Image(systemName: dark ? "sun.max.fill" : "moon.fill").font(.system(size: 14)).foregroundStyle(P.text)
                        .frame(width: 36, height: 36).background(P.surfaceAlt)
                        .overlay(Rectangle().stroke(P.border, lineWidth: 1))
                }
            }.padding(.horizontal, 16).padding(.bottom, 12)
        }

        private var content: some View {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("● LEADERBOARD").font(.system(size: 11, weight: .black)).tracking(1.5).foregroundStyle(P.lime)
                    Text("CHORE\nREWARDS.").font(.system(size: 44, weight: .black)).tracking(-1.5).lineSpacing(-10).padding(.top, 4)
                }.padding(.horizontal, 2)
                winner.padding(.top, 14)
                sectionHead("● STANDINGS").padding(.top, 18)
                standings.padding(.top, 8)
                sectionHead("● GOALS").padding(.top, 18)
                goals.padding(.top, 8)
                sectionHead("● EARN POINTS").padding(.top, 18)
                available.padding(.top, 8)
            }.padding(.horizontal, 16).padding(.bottom, 28)
        }

        private func sectionHead(_ s: String) -> some View {
            Text(s).font(.system(size: 11, weight: .black)).tracking(1.5).foregroundStyle(P.textDim)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 2)
        }

        private var winner: some View {
            HStack(spacing: 16) {
                CLAvatar(sorted[0], size: 72)
                VStack(alignment: .leading, spacing: 2) {
                    Text("1ST PLACE · THIS MONTH").font(.system(size: 11, weight: .black)).tracking(1.5).opacity(0.85)
                    Text(sorted[0].label.uppercased()).font(.system(size: 30, weight: .black)).tracking(-1)
                    Text("\(sorted[0].points) PTS · +\(sorted[0].points - sorted[1].points) AHEAD").font(.system(size: 14, weight: .heavy)).padding(.top, 4)
                }
                Spacer()
            }.foregroundStyle(.white).padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(P.magenta)
        }

        private var standings: some View {
            VStack(spacing: 0) {
                ForEach(Array(sorted.enumerated()), id: \.element.id) { i, m in
                    HStack(spacing: 12) {
                        Text("\(i+1)").font(.system(size: 22, weight: .black))
                            .foregroundStyle(i == 0 ? P.lime : P.textDim).monospacedDigit().frame(width: 32, alignment: .leading)
                        CLAvatar(m, size: 36)
                        VStack(spacing: 6) {
                            HStack {
                                Text(m.label.uppercased()).font(.system(size: 14, weight: .black)).tracking(0.4)
                                Spacer()
                                Text("\(m.points)").font(.system(size: 14, weight: .black)).monospacedDigit()
                            }
                            GeometryReader { g in
                                Rectangle().fill(P.surfaceAlt).overlay(alignment: .leading) {
                                    Rectangle().fill(m.color).frame(width: g.size.width * CGFloat(m.points) / 240)
                                }
                            }.frame(height: 4)
                        }
                    }.padding(14)
                    .overlay(alignment: .top) {
                        if i > 0 { Rectangle().fill(P.border).frame(height: 1) }
                    }
                }
            }.background(P.surface).overlay(Rectangle().stroke(P.border, lineWidth: 1))
        }

        private var goals: some View {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(Array(Casalist.goals.enumerated()), id: \.element.id) { i, g in
                    let m = Casalist.member(g.who)
                    let bg = i == 0 ? P.cyan : P.orange
                    VStack(alignment: .leading, spacing: 4) {
                        Text(m.label.uppercased()).font(.system(size: 11, weight: .black)).tracking(1)
                        Text(g.label.uppercased()).font(.system(size: 16, weight: .black)).lineLimit(2).padding(.top, 4)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(g.current)").font(.system(size: 24, weight: .black))
                            Text("/\(g.target)").font(.system(size: 14)).opacity(0.6)
                        }.padding(.top, 8)
                        GeometryReader { gg in
                            Rectangle().fill(Color.black.opacity(0.2)).overlay(alignment: .leading) {
                                Rectangle().fill(.black).frame(width: gg.size.width * CGFloat(g.current) / CGFloat(g.target))
                            }
                        }.frame(height: 6).padding(.top, 6)
                    }
                    .foregroundStyle(.black).padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(bg)
                }
            }
        }

        private var available: some View {
            VStack(spacing: 0) {
                ForEach(Array(Casalist.availableChores.enumerated()), id: \.element.id) { i, c in
                    HStack(spacing: 12) {
                        Image(systemName: c.symbol).font(.system(size: 15, weight: .bold)).foregroundStyle(P.onLime)
                            .frame(width: 30, height: 30).background(P.lime)
                        Text(c.label.uppercased()).font(.system(size: 13, weight: .heavy)).tracking(0.3)
                        Spacer()
                        Text("+\(c.points)").font(.system(size: 13, weight: .black)).foregroundStyle(P.lime).monospacedDigit()
                        Button {} label: {
                            Text("CLAIM").font(.system(size: 11, weight: .black)).tracking(0.8).foregroundStyle(P.bg)
                                .padding(.horizontal, 12).padding(.vertical, 6).background(P.text)
                        }
                    }.padding(14)
                    .overlay(alignment: .top) {
                        if i > 0 { Rectangle().fill(P.border).frame(height: 1) }
                    }
                }
            }.background(P.surface).overlay(Rectangle().stroke(P.border, lineWidth: 1))
        }
    }
}

#Preview("Home") { CasalistNeon.Home() }
#Preview("Rewards") { CasalistNeon.Rewards() }
