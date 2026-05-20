import Foundation
import UserNotifications
import CoreData
import CoreLocation

private struct NotificationPlan {
    let id: String
    let content: UNMutableNotificationContent
    let trigger: UNNotificationTrigger
}

enum NotificationsManager {
    /// Canonical notification id prefix for a task — uid-based.
    /// Stable across reschedules, migrations, CloudKit syncs. Used to
    /// scope cancel / lookup operations to a single task.
    static func notificationBaseId(for task: TaskItem) -> String {
        "task-\(task.uid)"
    }

    /// Pre-migration id prefix using the task's `createdAt` timestamp
    /// in milliseconds. Kept ONLY for the migration sweep — when the
    /// new code reschedules a task, we cancel both prefixes so any
    /// leftover legacy ids in `UNUserNotificationCenter` are cleaned
    /// up. Safe to delete after a few releases when no app on a real
    /// device still has legacy pending notifications.
    static func legacyNotificationBaseId(for task: TaskItem) -> String {
        "task-\(Int(task.createdAt.timeIntervalSince1970 * 1000))"
    }

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
        let myName = UserDefaults.standard.string(forKey: "userName")?
            .trimmingCharacters(in: .whitespaces) ?? ""
        for t in tasks {
            // Recurring reminders keep firing even when checked off; one-shot
            // tasks stop once completed.
            let isRecurring = !t.effectiveRepeatKind.isEmpty
            guard !t.isCompleted || isRecurring else { continue }
            // Honor the same per-device routing logic that scheduleNow uses
            // so the bulk sync doesn't accidentally schedule reminders this
            // device shouldn't fire (e.g. a reminder targeted at admins on a
            // standard member's device). Tasks not routed to this device
            // simply don't get added to `plans` — their existing pending
            // ids end up in the `toCancel` set below.
            if t.category.lowercased() == "reminders" {
                let shouldSchedule = shouldDeviceScheduleReminder(
                    notifyMode: t.notifyMode.lowercased(),
                    assignee: (t.assignee ?? "").trimmingCharacters(in: .whitespaces),
                    myName: myName
                )
                guard shouldSchedule else { continue }
            }
            let content = UNMutableNotificationContent()
            content.title = t.task
            content.body = subtitle(for: t)
            content.sound = .default
            let baseId = notificationBaseId(for: t)
            let legacyBase = legacyNotificationBaseId(for: t)
            let cal = Calendar.current
            for date in nextOccurrenceDates(
                kind: t.effectiveRepeatKind,
                dueDate: t.dueDate,
                now: now,
                endMinutes: t.repeatEndMinutes
            ) {
                let id = "\(baseId)~\(occurrenceSuffix(date))"
                var dc = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                dc.second = 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
                plans.append(NotificationPlan(id: id, content: content, trigger: trigger))
            }
            // Migration sweep: any pending notification for this task that
            // still uses the legacy timestamp-based base id should be
            // cancelled here so it doesn't fire stale.
            let stale = existingIds.filter { $0.hasPrefix(legacyBase) }
            if !stale.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: Array(stale))
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
    /// Decide whether THIS device should schedule a local notification
    /// for a reminder, given the routing override + assignee.
    ///
    /// Rules:
    /// - notifyMode == "everyone": always yes
    /// - notifyMode == "admins": yes if local FamilyMember has owner or
    ///   admin role (canManageFamily). Looked up off the Core Data main
    ///   context — this runs on every refresh so the lookup is cheap.
    /// - notifyMode empty: legacy behavior — yes if assignee matches my
    ///   userName, or if assignee is empty (broadcast).
    static func shouldDeviceScheduleReminder(
        notifyMode: String,
        assignee: String,
        myName: String
    ) -> Bool {
        switch notifyMode {
        case "everyone":
            return true
        case "admins":
            return localUserIsAdmin()
        default:
            // Empty mode = current behavior. Notify the assignee, or
            // broadcast if no assignee.
            if assignee.isEmpty { return true }
            if myName.isEmpty { return true }
            return myName.lowercased() == assignee.lowercased()
        }
    }

    /// True when the local user's FamilyMember record has owner or
    /// admin role. Uses the shared Core Data main context and looks up
    /// the member by `meUid` (UserDefaults) or `userName` fallback.
    private static func localUserIsAdmin() -> Bool {
        let context = CasaCoreDataStack.shared.context
        let userName = UserDefaults.standard.string(forKey: "userName") ?? ""
        let meUid = UserDefaults.standard.string(forKey: "meUid") ?? ""
        let req = FamilyMember.fetchRequest()
        req.predicate = NSPredicate(format: "deletedAt == nil")
        let members = (try? context.fetch(req)) ?? []
        let me = FamilyPermissions.currentMember(
            members: members, userName: userName, meUid: meUid
        )
        return me?.canManageFamily ?? false
    }

