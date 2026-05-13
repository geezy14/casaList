//
//  CasalistCottage.swift
//  Casalist — "Cottage" direction (playful pastel family, iOS 17+)
//
//  Requires CasalistShared.swift.
//  Use as:  CasalistCottage.Home()  or  CasalistCottage.Rewards()
//

import SwiftUI

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
            HStack(spacing: 10) {
                HStack(spacing: -10) { ForEach(Casalist.family) { CLAvatar($0, size: 34) } }
                Spacer()
                Button { darkOverride = !dark } label: {
                    Image(systemName: dark ? "sun.max.fill" : "moon.fill").font(.system(size: 14)).foregroundStyle(P.text)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(P.surfaceAlt))
                }
                Button {} label: {
                    Image(systemName: "plus").font(.system(size: 19, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(P.peach))
                        .shadow(color: P.peach.opacity(0.4), radius: 8, y: 4)
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

        private var todayString: String {
            let f = DateFormatter()
            f.dateFormat = "EEEE · MMM d"
            return f.string(from: Date()).uppercased()
        }

        private var greetingCard: some View {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(todayString).font(.system(size: 11, weight: .heavy)).tracking(0.6).opacity(0.95)
                    Text("Hi geezy ✨").font(.system(size: 26, weight: .heavy)).padding(.top, 2)
                    Text("4 things happening today").font(.system(size: 13, weight: .semibold)).opacity(0.95)
                }
                .foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22).padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(isNight ? Color(rgb: 0x1F3A5E) : P.peach)
            .overlay(alignment: .topTrailing) {
                Text(isNight ? "🌙" : "☀️")
                    .font(.system(size: 80))
                    .opacity(0.9)
                    .offset(x: 22, y: -18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }

        private var stickyAgenda: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(Casalist.agenda.enumerated()), id: \.element.id) { i, a in
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: a.symbol).font(.system(size: 15)).foregroundStyle(a.color)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(a.color.opacity(0.2)))
                            Text(a.label).font(.system(size: 13, weight: .heavy)).lineLimit(2)
                            Text("\(a.time) \(a.ampm) · \(a.sub)").font(.system(size: 10, weight: .semibold)).foregroundStyle(P.textMuted)
                        }
                        .padding(14).frame(width: 130, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 20).fill(i % 2 == 0 ? P.surface : P.surfaceAlt))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(P.border, lineWidth: 1.5))
                        .rotationEffect(.degrees(i % 2 == 0 ? -1 : 1))
                    }
                }.padding(.vertical, 4)
            }
        }

        private var quickAdd: some View {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle").font(.system(size: 18)).foregroundStyle(P.textDim)
                TextField("What needs doing?", text: .constant(""))
                    .font(.system(size: 14, weight: .semibold))
                Button {} label: {
                    Image(systemName: "arrow.up").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white)
                        .frame(width: 32, height: 32).background(Circle().fill(P.peach))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 4).padding(.trailing, 4)
            .background(Capsule().fill(P.surface))
            .overlay(Capsule().stroke(P.border, lineWidth: 1.5))
        }

        private var star: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("THIS WEEK'S STAR ⭐").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                starCard
            }
        }

        private var starCard: some View {
                ZStack(alignment: .bottomTrailing) {
                    Text("🏆").font(.system(size: 80)).offset(x: -10, y: 30).opacity(0.2)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 14) {
                            CLAvatar(Casalist.member("donovan"), size: 56)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("1ST PLACE").font(.system(size: 11, weight: .heavy)).tracking(0.8).opacity(0.7)
                                Text("Donovan").font(.system(size: 22, weight: .heavy))
                                Text("240 pts · 60 ahead!").font(.system(size: 13, weight: .bold))
                            }
                        }
                        ForEach(Array(Casalist.family.sorted { $0.points > $1.points }.enumerated()), id: \.element.id) { i, m in
                            HStack(spacing: 10) {
                                Text(["🥇","🥈","🥉","4️⃣"][i]).font(.system(size: 14))
                                Text(m.label).font(.system(size: 13, weight: .heavy))
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

        private var tiles: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("AROUND THE HOUSE").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    tile(bg: P.mint,     emoji: "🛒", label: "Grocery",     big: "\(Casalist.groceryCount)", suffix: "items needed", sub: Casalist.groceryPreview.prefix(3).joined(separator: ", "))
                    tile(bg: P.lavender, emoji: "🔧", label: "Maintenance", big: "\(Casalist.maintenanceCount)", suffix: "due soon",     sub: Casalist.maintenanceNext, badge: "SOON")
                    tile(bg: P.sky, emoji: "✏️", label: "My To-Do", big: "\(Casalist.todoCount)", suffix: "for today", sub: Casalist.todoNext)
                    tile(bg: P.coral,    emoji: "📌", label: "Reminders",   big: "\(Casalist.reminderCount)", suffix: "pinned",       sub: "Wi-Fi, Pet sitter, +5 more")
                }
            }
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

        private var whatsNew: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("WHAT'S NEW 💬").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                VStack(spacing: 0) {
                    ForEach(Array(Casalist.activity.enumerated()), id: \.element.id) { i, a in
                        HStack(spacing: 12) {
                            if a.who == "system" {
                                Text("🔔").font(.system(size: 14))
                                    .frame(width: 30, height: 30).background(Circle().fill(P.surfaceAlt))
                            } else {
                                CLAvatar(Casalist.member(a.who), size: 30)
                            }
                            (Text(a.who == "system" ? "Casalist" : Casalist.member(a.who).label)
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundColor(a.who == "system" ? P.textDim : Casalist.member(a.who).color)
                             + Text(" \(a.verb) ").font(.system(size: 13)).foregroundColor(P.textDim)
                             + Text(a.target).font(.system(size: 13, weight: .semibold)))
                            .lineLimit(2)
                            Spacer()
                            Text(a.when).font(.system(size: 10, weight: .heavy)).foregroundStyle(P.textMuted)
                        }.padding(.vertical, 11)
                        .overlay(alignment: .top) {
                            if i > 0 {
                                Rectangle().fill(P.border).frame(height: 1)
                                    .overlay(Rectangle().fill(P.surface).frame(width: 4, height: 1))
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

    // MARK: – Rewards
    public struct Rewards: View {
        @Environment(\.colorScheme) private var sys
        @State private var darkOverride: Bool? = nil
        @Environment(\.dismiss) private var dismiss
        public var onHome: (() -> Void)?
        private var dark: Bool { darkOverride ?? (sys == .dark) }
        private var P: Palette { Palette.resolve(dark) }
        private var sorted: [CLFamilyMember] { Casalist.family.sorted { $0.points > $1.points } }
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
        }

        private var topBar: some View {
            HStack {
                Button { if let onHome { onHome() } else { dismiss() } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 13, weight: .bold))
                        Text("Home").font(.system(size: 13, weight: .heavy))
                    }.foregroundStyle(P.text).padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(P.surfaceAlt))
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
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(Array([sorted[1], sorted[0], sorted[2]].enumerated()), id: \.element.id) { idx, m in
                    let place = idx == 1 ? 1 : (idx == 0 ? 2 : 3)
                    let sz: CGFloat = place == 1 ? 64 : 50
                    let podH: CGFloat = place == 1 ? 68 : (place == 2 ? 48 : 36)
                    let podColor = place == 1 ? P.peach : (place == 2 ? P.coral : P.mint)
                    VStack(spacing: 6) {
                        CLAvatar(m, size: sz)
                        Text(m.label).font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(rgb: 0x3B2A22))
                        Text("\(m.points) pts").font(.system(size: 11, weight: .bold)).foregroundStyle(Color(rgb: 0x3B2A22).opacity(0.7))
                        Text(["🥇","🥈","🥉"][place - 1]).font(.system(size: 24, weight: .heavy))
                            .frame(maxWidth: .infinity).frame(height: podH)
                            .background(UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12).fill(podColor))
                    }.frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 18).padding(.top, 20).padding(.bottom, 0)
            .background(RoundedRectangle(cornerRadius: 32).fill(P.butter))
        }

        private var standings: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("STANDINGS").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                VStack(spacing: 0) {
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { i, m in
                        HStack(spacing: 12) {
                            Text(["🥇","🥈","🥉","4️⃣"][i]).font(.system(size: 20))
                            CLAvatar(m, size: 36)
                            VStack(spacing: 5) {
                                HStack {
                                    Text(m.label).font(.system(size: 14, weight: .heavy))
                                    Spacer()
                                    Text("\(m.points) pts").font(.system(size: 14, weight: .heavy)).foregroundStyle(m.color).monospacedDigit()
                                }
                                GeometryReader { g in
                                    RoundedRectangle(cornerRadius: 3).fill(P.surfaceAlt).overlay(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3).fill(m.color)
                                            .frame(width: g.size.width * CGFloat(m.points) / 240)
                                    }
                                }.frame(height: 6)
                            }
                        }.padding(.vertical, 11)
                        .overlay(alignment: .top) {
                            if i > 0 { Rectangle().fill(P.border).frame(height: 1) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .background(RoundedRectangle(cornerRadius: 24).fill(P.surface))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(P.border, lineWidth: 1.5))
            }
        }

        private var goals: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("SAVING UP FOR...").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Casalist.goals) { g in
                        let m = Casalist.member(g.who)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) { CLAvatar(m, size: 28); Text(m.label).font(.system(size: 12, weight: .heavy)) }
                            Text(g.label).font(.system(size: 13, weight: .bold))
                            Text("\(g.current) / \(g.target)").font(.system(size: 11, weight: .bold)).foregroundStyle(P.textMuted)
                            GeometryReader { gg in
                                RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.5)).overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4).fill(m.color)
                                        .frame(width: gg.size.width * CGFloat(g.current) / CGFloat(g.target))
                                }
                            }.frame(height: 8)
                        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 22).fill(m.color.opacity(0.15)))
                    }
                }
            }
        }

        private var available: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("EARN POINTS 💪").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                VStack(spacing: 8) {
                    ForEach(Casalist.availableChores) { c in
                        HStack(spacing: 12) {
                            Image(systemName: c.symbol).font(.system(size: 14)).foregroundStyle(P.peach)
                                .frame(width: 36, height: 36).background(Circle().fill(P.peach.opacity(0.2)))
                            Text(c.label).font(.system(size: 14, weight: .heavy))
                            Spacer()
                            Text("⭐ \(c.points)").font(.system(size: 12, weight: .heavy))
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Capsule().fill(P.butter))
                            Button {} label: {
                                Text("Claim").font(.system(size: 12, weight: .heavy)).foregroundStyle(.white)
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(Capsule().fill(P.peach))
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 20).fill(P.surface))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(P.border, lineWidth: 1.5))
                    }
                }
            }
        }
    }
}

