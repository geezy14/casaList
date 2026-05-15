//
//  CasalistShared.swift
//  Casalist — shared models used by all direction files (iOS 17+)
//
//  Drop in alongside any of the CasalistHearth.swift / Glasshouse / Cottage /
//  Notebook / Neon files. Each direction file expects these types.
//

import SwiftUI
import UIKit

// MARK: – Family
public struct CLFamilyMember: Identifiable, Hashable {
    public let id: String
    public let label: String
    public let role: String
    public let color: Color   // light-mode anchor; direction palettes may tint further
    public let points: Int
    public var photoBlob: Data? = nil

    public init(id: String, label: String, role: String, color: Color, points: Int, photoBlob: Data? = nil) {
        self.id = id
        self.label = label
        self.role = role
        self.color = color
        self.points = points
        self.photoBlob = photoBlob
    }
}

public enum Casalist {
    public static let family: [CLFamilyMember] = []
    public static func member(_ id: String) -> CLFamilyMember {
        family.first(where: { $0.id == id })
            ?? CLFamilyMember(id: id, label: "?", role: "", color: .gray, points: 0)
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
    public static let agenda: [CLAgendaItem] = []
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
    public static let activity: [CLActivity] = []
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
    public static let availableChores: [CLChore] = []
    public static let recentRewards: [CLReward] = []
    public static let goals: [CLGoal] = []
    // Module previews
    public static let groceryPreview: [String] = []
    public static let groceryCount   = 0
    public static let maintenanceNext = ""
    public static let maintenanceCount = 0
    public static let todoCount = 0
    public static let todoNext = ""
    public static let reminderCount = 0
    public static let reminderPreview = ""
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
        Group {
            if let data = member.photoBlob, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(String(member.label.prefix(1)).uppercased())
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(
                        LinearGradient(colors: [member.color, member.color.opacity(0.7)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(Circle())
            }
        }
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
