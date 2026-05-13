//
//  CasalistShared.swift
//  Casalist — shared models used by all direction files (iOS 17+)
//
//  Drop in alongside any of the CasalistHearth.swift / Glasshouse / Cottage /
//  Notebook / Neon files. Each direction file expects these types.
//

import SwiftUI

// MARK: – Family
public struct CLFamilyMember: Identifiable, Hashable {
    public let id: String
    public let label: String
    public let role: String
    public let color: Color   // light-mode anchor; direction palettes may tint further
    public let points: Int
}

public enum Casalist {
    public static let family: [CLFamilyMember] = [
        .init(id: "geezy",   label: "Geezy",   role: "You",      color: Color(rgb: 0xC97357), points:  60),
        .init(id: "lorena",  label: "Lorena",  role: "Mom",      color: Color(rgb: 0x7A9070), points:  95),
        .init(id: "donovan", label: "Donovan", role: "Son",      color: Color(rgb: 0xE8A857), points: 240),
        .init(id: "dakodoa", label: "Dakodoa", role: "Daughter", color: Color(rgb: 0x6FB0CC), points: 180),
    ]
    public static func member(_ id: String) -> CLFamilyMember {
        family.first(where: { $0.id == id }) ?? family[0]
    }
}

// MARK: – Agenda
public struct CLAgendaItem: Identifiable {
    public let id = UUID()
    public let time: String, ampm: String
    public let label: String, sub: String
    public let symbol: String
    public let color: Color
}

extension Casalist {
    public static let agenda: [CLAgendaItem] = [
        .init(time: "9:30",  ampm: "AM", label: "Swim class",      sub: "Dakodoa",      symbol: "drop.fill",                color: Color(rgb: 0x6FB0CC)),
        .init(time: "12:00", ampm: "PM", label: "Grocery run",     sub: "Trader Joe's", symbol: "cart.fill",                color: Color(rgb: 0xE8A857)),
        .init(time: "4:00",  ampm: "PM", label: "Soccer practice", sub: "Donovan",      symbol: "soccerball",               color: Color(rgb: 0x7A9070)),
        .init(time: "7:00",  ampm: "PM", label: "Family dinner",   sub: "Everyone",     symbol: "fork.knife",               color: Color(rgb: 0xC97357)),
    ]
}

// MARK: – Activity
public struct CLActivity: Identifiable {
    public let id = UUID()
    public let who: String      // family id or "system"
    public let verb: String
    public let target: String
    public let when: String
}

extension Casalist {
    public static let activity: [CLActivity] = [
        .init(who: "lorena",  verb: "added",     target: "Olive oil to Grocery",     when: "5m"),
        .init(who: "donovan", verb: "completed", target: "Take out trash · +10 pts", when: "1h"),
        .init(who: "geezy",   verb: "marked",    target: "Pay electric bill done",   when: "3h"),
        .init(who: "system",  verb: "reminded",  target: "HVAC filter due in 3 days", when: "1d"),
        .init(who: "dakodoa", verb: "completed", target: "Feed Hops · +5 pts",       when: "1d"),
    ]
}

// MARK: – Rewards
public struct CLChore: Identifiable {
    public let id: String
    public let label: String
    public let points: Int
    public let symbol: String
}

public struct CLReward: Identifiable {
    public let id = UUID()
    public let who: String
    public let label: String
    public let points: Int
    public let date: String
}

public struct CLGoal: Identifiable {
    public let id = UUID()
    public let who: String
    public let label: String
    public let target: Int
    public let current: Int
}

extension Casalist {
    public static let availableChores: [CLChore] = [
        .init(id: "trash",   label: "Take out trash",   points: 10, symbol: "trash"),
        .init(id: "dishes",  label: "Empty dishwasher", points: 10, symbol: "circle.dashed"),
        .init(id: "lawn",    label: "Mow the lawn",     points: 25, symbol: "leaf"),
        .init(id: "walk",    label: "Walk Hops",        points: 10, symbol: "pawprint"),
        .init(id: "laundry", label: "Fold laundry",     points: 15, symbol: "tshirt"),
    ]
    public static let recentRewards: [CLReward] = [
        .init(who: "donovan", label: "Take out trash",     points: 10, date: "Today, 6:14 PM"),
        .init(who: "donovan", label: "Make bed",           points:  5, date: "Today, 8:02 AM"),
        .init(who: "dakodoa", label: "Feed Hops",          points:  5, date: "Today, 7:45 AM"),
        .init(who: "donovan", label: "Vacuum living room", points: 15, date: "Yesterday"),
        .init(who: "dakodoa", label: "Set the table",      points:  5, date: "Yesterday"),
        .init(who: "lorena",  label: "Plan weekly menu",   points: 10, date: "Sun"),
    ]
    public static let goals: [CLGoal] = [
        .init(who: "donovan", label: "Nintendo Switch game", target: 400, current: 240),
        .init(who: "dakodoa", label: "New art set",          target: 250, current: 180),
    ]
    // Module previews
    public static let groceryPreview = ["Milk", "Eggs", "Bread", "Olive oil", "Apples"]
    public static let groceryCount   = 12
    public static let maintenanceNext = "HVAC filter · in 3 days"
    public static let maintenanceCount = 3
    public static let todoCount = 4
    public static let todoNext = "Pick up dry cleaning"
    public static let reminderCount = 7
    public static let reminderPreview = "Wi-Fi · Pet sitter · Emergency"
    public static let quickAddCategories: [(label: String, symbol: String, color: Color)] = [
        ("Grocery",     "cart",                          Color(rgb: 0xE8A857)),
        ("To-do",       "checkmark.circle",              Color(rgb: 0x6FB0CC)),
        ("Maintenance", "wrench.and.screwdriver",        Color(rgb: 0x7A9070)),
        ("Chore",       "trophy",                        Color(rgb: 0xC97357)),
    ]
}

// MARK: – Family Avatar
public struct CLAvatar: View {
    public let member: CLFamilyMember
    public var size: CGFloat = 40
    public var ring: Bool = true
    public init(_ member: CLFamilyMember, size: CGFloat = 40, ring: Bool = true) {
        self.member = member; self.size = size; self.ring = ring
    }
    public var body: some View {
        Text(String(member.label.prefix(1)))
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [member.color, member.color.opacity(0.7)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(ring ? 0.18 : 0), lineWidth: 2))
            .shadow(color: ring ? member.color.opacity(0.35) : .clear, radius: 4, y: 2)
    }
}

// MARK: – Color hex helper (public for cross-file use)
public extension Color {
    init(rgb hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >>  8) & 0xFF) / 255,
                  blue:  Double( hex        & 0xFF) / 255,
                  opacity: alpha)
    }
}