extension CasalistCottage {

    public struct MyToDo: View {
        @Environment(\.colorScheme) private var sys
        @Environment(\.dismiss) private var dismiss
        @State private var darkOverride: Bool? = nil
        @State private var filter: String = "Today"
        public var onHome: (() -> Void)?
        private var dark: Bool { darkOverride ?? (sys == .dark) }
        private var P: Palette { Palette.resolve(dark) }
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
            .navigationBarBackButtonHidden()
            .toolbar(.hidden, for: .navigationBar)
        }

        private var topBar: some View {
            HStack {
                Button { if let onHome { onHome() } else { dismiss() } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 13, weight: .bold))
                        Text("Home").font(.system(size: 13, weight: .heavy))
                    }
                    .foregroundStyle(P.text).padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(P.surfaceAlt))
                }
                Spacer()
                Button { darkOverride = !dark } label: {
                    Image(systemName: dark ? "sun.max.fill" : "moon.fill").font(.system(size: 14)).foregroundStyle(P.text)
                        .frame(width: 38, height: 38).background(Circle().fill(P.surfaceAlt))
                }
                Button {} label: {
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
                    Circle().trim(from: 0, to: 0.33)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 76, height: 76)
                    VStack(spacing: 0) {
                        Text("33%").font(.system(size: 18, weight: .heavy))
                        Text("DONE").font(.system(size: 8, weight: .heavy)).tracking(0.8).opacity(0.85)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("MY TO-DO").font(.system(size: 11, weight: .heavy)).tracking(0.8).opacity(0.85)
                    Text("4 left for today").font(.system(size: 22, weight: .heavy))
                    Text("2 of 6 done · keep going!").font(.system(size: 12, weight: .semibold)).opacity(0.85)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(20)
            .background(P.coral)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }

        private var quickAdd: some View {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle").font(.system(size: 18)).foregroundStyle(P.textDim)
                TextField("Add to your list...", text: .constant(""))
                    .font(.system(size: 14, weight: .semibold))
                Button {} label: {
                    Image(systemName: "arrow.up").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white)
                        .frame(width: 32, height: 32).background(Circle().fill(P.peach))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 4).padding(.trailing, 4)
            .background(Capsule().fill(P.surface))
            .overlay(Capsule().stroke(P.border, lineWidth: 1.5))
        }

        private var filters: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    pill("Today", count: 4)
                    pill("This week", count: 4)
                    pill("All", count: 8)
                    pill("Errands", count: 2)
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
            VStack(alignment: .leading, spacing: 8) {
                Text("BY KIND").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        kindChip(emoji: "🛍️", label: "Errand", color: P.coral, count: 2)
                        kindChip(emoji: "💰", label: "Money", color: P.butter, count: 2)
                        kindChip(emoji: "🏠", label: "Home", color: P.mint, count: 1)
                        kindChip(emoji: "📝", label: "Note", color: P.lavender, count: 2)
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

        private struct TodoRow: Identifiable {
            let id = UUID()
            let title: String
            let dot: Color
            let when: String
            let tag: String
            let symbol: String
            let bg: Color
        }

        private var todayRows: [TodoRow] {
            [
                .init(title: "Pick up dry cleaning", dot: P.coral, when: "By 5pm", tag: "Errand", symbol: "bag.fill", bg: P.coral),
                .init(title: "Pay water bill", dot: P.peach, when: "Due today", tag: "Money", symbol: "dollarsign.circle.fill", bg: P.butter),
                .init(title: "Schedule plumber", dot: P.butter, when: "Call AM", tag: "Home", symbol: "house.fill", bg: P.mint),
                .init(title: "Reply to landlord", dot: P.mint, when: "5 min", tag: "Note", symbol: "envelope.fill", bg: P.lavender),
            ]
        }

        private var forToday: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("FOR TODAY ☀️").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                    Spacer()
                    Text("\(todayRows.count) items").font(.system(size: 11, weight: .heavy)).foregroundStyle(P.textMuted).padding(.trailing, 4)
                }
                VStack(spacing: 0) {
                    ForEach(Array(todayRows.enumerated()), id: \.element.id) { i, r in
                        HStack(spacing: 12) {
                            Circle().stroke(r.dot, lineWidth: 2).frame(width: 22, height: 22)
                            Image(systemName: r.symbol).font(.system(size: 14)).foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(RoundedRectangle(cornerRadius: 10).fill(r.bg))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(r.title).font(.system(size: 14, weight: .heavy))
                                HStack(spacing: 6) {
                                    Circle().fill(r.dot).frame(width: 6, height: 6)
                                    Text(r.when).font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textDim)
                                    Text("·").font(.system(size: 11)).foregroundStyle(P.textMuted)
                                    Text(r.tag).font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textDim)
                                }
                            }
                            Spacer()
                            CLAvatar(Casalist.member("geezy"), size: 26)
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

        private var recentlyDone: some View {
            HStack {
                Text("RECENTLY DONE 🎉").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(P.textDim).padding(.leading, 4)
                Spacer()
                Text("See all").font(.system(size: 11, weight: .heavy)).foregroundStyle(P.peach).padding(.trailing, 4)
            }
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