    static func scheduleNow(for task: TaskItem) async {
        // Capture properties synchronously on MainActor.
        let baseId = notificationBaseId(for: task)
        let legacyBase = legacyNotificationBaseId(for: task)
        let title = task.task
        let body = subtitle(for: task)
        let kind = task.effectiveRepeatKind
        let dueDate = task.dueDate
        let endMinutes = task.repeatEndMinutes
        let isCompleted = task.isCompleted
        let taskUid = task.uid
        let category = task.category.lowercased()
        let assignee = (task.assignee ?? "").trimmingCharacters(in: .whitespaces)
        let notifyMode = task.notifyMode.lowercased()

        // Route per-device based on notifyMode override + assignee.
        //   "everyone" -> every device schedules
        //   "admins"   -> only owners + admins schedule
        //   "users"/"" -> existing assignee-based behavior
        // Only reminders use this routing; chores keep their existing
        // assignment semantics elsewhere in the codebase.
        if category == "reminders" {
            let me = UserDefaults.standard.string(forKey: "userName")?
                .trimmingCharacters(in: .whitespaces) ?? ""
            let shouldSchedule = shouldDeviceScheduleReminder(
                notifyMode: notifyMode,
                assignee: assignee,
                myName: me
            )
            if !shouldSchedule {
                // Cancel any stale pending notifications for this task
                // before bailing — the reminder may have been
                // re-routed away from this user.
                let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
                let toCancel = pending.map(\.identifier).filter {
                    $0.hasPrefix(baseId) || $0.hasPrefix(legacyBase)
                }
                if !toCancel.isEmpty {
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: toCancel)
                }
                return
            }
        }

