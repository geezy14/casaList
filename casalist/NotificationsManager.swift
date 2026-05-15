import Foundation
import UserNotifications
import CoreData

private struct NotificationPlan {
    let id: String
    let content: UNMutableNotificationContent
    let trigger: UNNotificationTrigger
}

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
    static func sync<S: Sequence>(tasks: S) async where S.Element == TaskItem {
        let status = await currentStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else {
            await cancelAll()
            return
        }

        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let existingIds = Set(pending.map(\.identifier).filter { $0.hasPrefix("task-") })

        let now = Date()
        var plans: [NotificationPlan] = []
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
                plans.append(NotificationPlan(id: id, content: content, trigger: trigger))
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

    /// Convenience that pulls tasks from a managed object context and calls sync.
    @MainActor
    static func syncFromContext(_ context: NSManagedObjectContext) async {
        let request = TaskItem.fetchRequest()
        let tasks = (try? context.fetch(request)) ?? []
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

    // MARK: – Weekly recap (Sunday 7pm)

    @MainActor
    static func scheduleWeeklyRecap(in context: NSManagedObjectContext) async {
        let recapId = "weekly-recap"
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [recapId])

        let status = await currentStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let memberReq = FamilyMember.fetchRequest()
        memberReq.predicate = NSPredicate(format: "deletedAt == nil")
        let members = (try? context.fetch(memberReq)) ?? []
        let sortedMembers = members.sorted { $0.points > $1.points }
        guard !sortedMembers.isEmpty else { return }

        let topThree = sortedMembers.prefix(3).map { "\($0.name) \($0.points)pt" }.joined(separator: " · ")

        let openReq: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        openReq.predicate = NSPredicate(format: "isCompleted == NO AND points > 0 AND deletedAt == nil")
        let openCount = (try? context.count(for: openReq)) ?? 0

        let body = openCount == 0
            ? "\(topThree). No open chores 🎉"
            : "\(topThree). \(openCount) open chore\(openCount == 1 ? "" : "s") this week."

        let content = UNMutableNotificationContent()
        content.title = "Casalist weekly recap 🏠"
        content.body = body
        content.sound = .default

        var dc = DateComponents()
        dc.weekday = 1   // Sunday
        dc.hour = 19
        dc.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        let request = UNNotificationRequest(identifier: recapId, content: content, trigger: trigger)
        try? await center.add(request)
    }

    @MainActor
    static func cancelWeeklyRecap() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["weekly-recap"])
    }

    // MARK: – Assignment push notifications

    private static let notifiedAssignmentsKey = "notifiedAssignmentUIDs"

    /// Fire a local notification for every TaskItem newly assigned to
    /// `userName` since the last scan, deduped per device by UID. Runs
    /// off the .NSPersistentStoreRemoteChange listener — local creations
    /// don't fire that publisher, so the assignee only gets pinged for
    /// tasks that came in from another device.
    @MainActor
    static func detectAndNotifyAssignments(in context: NSManagedObjectContext, userName: String) async {
        let trimmed = userName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let status = await currentStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        // Only look at recent tasks so a freshly synced shared store doesn't
        // dump months of historical assignments into the notification center.
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        let req: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        req.predicate = NSPredicate(
            format: "assignee != nil AND assignee LIKE[c] %@ AND isCompleted == NO AND deletedAt == nil AND createdAt > %@",
            trimmed, cutoff as NSDate
        )
        guard let recent = try? context.fetch(req), !recent.isEmpty else { return }

        let defaults = UserDefaults.standard
        var notified = Set(defaults.stringArray(forKey: notifiedAssignmentsKey) ?? [])

        for t in recent {
            let key = t.uid
            if key.isEmpty || notified.contains(key) { continue }
            // Skip if I created the task myself — even if it landed here via
            // sync, I obviously already know.
            if t.createdBy.lowercased() == trimmed.lowercased() {
                notified.insert(key)
                continue
            }

            let content = UNMutableNotificationContent()
            let actor = t.createdBy.isEmpty ? "Casalist" : t.createdBy
            content.title = "📝 \(actor) assigned you a task"
            var bodyParts: [String] = [t.task]
            if t.points > 0 { bodyParts.append("\(t.points) pts") }
            if !t.category.isEmpty { bodyParts.append(t.category.capitalized) }
            content.body = bodyParts.joined(separator: " · ")
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "assigned-\(key)",
                content: content,
                trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(request)
            notified.insert(key)
        }

        defaults.set(Array(notified), forKey: notifiedAssignmentsKey)
    }

    // MARK: – Reward-request push notifications

    private static let notifiedRequestsKey = "notifiedPendingRequestUIDs"

    /// Fire a local notification for every newly-pending FamilyGoal (a
    /// reward request from a kid or non-admin) that's landed on this
    /// device. Only admins get pinged — non-admin family members don't
    /// need to know about other people's requests.
    @MainActor
    static func detectAndNotifyPendingRequests(in context: NSManagedObjectContext, userName: String) async {
        let trimmed = userName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let status = await currentStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        // Verify this device's user is actually an admin — non-admins
        // shouldn't get notified about other people's reward requests.
        let memberReq = FamilyMember.fetchRequest()
        memberReq.predicate = NSPredicate(format: "deletedAt == nil AND name LIKE[c] %@", trimmed)
        guard let me = (try? context.fetch(memberReq))?.first, me.canManageFamily else { return }

        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        let goalReq: NSFetchRequest<FamilyGoal> = FamilyGoal.fetchRequest()
        goalReq.predicate = NSPredicate(
            format: "ownerName BEGINSWITH %@ AND isRedeemed == NO AND deletedAt == nil AND createdAt > %@",
            GoalApproval.pendingPrefix, cutoff as NSDate
        )
        guard let pending = try? context.fetch(goalReq), !pending.isEmpty else { return }

        let defaults = UserDefaults.standard
        var notified = Set(defaults.stringArray(forKey: notifiedRequestsKey) ?? [])

        for g in pending {
            let key = g.uid.uuidString
            if notified.contains(key) { continue }
            let requester = GoalApproval.realOwnerName(g)
            guard !requester.isEmpty else { continue }

            let content = UNMutableNotificationContent()
            content.title = "💬 \(requester) asked for a reward"
            var bodyParts: [String] = [g.label]
            if !g.note.isEmpty { bodyParts.append("\u{201C}\(g.note)\u{201D}") }
            content.body = bodyParts.joined(separator: " — ")
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "request-\(key)",
                content: content,
                trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(request)
            notified.insert(key)
        }

        defaults.set(Array(notified), forKey: notifiedRequestsKey)
    }

    // MARK: – Redemption push notifications

    private static let notifiedRedemptionsKey = "notifiedRedemptionUIDs"

    /// Fire a local notification for every FamilyGoal that's been redeemed
    /// since the last scan and hasn't been notified about yet on this device.
    ///
    /// Called from the .NSPersistentStoreRemoteChange listener — so it only
    /// runs when the change came from CloudKit (not from a local redeem on
    /// this device). The redeemer's own device won't see their own action
    /// here because local changes don't fire the remote-change notification.
    @MainActor
    static func detectAndNotifyRedemptions(in context: NSManagedObjectContext) async {
        let status = await currentStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        // Only consider redemptions in the last 7 days so a clock-skew
        // backlog or a freshly synced shared store doesn't dump months of
        // history into the user's notification center.
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        let req: NSFetchRequest<FamilyGoal> = FamilyGoal.fetchRequest()
        req.predicate = NSPredicate(format: "isRedeemed == YES AND redeemedAt != nil AND redeemedAt > %@ AND deletedAt == nil", cutoff as NSDate)
        guard let recent = try? context.fetch(req), !recent.isEmpty else { return }

        let defaults = UserDefaults.standard
        var notified = Set(defaults.stringArray(forKey: notifiedRedemptionsKey) ?? [])

        for g in recent {
            let key = g.uid.uuidString
            if notified.contains(key) { continue }
            // Skip if the goal has no real owner (still pending) — shouldn't
            // happen with isRedeemed=YES but defensive.
            let owner = GoalApproval.realOwnerName(g)
            guard !owner.isEmpty else { continue }

            let content = UNMutableNotificationContent()
            content.title = "🎁 \(owner) redeemed a reward"
            content.body = "\(g.label) · \(g.targetPoints) pts"
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "redemption-\(key)",
                content: content,
                trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(request)
            notified.insert(key)
        }

        defaults.set(Array(notified), forKey: notifiedRedemptionsKey)
    }

    /// Fires a one-shot test notification in ~5 seconds using the same body
    /// builder as the Sunday recap, so the parent can see exactly what the
    /// weekly notification will look like with real data.
    @MainActor
    static func sendRecapTestNow(in context: NSManagedObjectContext) async {
        let status = await currentStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let memberReq = FamilyMember.fetchRequest()
        memberReq.predicate = NSPredicate(format: "deletedAt == nil")
        let members = (try? context.fetch(memberReq)) ?? []
        let sortedMembers = members.sorted { $0.points > $1.points }

        let topThree = sortedMembers.isEmpty
            ? "No family members yet"
            : sortedMembers.prefix(3).map { "\($0.name) \($0.points)pt" }.joined(separator: " · ")

        let openReq: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        openReq.predicate = NSPredicate(format: "isCompleted == NO AND points > 0 AND deletedAt == nil")
        let openCount = (try? context.count(for: openReq)) ?? 0

        let body = openCount == 0
            ? "\(topThree). No open chores 🎉"
            : "\(topThree). \(openCount) open chore\(openCount == 1 ? "" : "s") this week."

        let content = UNMutableNotificationContent()
        content.title = "Casalist weekly recap 🏠 (test)"
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "weekly-recap-test-\(UUID().uuidString)", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
