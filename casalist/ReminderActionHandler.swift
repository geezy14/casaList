import Foundation
import CoreData
import UserNotifications

/// Routes lock-screen action button taps (Mark done / Snooze 15m /
/// Snooze 1h / Snooze until tomorrow) on reminder notifications. Runs
/// on the main actor because Core Data fetch / save is bound to the
/// shared stack's main context.
@MainActor
enum ReminderActionHandler {
    /// Identifier set on each snooze one-shot trigger so successive
    /// snoozes replace, not stack.
    private static func snoozeID(for uid: String) -> String { "reminder-snooze-\(uid)" }

    static func handle(actionID: String, taskUid: String) {
        let ctx = CasaCoreDataStack.shared.context
        guard let task = findTask(uid: taskUid, in: ctx) else { return }

        switch actionID {
        case "REMINDER_DONE":
            markDone(task, ctx: ctx)
            ReminderHistory.record(taskUid: task.uid, taskName: task.task, action: .markedDone)
        case "REMINDER_SNOOZE_15":
            snooze(task, after: 15 * 60)
            ReminderHistory.record(taskUid: task.uid, taskName: task.task, action: .snoozed)
        case "REMINDER_SNOOZE_1H":
            snooze(task, after: 60 * 60)
            ReminderHistory.record(taskUid: task.uid, taskName: task.task, action: .snoozed)
        case "REMINDER_SNOOZE_TOMORROW":
            snoozeUntilTomorrow(task)
            ReminderHistory.record(taskUid: task.uid, taskName: task.task, action: .snoozed)
        default:
            // Default tap (UNNotificationDefaultActionIdentifier) or
            // dismiss — no-op, the app opens normally.
            break
        }
    }

    // MARK: – Mark done

    private static func markDone(_ task: TaskItem, ctx: NSManagedObjectContext) {
        // Reuse the FamilyPoints toggle path so recurring reminders
        // advance their dueDate / completionCount the same way as an
        // in-app tap. Pass the live FamilyMember set so points credit
        // the right member if the reminder has an assignee + points.
        let memberReq: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
        memberReq.predicate = NSPredicate(format: "deletedAt == nil")
        let members = (try? ctx.fetch(memberReq)) ?? []
        if !task.isCompleted {
            FamilyPoints.toggle(task, in: members)
        }
        try? ctx.save()
        // Re-sync notifications so a one-shot stops firing and a
        // recurring reminder rolls to its next slot.
        Task { await NotificationsManager.scheduleNow(for: task) }
    }

    // MARK: – Snooze

    /// Schedule a one-shot follow-up notification N seconds from now.
    /// Identifier is stable per-task so back-to-back snoozes replace
    /// the previous one instead of stacking.
    private static func snooze(_ task: TaskItem, after seconds: TimeInterval) {
        let id = snoozeID(for: task.uid)
        let content = UNMutableNotificationContent()
        content.title = task.task
        content.body = "Snoozed reminder"
        content.sound = .default
        content.categoryIdentifier = "REMINDER_FIRE"
        content.userInfo = ["taskUid": task.uid]
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(60, seconds),
            repeats: false
        )
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.add(req)
    }

    private static func snoozeUntilTomorrow(_ task: TaskItem) {
        let cal = Calendar.current
        let tomorrowStart = cal.startOfDay(for: Date().addingTimeInterval(86_400))
        // 8am tomorrow — sensible default for "deal with it then."
        let target = cal.date(bySettingHour: 8, minute: 0, second: 0, of: tomorrowStart) ?? tomorrowStart
        let seconds = max(60, target.timeIntervalSinceNow)
        snooze(task, after: seconds)
    }

    // MARK: – Lookup

    private static func findTask(uid: String, in ctx: NSManagedObjectContext) -> TaskItem? {
        let req: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        req.predicate = NSPredicate(format: "uid == %@", uid)
        req.fetchLimit = 1
        return (try? ctx.fetch(req))?.first
    }
}