        let status = await currentStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }
        let center = UNUserNotificationCenter.current()

        // Remove anything already scheduled for this task. Includes both
        // the new uid-based base id AND any leftover legacy timestamp-
        // based ids so the migration sweeps as users open the app.
        let pending = await center.pendingNotificationRequests()
        let toCancel = pending.map(\.identifier).filter {
            $0.hasPrefix(baseId) || $0.hasPrefix(legacyBase)
        }
        if !toCancel.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: toCancel)
        }
        // Recurring reminders keep firing even when checked off; one-shots stop.
        let isRecurring = !kind.isEmpty
        guard !isCompleted || isRecurring else { return }

        let now = Date()
        let isReminder = category == "reminders"
        let cal = Calendar.current
        // Compute rolling one-shot fire dates. Reminder-category items get
        // each date shifted forward past the quiet-hours window so the user
        // is never woken in the middle of the night by their own reminders.
        let occurrences = nextOccurrenceDates(
            kind: kind, dueDate: dueDate, now: now, endMinutes: endMinutes
        ).map { isReminder ? quietAdjusted($0) : $0 }

        for date in occurrences {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            // Reminders get action buttons (Mark done / Snooze / Skip) on the
            // lock screen via the REMINDER_FIRE category registered in
            // CasalistAppDelegate.registerReminderActions. Sound is
            // device-local: ReminderSoundStore tracks per-uid silence.
            if isReminder {
                content.categoryIdentifier = "REMINDER_FIRE"
                content.userInfo = ["taskUid": taskUid]
                content.sound = ReminderSoundStore.playsSound(for: taskUid) ? .default : nil
                // Group reminder pushes so a batch firing together
                // (e.g. 3 hourly reminders at 9 AM) lands as one stack
                // in Notification Center instead of 3 separate banners.
                content.threadIdentifier = "casalist-reminders"
            } else {
                content.sound = .default
            }
            var dc = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            dc.second = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
            let id = "\(baseId)~\(occurrenceSuffix(date))"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    // MARK: – Daily reminder recap

    /// Schedules tonight's recap push at the user-configured hour
    /// (default 21:00). Pulls the day's reminder activity from
    /// `ReminderHistory` and bakes a one-shot calendar-trigger
    /// notification with the summary. Call from app launch and
    /// after any meaningful state change.
    @MainActor
    static func scheduleReminderRecap() async {
        let enabled = UserDefaults.standard.object(forKey: "reminderRecapEnabled") as? Bool ?? false
        let center = UNUserNotificationCenter.current()
        let id = "reminder-recap"
        let pending = await center.pendingNotificationRequests()
        if pending.contains(where: { $0.identifier == id }) {
            center.removePendingNotificationRequests(withIdentifiers: [id])
        }
        guard enabled else { return }

        let hour = UserDefaults.standard.object(forKey: "reminderRecapHour") as? Int ?? 21
        let minute = UserDefaults.standard.object(forKey: "reminderRecapMinute") as? Int ?? 0
        let cal = Calendar.current
        guard let target = cal.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) else { return }
        // If we're past today's target time already, push to tomorrow.
        let fireDate = target > Date() ? target : (cal.date(byAdding: .day, value: 1, to: target) ?? target)

        let entries = ReminderHistory.load().filter {
            cal.isDateInToday($0.timestamp)
        }
        let doneCount = entries.filter { $0.action == .markedDone }.count
        let firedCount = entries.filter { $0.action == .fired }.count
        let snoozedCount = entries.filter { $0.action == .snoozed }.count

        let content = UNMutableNotificationContent()
        content.title = "Today's reminders"
        if entries.isEmpty {
            content.body = "Nothing fired today — a quiet day."
        } else {
            var parts: [String] = []
            if doneCount > 0 { parts.append("✅ \(doneCount) done") }
            if firedCount > 0 { parts.append("🔔 \(firedCount) fired") }
            if snoozedCount > 0 { parts.append("🌙 \(snoozedCount) snoozed") }
            content.body = parts.joined(separator: " · ")
        }
        content.sound = .default

        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        comps.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(req)
    }

    // MARK: – Rolling one-shot occurrence engine

    /// Date formatter for compact occurrence IDs (e.g. "202605181430").
    /// Using a let instead of a computed property avoids repeated allocation.
    private static let occurrenceFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMddHHmm"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        return f
    }()

    /// Compact date string used as the suffix in notification IDs.
    /// e.g. Date(2026-05-18 14:30) → "202605181430"
    private static func occurrenceSuffix(_ date: Date) -> String {
        occurrenceFmt.string(from: date)
    }

    /// Core occurrence calculator. Returns up to `maxCount` upcoming fire
    /// dates for a recurring (or one-shot) task, all strictly after `now`.
    /// All `repeats: true` triggers have been replaced with lists of one-shot
    /// calendar triggers so quiet-hours shifting, skip, and preview all work
    /// on concrete dates rather than abstract patterns.
    static func nextOccurrenceDates(
        kind: String,
        dueDate: Date?,
        now: Date = Date(),
        endMinutes: Int64 = 0,
        maxCount: Int = 7
    ) -> [Date] {
        let cal = Calendar.current

        // Custom RepeatRule ("custom:{...}") path.
        if let rule = RepeatRule.decode(kind) {
            return customRuleOccurrences(rule: rule, dueDate: dueDate, now: now, maxCount: maxCount, cal: cal)
        }

        switch kind {
        case "hourly", "every2h", "every4h", "every8h", "every12h":
            let step: Int = {
                switch kind {
                case "hourly":  return 1
                case "every2h": return 2
                case "every4h": return 4
                case "every8h": return 8
                default:        return 12
                }
            }()
            guard let due = dueDate else {
                // No start time — fire relative to now at step intervals.
                return (1...maxCount).map { i in
                    now.addingTimeInterval(TimeInterval(i * step * 3600))
                }
            }
            return cadenceOccurrences(due: due, step: step,
                                      endMinutes: Int(endMinutes),
                                      now: now, maxCount: maxCount, cal: cal)

        case "daily":
            guard let due = dueDate else { return [] }
            return periodicOccurrences(due: due, now: now, maxCount: maxCount,
                                       component: .day, value: 1, cal: cal)

        case "weekly":
            guard let due = dueDate else { return [] }
            return periodicOccurrences(due: due, now: now, maxCount: maxCount,
                                       component: .weekOfYear, value: 1, cal: cal)

        case "monthly":
            guard let due = dueDate else { return [] }
            return periodicOccurrences(due: due, now: now, maxCount: min(maxCount, 4),
                                       component: .month, value: 1, cal: cal)

        case "yearly":
            guard let due = dueDate else { return [] }
            return periodicOccurrences(due: due, now: now, maxCount: min(maxCount, 2),
                                       component: .year, value: 1, cal: cal)

        default:
            // One-shot: fire once at dueDate if it's still in the future.
            guard let due = dueDate, due > now else { return [] }
            return [due]
        }
    }

    /// Advances `due` by (`component`, `value`) until it's past `now`,
    /// then collects `maxCount` consecutive future dates.
    private static func periodicOccurrences(
        due: Date,
        now: Date,
        maxCount: Int,
        component: Calendar.Component,
        value: Int,
        cal: Calendar
    ) -> [Date] {
        var cursor = due
        while cursor <= now {
            cursor = cal.date(byAdding: component, value: value, to: cursor)
                ?? cursor.addingTimeInterval(86400)
        }
        var results: [Date] = []
        for _ in 0..<maxCount {
            results.append(cursor)
            cursor = cal.date(byAdding: component, value: value, to: cursor)
                ?? cursor.addingTimeInterval(86400)
        }
        return results
    }

    /// Hourly-cadence occurrences. Generates fire times for each `step`-hour
    /// slot in a day window defined by `due` (start) and `endMinutes` (stop).
    /// Scans up to 30 days forward to fill `maxCount` slots.
    private static func cadenceOccurrences(
        due: Date,
        step: Int,
        endMinutes: Int,
        now: Date,
        maxCount: Int,
        cal: Calendar
    ) -> [Date] {
        let startMinOfDay = cal.component(.hour, from: due) * 60 + cal.component(.minute, from: due)
        let hasStop = endMinutes > startMinOfDay

        // Slots = minute-of-day values that should fire each day.
        var slots: [Int] = []
        var mod = startMinOfDay
        while mod < 24 * 60 {
            if !hasStop || mod <= endMinutes { slots.append(mod) }
            mod += step * 60
        }
        guard !slots.isEmpty else { return [] }

        var results: [Date] = []
        let dayStart = cal.startOfDay(for: due)

        for dayOffset in 0..<30 where results.count < maxCount {
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: dayStart) else { continue }
            for slot in slots {
                guard let fire = cal.date(bySettingHour: slot / 60, minute: slot % 60, second: 0, of: day),
                      fire > now else { continue }
                results.append(fire)
                if results.count >= maxCount { break }
            }
        }
        return results
    }

    /// Custom RepeatRule occurrence generator.
    private static func customRuleOccurrences(
        rule: RepeatRule,
        dueDate: Date?,
        now: Date,
        maxCount: Int,
        cal: Calendar
    ) -> [Date] {
        guard let due = dueDate else { return [] }
        switch rule.unit {
        case .minute:
            let s = TimeInterval(max(1, rule.interval) * 60)
            var c = due
            while c <= now { c = c.addingTimeInterval(s) }
            return (0..<maxCount).map { c.addingTimeInterval(s * TimeInterval($0)) }

        case .hour:
            let s = TimeInterval(max(1, rule.interval) * 3600)
            var c = due
            while c <= now { c = c.addingTimeInterval(s) }
            return (0..<maxCount).map { c.addingTimeInterval(s * TimeInterval($0)) }

        case .day:
            return periodicOccurrences(due: due, now: now, maxCount: maxCount,
                                       component: .day, value: rule.interval, cal: cal)
        case .week:
            // Multi-weekday rules ("Every weekday", "Every Mon, Wed, Fri")
            // expand by walking forward day-by-day and emitting occurrences
            // whose weekday is in the set. Single-weekday rules fall through
            // to the existing weekOfYear cadence.
            let wds = rule.effectiveWeekdays
            if wds.count > 1 {
                let timeComps = cal.dateComponents([.hour, .minute, .second], from: due)
                var cursor = cal.startOfDay(for: max(due, now))
                var results: [Date] = []
                var safety = 0
                while results.count < maxCount && safety < 365 {
                    let wd = cal.component(.weekday, from: cursor)
                    if wds.contains(wd) {
                        var c = cal.dateComponents([.year, .month, .day], from: cursor)
                        c.hour = timeComps.hour
                        c.minute = timeComps.minute
                        c.second = timeComps.second
                        if let d = cal.date(from: c), d > now {
                            results.append(d)
                        }
                    }
                    cursor = cal.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86400)
                    safety += 1
                }
                return results
            }
            return periodicOccurrences(due: due, now: now, maxCount: maxCount,
                                       component: .weekOfYear, value: rule.interval, cal: cal)
        case .month:
            return periodicOccurrences(due: due, now: now, maxCount: min(maxCount, 4),
                                       component: .month, value: rule.interval, cal: cal)
        case .year:
            return periodicOccurrences(due: due, now: now, maxCount: min(maxCount, 2),
                                       component: .year, value: rule.interval, cal: cal)
        }
    }

    // MARK: – Quiet-hours adjustment

    /// Shifts `date` to the end of the quiet window when it falls inside one.
    /// If quiet hours are disabled or the date is already outside the window,
    /// returns `date` unchanged. Call this per-occurrence when scheduling
    /// reminder-category tasks so pushes never fire during sleep.
    static func quietAdjusted(_ date: Date) -> Date {
        guard isWithinQuietHours(date) else { return date }
        let defaults = UserDefaults.standard
        let endHour = defaults.object(forKey: "quietHoursEnd") as? Int ?? 7
        let cal = Calendar.current
        // Build endHour:00 on the same calendar day.
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        comps.hour = endHour
        comps.minute = 0
        comps.second = 0
        guard var candidate = cal.date(from: comps) else { return date }
        // If end-of-quiet already passed relative to `date`, bump to next day.
        if candidate <= date {
            candidate = cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }

    // MARK: – Skip next occurrence

    /// Cancels the earliest pending one-shot notification for a task
    /// (identified by `baseId`). The next occurrence in the rolling window
    /// becomes the new "next fire". After skipping, call `scheduleNow` to
    /// backfill the removed slot with a fresh occurrence at the tail.
    static func skipNextOccurrence(baseId: String) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        // New-format IDs use "~" separator; old-format used "-". Only skip
        // new-format IDs (old ones will be cleaned up by the next sync).
        let matching = pending
            .filter { $0.identifier.hasPrefix("\(baseId)~") }
            .compactMap { req -> (String, Date)? in
                guard let cal = (req.trigger as? UNCalendarNotificationTrigger)
                    .flatMap({ Calendar.current.nextDate(after: .distantPast,
                                                        matching: $0.dateComponents,
                                                        matchingPolicy: .nextTime) })
                else { return nil }
                return (req.identifier, cal)
            }
            .sorted { $0.1 < $1.1 }
        guard let (earliestId, _) = matching.first else { return }
        center.removePendingNotificationRequests(withIdentifiers: [earliestId])
    }

    // MARK: – Upcoming fire date queries

    /// Returns the next `limit` fire dates already queued in the notification
    /// center for a task. Covers both rolling one-shot (task-*~*) and any
    /// active snooze (reminder-snooze-{uid}) so the edit view reflects the
    /// real upcoming fire, not just the pattern schedule.
    static func upcomingFireDates(baseId: String, taskUid: String = "", limit: Int = 3) async -> [Date] {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let cal = Calendar.current
        let now = Date()

        var dates: [Date] = []

        for req in pending {
            let id = req.identifier
            // Regular rolling one-shot: task-{ms}~{date}
            let isRegular = id.hasPrefix("\(baseId)~")
            // Snooze: reminder-snooze-{uid}
            let isSnooze = !taskUid.isEmpty && id == "reminder-snooze-\(taskUid)"
            guard isRegular || isSnooze else { continue }

            if let t = req.trigger as? UNCalendarNotificationTrigger,
               let d = cal.nextDate(after: now, matching: t.dateComponents,
                                    matchingPolicy: .nextTime) {
                dates.append(d)
            } else if let t = req.trigger as? UNTimeIntervalNotificationTrigger {
                // Snooze uses UNTimeIntervalNotificationTrigger
                dates.append(now.addingTimeInterval(t.timeInterval))
            }
        }

        return dates.sorted().prefix(limit).map { $0 }
    }

    /// Computes upcoming fire dates without touching the notification center.
    /// Use this in the edit sheet to show "Next fires: …" without async work.
    static func previewFireDates(
        kind: String,
        dueDate: Date?,
        endMinutes: Int64 = 0,
        limit: Int = 3
    ) -> [Date] {
        nextOccurrenceDates(kind: kind, dueDate: dueDate, now: Date(),
                            endMinutes: endMinutes, maxCount: limit)
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

    // MARK: – Daily morning briefing

    /// Roll-up push fired once a day at the user's chosen hour. Aggregates
    /// today's open chores, scheduled events, and pending reward requests
    /// into a single notification so the household isn't drowned in
    /// individual pings first thing in the morning.
    static func scheduleDailyBriefing(in context: NSManagedObjectContext) async {
        let briefingId = "daily-briefing"
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [briefingId])

        let defaults = UserDefaults.standard
        let enabled = defaults.object(forKey: "dailyBriefingEnabled") as? Bool ?? true
        guard enabled else { return }
        let status = await currentStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        // Repeats daily at the configured hour. Body is computed at trigger
        // time? No — Apple only delivers a static body for repeating
        // calendar triggers. We rebuild + reschedule on every foreground
        // (via the scenePhase active handler) so the body reflects today.
        let hour = defaults.object(forKey: "dailyBriefingHour") as? Int ?? 7

        // Count today's open tasks.
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: Date())
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        let openReq: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        openReq.predicate = NSPredicate(
            format: "isCompleted == NO AND deletedAt == nil AND ((dueDate == nil) OR (dueDate >= %@ AND dueDate < %@))",
            startOfDay as NSDate, endOfDay as NSDate
        )
        let openToday = (try? context.count(for: openReq)) ?? 0

        // Count today's events.
        let eventReq: NSFetchRequest<FamilyEvent> = FamilyEvent.fetchRequest()
        eventReq.predicate = NSPredicate(
            format: "deletedAt == nil AND startDate >= %@ AND startDate < %@",
            startOfDay as NSDate, endOfDay as NSDate
        )
        let eventsToday = (try? context.count(for: eventReq)) ?? 0

        // Pending reward requests.
        let pendingReq: NSFetchRequest<FamilyGoal> = FamilyGoal.fetchRequest()
        pendingReq.predicate = NSPredicate(
            format: "ownerName BEGINSWITH %@ AND isRedeemed == NO AND deletedAt == nil",
            GoalApproval.pendingPrefix
        )
        let pending = (try? context.count(for: pendingReq)) ?? 0

        var parts: [String] = []
        if openToday > 0 { parts.append("\(openToday) chore\(openToday == 1 ? "" : "s")") }
        if eventsToday > 0 { parts.append("\(eventsToday) event\(eventsToday == 1 ? "" : "s")") }
        if pending > 0 { parts.append("\(pending) reward request\(pending == 1 ? "" : "s")") }

        let body: String
        if parts.isEmpty {
            body = "Nothing on the family schedule today. Enjoy the breather."
        } else {
            body = "Today: \(parts.joined(separator: " · "))"
        }

        let content = UNMutableNotificationContent()
        content.title = "Casalist morning briefing ☀️"
        content.body = body
        content.sound = .default

        var dc = DateComponents()
        dc.hour = hour
        dc.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        let request = UNNotificationRequest(identifier: briefingId, content: content, trigger: trigger)
        try? await center.add(request)
    }

    @MainActor
    static func cancelDailyBriefing() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-briefing"])
    }

    // MARK: – FamilyEvent push notifications

    /// Identifier prefix for event notifications.
    private static let eventIdPrefix = "event-"

    /// Schedule (or reschedule) a local push for a FamilyEvent. Honors
    /// `repeatKind` so daily/weekly/monthly/yearly events use a repeating
    /// calendar trigger. Idempotent — cancels any prior schedule for this
    /// event before re-adding.
    static func scheduleEvent(for event: FamilyEvent) async {
        let id = eventIdPrefix + event.uid.uuidString
        let center = UNUserNotificationCenter.current()
        // Cancel both the legacy single-trigger id and any per-weekday
        // ids from a previous multi-weekday schedule. 1=Sun..7=Sat.
        var stale = [id]
        for wd in 1...7 { stale.append("\(id)-wd\(wd)") }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        guard event.deletedAt == nil else { return }
        // Don't schedule events in the past unless they're recurring.
        if event.startDate < Date() && event.repeatKind.isEmpty { return }

        let status = await currentStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        // Empty attendees → household-wide broadcast by default.
        // `announceHousehold` ALSO forces the broadcast prefix even when a
        // specific attendee is set, so admins can announce "this is
        // Donovan's event" without losing the family-wide ping.
        let isBroadcast = event.attendees.trimmingCharacters(in: .whitespaces).isEmpty
            || event.announceHousehold
        let content = UNMutableNotificationContent()
        content.title = isBroadcast ? "📢 \(event.title)" : "📅 \(event.title)"
        var bodyParts: [String] = []
        if event.isAllDay {
            bodyParts.append("All day")
        } else {
            let f = DateFormatter()
            f.dateStyle = .none
            f.timeStyle = .short
            bodyParts.append(f.string(from: event.startDate))
        }
        if !event.location.isEmpty { bodyParts.append(event.location) }
        if isBroadcast {
            bodyParts.append("Family-wide reminder")
        } else {
            bodyParts.append("with \(event.attendees)")
        }
        content.body = bodyParts.joined(separator: " · ")
        content.sound = .default

        let cal = Calendar.current
        let trigger: UNNotificationTrigger

        if let rule = RepeatRule.decode(event.repeatKind) {
            // Custom rule. Hours/minutes use UNTimeIntervalNotificationTrigger
            // (calendar trigger has no "every N hours" form). Days/Weeks/
            // Months use a calendar trigger with the right component mask.
            switch rule.unit {
            case .minute:
                let seconds = max(60, TimeInterval(rule.interval) * 60)
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: true)
            case .hour:
                let seconds = max(3600, TimeInterval(rule.interval) * 3600)
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: true)
            case .day:
                // "Every N days" — repeating exact time-of-day triggers can
                // only do "every day," not every N. Fall back: schedule one
                // future date, non-repeating. The foreground sync will
                // reschedule the next occurrence after it fires.
                if rule.interval == 1 {
                    let dc = cal.dateComponents([.hour, .minute], from: event.startDate)
                    trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
                } else {
                    let next = cal.date(byAdding: .day, value: rule.interval, to: max(event.startDate, Date())) ?? event.startDate
                    let dc = cal.dateComponents([.year, .month, .day, .hour, .minute], from: next)
                    trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
                }
            case .week:
                // Multi-weekday ("Every weekday", "Every Mon, Wed, Fri") —
                // register one repeating calendar trigger per weekday with
                // a -wdN suffix on the id so each can be cancelled cleanly.
                if rule.interval == 1, let wds = rule.weekdays, wds.count > 1 {
                    let baseComps = cal.dateComponents([.hour, .minute], from: event.startDate)
                    for wd in wds {
                        var dc = baseComps
                        dc.weekday = wd
                        let t = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
                        let req = UNNotificationRequest(identifier: "\(id)-wd\(wd)", content: content, trigger: t)
                        try? await center.add(req)
                    }
                    return
                }
                // "Every Friday" → weekly weekday trigger. "Every other
                // Friday" → weekly trigger that fires every Friday, but we
                // skip alternates at delivery time? Hard. Cheap fix: every
                // 2nd week, fire as one-shot N days out.
                if rule.interval == 1, let wd = rule.weekday {
                    var dc = cal.dateComponents([.hour, .minute], from: event.startDate)
                    dc.weekday = wd
                    trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
                } else if rule.interval == 1 {
                    let dc = cal.dateComponents([.weekday, .hour, .minute], from: event.startDate)
                    trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
                } else {
                    let weeks = rule.interval
                    let next = cal.date(byAdding: .weekOfYear, value: weeks, to: max(event.startDate, Date())) ?? event.startDate
                    let dc = cal.dateComponents([.year, .month, .day, .hour, .minute], from: next)
                    trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
                }
            case .month:
                if rule.interval == 1 {
                    let dc = cal.dateComponents([.day, .hour, .minute], from: event.startDate)
                    trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
                } else {
                    let next = cal.date(byAdding: .month, value: rule.interval, to: max(event.startDate, Date())) ?? event.startDate
                    let dc = cal.dateComponents([.year, .month, .day, .hour, .minute], from: next)
                    trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
                }
            case .year:
                if rule.interval == 1 {
                    let dc = cal.dateComponents([.month, .day, .hour, .minute], from: event.startDate)
                    trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
                } else {
                    let next = cal.date(byAdding: .year, value: rule.interval, to: max(event.startDate, Date())) ?? event.startDate
                    let dc = cal.dateComponents([.year, .month, .day, .hour, .minute], from: next)
                    trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
                }
            }
        } else if event.repeatKind == "weekdays" {
            // Monday-Friday only. Register one repeating calendar trigger
            // per weekday (2=Mon..6=Fri) with a -wdN id suffix, mirroring
            // the multi-weekday path above. Return early; no single
            // trigger to add at the bottom of this function.
            let baseComps = cal.dateComponents([.hour, .minute], from: event.startDate)
            for wd in 2...6 {
                var dc = baseComps
                dc.weekday = wd
                let t = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
                let req = UNNotificationRequest(identifier: "\(id)-wd\(wd)", content: content, trigger: t)
                try? await center.add(req)
            }
            return
        } else {
            // Legacy kind strings.
            var dc: DateComponents
            let repeats = !event.repeatKind.isEmpty
            switch event.repeatKind {
            case "daily":
                dc = cal.dateComponents([.hour, .minute], from: event.startDate)
            case "weekly":
                dc = cal.dateComponents([.weekday, .hour, .minute], from: event.startDate)
            case "monthly":
                dc = cal.dateComponents([.day, .hour, .minute], from: event.startDate)
            case "yearly":
                dc = cal.dateComponents([.month, .day, .hour, .minute], from: event.startDate)
            default:
                dc = cal.dateComponents([.year, .month, .day, .hour, .minute], from: event.startDate)
            }
            trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: repeats)
        }
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func cancelEvent(uid: String) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [eventIdPrefix + uid]
        )
    }

    /// Re-schedule push notifications for every live FamilyEvent. Called on
    /// app launch / foreground so events that synced down from another
    /// device get their notifications registered on THIS device too.
    static func syncEventsFromContext(_ context: NSManagedObjectContext) async {
        let req: NSFetchRequest<FamilyEvent> = FamilyEvent.fetchRequest()
        req.predicate = NSPredicate(format: "deletedAt == nil")
        let events = (try? context.fetch(req)) ?? []
        // Defensive dedupe BEFORE scheduling. If two FamilyEvent rows
        // exist for the same logical event (CKShare replay, household
        // migration, double-tap on Save) each row has its own uid →
        // its own `event-<uid>` notification id → both fire,
        // producing two identical pushes for one event. Group by
        // (title|startDate|household) and schedule only one. The
        // surviving row is the oldest (lowest uid string) so the same
        // device picks the same survivor every launch.
        var bestByKey: [String: FamilyEvent] = [:]
        for e in events {
            let householdId = e.household?.objectID.uriRepresentation().absoluteString ?? ""
            let key = "\(e.title)|\(e.startDate.timeIntervalSinceReferenceDate)|\(householdId)"
            if let prior = bestByKey[key] {
                // Keep the lexicographically lower uid string — stable,
                // device-independent, no clock dependency.
                if e.uid.uuidString < prior.uid.uuidString {
                    bestByKey[key] = e
                }
            } else {
                bestByKey[key] = e
            }
        }
        // Cancel pushes for the LOSER rows so they stop firing
        // independently if they were scheduled in a prior session.
        let survivorUids = Set(bestByKey.values.map { $0.uid.uuidString })
        let loserIds = events.compactMap { e -> String? in
            survivorUids.contains(e.uid.uuidString) ? nil : eventIdPrefix + e.uid.uuidString
        }
        if !loserIds.isEmpty {
            var allLoserIds = loserIds
            for base in loserIds {
                for wd in 1...7 { allLoserIds.append("\(base)-wd\(wd)") }
            }
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: allLoserIds)
        }
        for event in bestByKey.values {
            await scheduleEvent(for: event)
        }

        // Orphan cleanup — cancel any pending event-* notification whose
        // event no longer exists (deleted, renamed into a new row, or a
        // stale repeating trigger left from a past schedule). Without this
        // a recurring push keeps firing forever even after its event is
        // gone — e.g. a "school out" notification still arriving when only
        // an "early out" event remains.
        let liveUids = Set(events.map { $0.uid.uuidString })
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let orphanIds = pending.map(\.identifier).filter { id in
            guard id.hasPrefix(eventIdPrefix) else { return false }
            // id is "event-<uuid>" or "event-<uuid>-wd<N>"; UUIDs never
            // contain "-wd", so splitting on it isolates the uuid.
            let rest = String(id.dropFirst(eventIdPrefix.count))
            let uid = rest.components(separatedBy: "-wd").first ?? rest
            return !liveUids.contains(uid)
        }
        if !orphanIds.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: orphanIds)
        }
    }

    // MARK: – Quiet hours

    /// Returns true if `date` falls inside the user's configured quiet
    /// hours window. Used to suppress non-critical pushes (assignment,
    /// grocery activity, etc.). Per-task due-date reminders bypass this.
    static func isWithinQuietHours(_ date: Date = Date()) -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "quietHoursEnabled") else { return false }
        let start = defaults.object(forKey: "quietHoursStart") as? Int ?? 21
        let end = defaults.object(forKey: "quietHoursEnd") as? Int ?? 7
        let hour = Calendar.current.component(.hour, from: date)
        if start == end { return false }
        if start < end { return hour >= start && hour < end }
        // Window crosses midnight (e.g. 21 → 7).
        return hour >= start || hour < end
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
        if isWithinQuietHours() { return }
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

    // MARK: – Status ping push (manual family broadcast)

    private static let notifiedPingsKey = "notifiedStatusPingUIDs"

    /// Fire a push for every new status ping that landed on this device
    /// from another device. Pings are TaskItem records with
    /// `category == StatusPing.category`. Quiet hours suppress.
    @MainActor
    static func detectAndNotifyStatusPings(in context: NSManagedObjectContext, userName: String) async {
        if isWithinQuietHours() { return }
        let trimmed = userName.trimmingCharacters(in: .whitespaces)
        let status = await currentStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let cutoff = Date().addingTimeInterval(-24 * 3600)
        let req: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        req.predicate = NSPredicate(
            format: "category == %@ AND deletedAt == nil AND createdAt > %@",
            StatusPing.category, cutoff as NSDate
        )
        guard let pings = try? context.fetch(req), !pings.isEmpty else { return }

        let defaults = UserDefaults.standard
        var notified = Set(defaults.stringArray(forKey: notifiedPingsKey) ?? [])

        for ping in pings {
            let key = ping.uid
            if notified.contains(key) { continue }
            if ping.createdBy.lowercased() == trimmed.lowercased() {
                notified.insert(key)
                continue
            }
            // Honor per-device mute on the sender. We still mark the
            // ping as notified so an un-mute later doesn't replay
            // back-history pushes.
            if MemberMuteStore.isMuted(ping.createdBy) {
                notified.insert(key)
                continue
            }
            let sender = ping.createdBy.isEmpty ? "Someone" : ping.createdBy
            let (display, coord) = StatusPing.parseLocationPing(ping.task)
            let content = UNMutableNotificationContent()
            content.title = "📣 \(sender)"
            if let coord {
                content.body = "\(display)— tap to open in Maps"
                content.userInfo = ["pingCoordLat": coord.latitude,
                                    "pingCoordLng": coord.longitude,
                                    "pingSender": sender]
            } else {
                content.body = display
            }
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: "ping-\(key)", content: content, trigger: trigger)
            try? await UNUserNotificationCenter.current().add(request)
            notified.insert(key)
        }

        defaults.set(Array(notified), forKey: notifiedPingsKey)
    }

    // MARK: – Grocery list activity push

    private static let notifiedGroceryKey = "notifiedGroceryUIDs"

    /// Fire a push when a new grocery item lands on this device from
    /// another device. Light social signal so the household knows the
    /// list has changed. Honors `groceryActivityPush` AppStorage and
    /// quiet hours. Skips items this device created itself (we already
    /// know what we typed). Skips trip headers (parent grocery tasks
    /// with a dueDate — they're trip titles, not shopping items).
    @MainActor
    static func detectAndNotifyGroceryActivity(in context: NSManagedObjectContext, userName: String) async {
        if isWithinQuietHours() { return }
        let defaults = UserDefaults.standard
        let enabled = defaults.object(forKey: "groceryActivityPush") as? Bool ?? true
        guard enabled else { return }
        let trimmed = userName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let status = await currentStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        let req: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        req.predicate = NSPredicate(
            format: "category == %@ AND deletedAt == nil AND isCompleted == NO AND createdAt > %@ AND dueDate == nil",
            "groceries", cutoff as NSDate
        )
        guard let items = try? context.fetch(req), !items.isEmpty else { return }

        var notified = Set(defaults.stringArray(forKey: notifiedGroceryKey) ?? [])

        for item in items {
            let key = item.uid
            if notified.contains(key) { continue }
            // Skip items this device's user created — they already know.
            if item.createdBy.lowercased() == trimmed.lowercased() {
                notified.insert(key)
                continue
            }
            // Honor per-device mute on the actor.
            if MemberMuteStore.isMuted(item.createdBy) {
                notified.insert(key)
                continue
            }
            let actor = item.createdBy.isEmpty ? "Someone" : item.createdBy
            let content = UNMutableNotificationContent()
            content.title = "🛒 \(actor) added to the grocery list"
            content.body = item.task
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: "grocery-\(key)", content: content, trigger: trigger)
            try? await UNUserNotificationCenter.current().add(request)
            notified.insert(key)
        }

        defaults.set(Array(notified), forKey: notifiedGroceryKey)
    }

    // MARK: – Reward-request push notifications

    private static let notifiedRequestsKey = "notifiedPendingRequestUIDs"

    /// Fire a local notification for every newly-pending FamilyGoal (a
    /// reward request from a kid or non-admin) that's landed on this
    /// device. Only admins get pinged — non-admin family members don't
    /// need to know about other people's requests.
    @MainActor
    static func detectAndNotifyPendingRequests(in context: NSManagedObjectContext, userName: String) async {
        if isWithinQuietHours() { return }
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
            let noteText = GoalLink.note(from: g.note)
            if !noteText.isEmpty { bodyParts.append("\u{201C}\(noteText)\u{201D}") }
            if GoalLink.url(from: g.note) != nil { bodyParts.append("🔗 link attached") }
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
        if isWithinQuietHours() { return }
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
