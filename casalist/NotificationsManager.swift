import Foundation
import UserNotifications
import SwiftData

enum NotificationsManager {
    @discardableResult
    static func requestAuth() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    static func currentStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Cancels notifications for tasks that no longer exist or aren't due,
    /// and schedules any newly-due ones. Called on app launch + after mutations.
    static func sync(tasks: [TaskItem]) async {
        let status = await currentStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else {
            await cancelAll()
            return
        }

        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let existingIds = Set(pending.map(\.identifier).filter { $0.hasPrefix("task-") })

        let now = Date()
        struct Plan { let id: String; let content: UNMutableNotificationContent; let trigger: UNNotificationTrigger }
        var plans: [Plan] = []
        for t in tasks {
            // Recurring reminders keep firing even when checked off; one-shot
            // tasks stop once completed.
            let isRecurring = !t.effectiveRepeatKind.isEmpty
            guard !t.isCompleted || isRecurring else { continue }
            let content = UNMutableNotificationContent()
            content.title = t.task
            content.body = subtitle(for: t)
            content.sound = .default
            for (suffix, trigger) in triggers(for: t, now: now) {
                let id = "task-\(Int(t.createdAt.timeIntervalSince1970 * 1000))-\(suffix)"
                plans.append(Plan(id: id, content: content, trigger: trigger))
            }
        }

        let neededIds = Set(plans.map(\.id))
        let toCancel = existingIds.subtracting(neededIds)
        if !toCancel.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(toCancel))
        }
        for plan in plans where !existingIds.contains(plan.id) {
            let request = UNNotificationRequest(identifier: plan.id, content: plan.content, trigger: plan.trigger)
            try? await center.add(request)
        }
    }

    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("task-") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Convenience that pulls tasks from a model context and calls sync.
    @MainActor
    static func syncFromContext(_ context: ModelContext) async {
        let descriptor = FetchDescriptor<TaskItem>()
        let tasks = (try? context.fetch(descriptor)) ?? []
        await sync(tasks: tasks)
    }

    /// Schedules notifications for a single task directly, without needing a
    /// fetch. Cancels any prior notifications belonging to this task first.
    @MainActor
    static func scheduleNow(for task: TaskItem) async {
        // Capture properties synchronously on MainActor.
        let baseId = "task-\(Int(task.createdAt.timeIntervalSince1970 * 1000))"
        let title = task.task
        let body = subtitle(for: task)
        let kind = task.effectiveRepeatKind
        let dueDate = task.dueDate
        let isCompleted = task.isCompleted

        let status = await currentStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }
        let center = UNUserNotificationCenter.current()

        // Remove anything already scheduled for this task.
        let pending = await center.pendingNotificationRequests()
        let toCancel = pending.map(\.identifier).filter { $0.hasPrefix(baseId) }
        if !toCancel.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: toCancel)
        }
        // Recurring reminders keep firing even when checked off; one-shots stop.
        let isRecurring = !kind.isEmpty
        guard !isCompleted || isRecurring else { return }

        let now = Date()
        let triggers = computeTriggers(kind: kind, dueDate: dueDate, now: now)
        for (suffix, trigger) in triggers {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let id = "\(baseId)-\(suffix)"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    private static func computeTriggers(kind: String, dueDate: Date?, now: Date) -> [(String, UNNotificationTrigger)] {
        let cal = Calendar.current
        switch kind {
        case "hourly":
            if let due = dueDate {
                var c = DateComponents()
                c.minute = cal.component(.minute, from: due)
                return [("hourly", UNCalendarNotificationTrigger(dateMatching: c, repeats: true))]
            }
            return [("hourly", UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: true))]
        case "every2h", "every4h", "every8h", "every12h":
            let step: Int = (kind == "every2h" ? 2 : kind == "every4h" ? 4 : kind == "every8h" ? 8 : 12)
            if let due = dueDate {
                let startHour = cal.component(.hour, from: due)
                let minute = cal.component(.minute, from: due)
                var out: [(String, UNNotificationTrigger)] = []
                for offset in stride(from: 0, to: 24, by: step) {
                    let hour = (startHour + offset) % 24
                    var c = DateComponents()
                    c.hour = hour
                    c.minute = minute
                    out.append(("\(kind)-h\(hour)", UNCalendarNotificationTrigger(dateMatching: c, repeats: true)))
                }
                return out
            }
            return [(kind, UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(step * 3600), repeats: true))]
        case "daily":
            guard let due = dueDate else { return [] }
            let c = cal.dateComponents([.hour, .minute], from: due)
            return [("daily", UNCalendarNotificationTrigger(dateMatching: c, repeats: true))]
        case "weekly":
            guard let due = dueDate else { return [] }
            let c = cal.dateComponents([.weekday, .hour, .minute], from: due)
            return [("weekly", UNCalendarNotificationTrigger(dateMatching: c, repeats: true))]
        case "monthly":
            guard let due = dueDate else { return [] }
            let c = cal.dateComponents([.day, .hour, .minute], from: due)
            return [("monthly", UNCalendarNotificationTrigger(dateMatching: c, repeats: true))]
        case "yearly":
            guard let due = dueDate else { return [] }
            let c = cal.dateComponents([.month, .day, .hour, .minute], from: due)
            return [("yearly", UNCalendarNotificationTrigger(dateMatching: c, repeats: true))]
        default:
            guard let due = dueDate, due > now else { return [] }
            let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: due)
            return [("once", UNCalendarNotificationTrigger(dateMatching: c, repeats: false))]
        }
    }

    private static func triggers(for t: TaskItem, now: Date) -> [(String, UNNotificationTrigger)] {
        let cal = Calendar.current
        let kind = t.effectiveRepeatKind
        switch kind {
        case "hourly":
            if let due = t.dueDate {
                var c = DateComponents()
                c.minute = cal.component(.minute, from: due)
                return [("hourly", UNCalendarNotificationTrigger(dateMatching: c, repeats: true))]
            }
            return [("hourly", UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: true))]
        case "every2h", "every4h", "every8h", "every12h":
            let step: Int = (kind == "every2h" ? 2 : kind == "every4h" ? 4 : kind == "every8h" ? 8 : 12)
            if let due = t.dueDate {
                let startHour = cal.component(.hour, from: due)
                let minute = cal.component(.minute, from: due)
                var out: [(String, UNNotificationTrigger)] = []
                for offset in stride(from: 0, to: 24, by: step) {
                    let hour = (startHour + offset) % 24
                    var c = DateComponents()
                    c.hour = hour
                    c.minute = minute
                    out.append(("\(kind)-h\(hour)", UNCalendarNotificationTrigger(dateMatching: c, repeats: true)))
                }
                return out
            }
            return [(kind, UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(step * 3600), repeats: true))]
        case "daily":
            guard let due = t.dueDate else { return [] }
            let c = cal.dateComponents([.hour, .minute], from: due)
            return [("daily", UNCalendarNotificationTrigger(dateMatching: c, repeats: true))]
        case "weekly":
            guard let due = t.dueDate else { return [] }
            let c = cal.dateComponents([.weekday, .hour, .minute], from: due)
            return [("weekly", UNCalendarNotificationTrigger(dateMatching: c, repeats: true))]
        case "monthly":
            guard let due = t.dueDate else { return [] }
            let c = cal.dateComponents([.day, .hour, .minute], from: due)
            return [("monthly", UNCalendarNotificationTrigger(dateMatching: c, repeats: true))]
        case "yearly":
            guard let due = t.dueDate else { return [] }
            let c = cal.dateComponents([.month, .day, .hour, .minute], from: due)
            return [("yearly", UNCalendarNotificationTrigger(dateMatching: c, repeats: true))]
        default:
            guard let due = t.dueDate, due > now else { return [] }
            let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: due)
            return [("once", UNCalendarNotificationTrigger(dateMatching: c, repeats: false))]
        }
    }

    private static func subtitle(for t: TaskItem) -> String {
        var parts: [String] = []
        if let assignee = t.assignee, !assignee.isEmpty { parts.append(assignee) }
        if !t.category.isEmpty { parts.append(t.category.capitalized) }
        return parts.isEmpty ? "Casalist reminder" : parts.joined(separator: " · ")
    }
}
