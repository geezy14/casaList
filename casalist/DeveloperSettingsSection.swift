import SwiftUI
import CoreData
import CloudKit

/// Developer tools section, isolated in its own View struct (and several
/// sub-structs) so the heavy generic TupleView doesn't bloat any single
/// View's body type signature. On iOS 26 the deeply-nested type-graph
/// from inlining the dev section into SettingsView caused Swift's
/// metadata demangler to stack-overflow when rendering Settings (crash
/// log 2026-05-15 21:48:44). Splitting into multiple nominal View types
/// keeps each body type bounded.

struct DeveloperSettingsSection: View {
    @State var message: String = ""
    @State var confirmWipe: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DEVELOPER")
                .font(.system(size: 11, weight: .heavy)).tracking(1.2)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                DevStatsBlock()
                DevNotificationsDiagnosticBlock()
                DevWidgetDiagnosticBlock()
                DevSchemaBlock(message: $message)
                DevShareInspectBlock(message: $message)
                DevShareResetBlock(message: $message)
                DevNukeBlock(message: $message)
                DevOwnerBlock(message: $message)
                DevWipeBlock(message: $message, confirmWipe: $confirmWipe)
                DevMessageBlock(message: message)
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: – Stats

private struct DevStatsBlock: View {
    @FetchRequest(sortDescriptors: [], predicate: NSPredicate(format: "deletedAt == nil"))
    private var members: FetchedResults<FamilyMember>
    @FetchRequest(sortDescriptors: [], predicate: NSPredicate(format: "deletedAt == nil"))
    private var tasks: FetchedResults<TaskItem>
    @FetchRequest(sortDescriptors: [], predicate: NSPredicate(format: "deletedAt == nil"))
    private var households: FetchedResults<Household>

    var body: some View {
        Group {
            DevInfoRow(title: "Family members", value: "\(members.count)")
            DevDivider()
            DevInfoRow(title: "Tasks", value: "\(tasks.count)")
            DevDivider()
            DevInfoRow(title: "Households", value: "\(households.count)")
            DevDivider()
        }
    }
}

// MARK: – Schema

private struct DevSchemaBlock: View {
    @Binding var message: String
    @Environment(\.managedObjectContext) private var moc

    var body: some View {
        Group {
            DevActionRow(title: "Seed schema records") { seedSchemaRecords() }
            DevDivider()
            DevActionRow(title: "Init CloudKit schema (dev)") { initSchema() }
            DevDivider()
            DevActionRow(title: "Remove test members") { removeTestMembers() }
            DevDivider()
        }
    }

    private func seedSchemaRecords() {
        guard let household = (try? moc.fetch(Household.fetchRequest()))?.first else {
            message = "No household to seed against."; return
        }
        let temp = FamilyMember(context: moc, name: "Schema-\(UUID().uuidString.prefix(6))",
                                role: "Schema seed", colorHex: 0xC97357, roleLevel: .admin)
        moc.assign(temp, toStoreOf: household)
        temp.household = household
        try? moc.save()
        message = "Seeded one Schema-* member. Remove via the button below."
    }

    private func initSchema() {
        Task {
            do {
                try CasaCoreDataStack.shared.initializeCloudKitSchemaForDevelopment()
                await MainActor.run { message = "Schema initialized in Dev. Diff + deploy via Dashboard." }
            } catch {
                let ns = error as NSError
                NSLog("Casa initializeCloudKitSchema FULL ERROR: \(ns)")
                await MainActor.run { message = "init failed: \(ns.localizedDescription)" }
            }
        }
    }

    private func removeTestMembers() {
        let req: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
        let all = (try? moc.fetch(req)) ?? []
        let stale = all.filter {
            $0.name.hasPrefix("Schema-") || $0.role == "Schema seed"
                || ($0.name == "Test" && $0.role == "You")
        }
        for m in stale { moc.delete(m) }
        if !stale.isEmpty { try? moc.save() }
        message = "Removed \(stale.count) Schema-* test member(s)."
    }
}

// MARK: – Share inspection

private struct DevShareInspectBlock: View {
    @Binding var message: String
    @Environment(\.managedObjectContext) private var moc
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)],
                  predicate: NSPredicate(format: "deletedAt == nil"))
    private var households: FetchedResults<Household>

    var body: some View {
        Group {
            DevActionRow(title: "Leave shared household") { leaveShared() }
            DevDivider()
            DevActionRow(title: "Inspect & fix share permissions") { inspectShare() }
            DevDivider()
            DevActionRow(title: "Inspect local store assignments") { inspectStores() }
            DevDivider()
            DevActionRow(title: "View sync log (last 30)") { viewLog() }
            DevDivider()
        }
    }

    private func leaveShared() {
        let stack = CasaCoreDataStack.shared
        guard let sharedStore = stack.sharedStore else { message = "Shared store not available."; return }
        let shared = households.filter { $0.objectID.persistentStore === sharedStore }
        guard !shared.isEmpty else { message = "No shared households to leave."; return }
        var zoneIDs = Set<CKRecordZone.ID>()
        for h in shared {
            if let record = try? stack.container.record(for: h.objectID) {
                zoneIDs.insert(record.recordID.zoneID)
            }
        }
        guard !zoneIDs.isEmpty else { message = "No CloudKit zones to purge yet — try again."; return }
        let count = shared.count
        let group = DispatchGroup()
        var failure: Error? = nil
        for zid in zoneIDs {
            group.enter()
            stack.container.purgeObjectsAndRecordsInZone(with: zid, in: sharedStore) { _, error in
                if let error { failure = error }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            if let failure { message = "Leave failed: \(failure.localizedDescription)" }
            else { message = "Left \(count) shared household(s)." }
        }
    }

    private func inspectShare() {
        let stack = CasaCoreDataStack.shared
        guard let mine = households.first(where: { $0.objectID.persistentStore === stack.privateStore }) else {
            message = "No private household."; return
        }
        do {
            let map = try stack.container.fetchShares(matching: [mine.objectID])
            guard let share = map[mine.objectID] else {
                message = "Household isn't shared yet."; return
            }
            var report = "Participants (\(share.participants.count)):\n"
            var changed = false
            for p in share.participants {
                let email = p.userIdentity.lookupInfo?.emailAddress ?? "?"
                let accept = p.acceptanceStatus == .accepted ? "accepted" : "\(p.acceptanceStatus)"
                let perm = p.permission == .readWrite ? "rw" : "\(p.permission)"
                report += "• \(email) \(p.role == .owner ? "owner" : "participant") \(accept) \(perm)\n"
                if p.role != .owner && p.permission != .readWrite {
                    p.permission = .readWrite; changed = true
                }
            }
            if !changed { message = report + "All read-write already."; return }
            let ck = CKContainer(identifier: casalistCloudKitContainerID)
            let op = CKModifyRecordsOperation(recordsToSave: [share], recordIDsToDelete: nil)
            op.savePolicy = .changedKeys
            op.modifyRecordsResultBlock = { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success: message = report + "Fixed read-write."
                    case .failure(let e): message = report + "Save failed: \(e.localizedDescription)"
                    }
                }
            }
            ck.privateCloudDatabase.add(op)
        } catch {
            message = "fetchShares failed: \(error.localizedDescription)"
        }
    }

    private func inspectStores() {
        let stack = CasaCoreDataStack.shared
        var out = "Stores:\n"
        out += "  private = \(stack.privateStore?.identifier ?? "nil")\n"
        out += "  shared  = \(stack.sharedStore?.identifier ?? "nil")\n"
        for entity in ["Household", "FamilyMember", "TaskItem", "FamilyGoal", "FamilyEvent"] {
            let req = NSFetchRequest<NSManagedObject>(entityName: entity)
            let all = (try? moc.fetch(req)) ?? []
            let priv = all.filter { $0.objectID.persistentStore === stack.privateStore }.count
            let sh = all.filter { $0.objectID.persistentStore === stack.sharedStore }.count
            out += "  \(entity): priv=\(priv) shared=\(sh)\n"
        }
        message = out
    }

    private func viewLog() {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = docs.appendingPathComponent("share-log.txt")
        guard let handle = try? FileHandle(forReadingFrom: url) else { message = "No sync log yet."; return }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let tail: UInt64 = 20_000
        try? handle.seek(toOffset: size > tail ? size - tail : 0)
        let data = (try? handle.readToEnd()) ?? Data()
        if let text = String(data: data, encoding: .utf8) {
            message = text.split(separator: "\n").suffix(30).joined(separator: "\n")
        }
    }
}

// MARK: – Share reset

private struct DevShareResetBlock: View {
    @Binding var message: String
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)],
                  predicate: NSPredicate(format: "deletedAt == nil"))
    private var households: FetchedResults<Household>

    var body: some View {
        Group {
            DevActionRow(title: "Clear stuck share invitation") { clearStuck() }
            DevDivider()
            DevActionRow(title: "Reset share (owner) — delete CKShare") { resetShare() }
            DevDivider()
        }
    }

    private func clearStuck() {
        let kv = NSUbiquitousKeyValueStore.default
        kv.removeObject(forKey: CasalistAppDelegate.lastShareURLKey)
        kv.synchronize()
        CasalistAppDelegate.clearBadShareList()
        message = "Cleared saved share URL + bad-share cache. Restart the app."
    }

    private func resetShare() {
        let stack = CasaCoreDataStack.shared
        guard let mine = households.first(where: { $0.objectID.persistentStore === stack.privateStore }) else {
            message = "No private household."; return
        }
        do {
            let map = try stack.container.fetchShares(matching: [mine.objectID])
            guard let share = map[mine.objectID] else { message = "Not shared yet."; return }
            let ck = CKContainer(identifier: casalistCloudKitContainerID)
            let op = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [share.recordID])
            op.modifyRecordsResultBlock = { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success: message = "Old share deleted. Re-invite to create fresh."
                    case .failure(let e): message = "Delete failed: \(e.localizedDescription)"
                    }
                }
            }
            ck.privateCloudDatabase.add(op)
        } catch {
            message = "fetchShares failed: \(error.localizedDescription)"
        }
    }
}

// MARK: – Nuke / merge

private struct DevNukeBlock: View {
    @Binding var message: String
    @Environment(\.managedObjectContext) private var moc
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)],
                  predicate: NSPredicate(format: "deletedAt == nil"))
    private var households: FetchedResults<Household>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)],
                  predicate: NSPredicate(format: "deletedAt == nil"))
    private var members: FetchedResults<FamilyMember>
    @FetchRequest(sortDescriptors: [])
    private var allTasks: FetchedResults<TaskItem>
    @AppStorage("userName") private var userName: String = ""

    var body: some View {
        Group {
            DevActionRow(title: "Merge duplicate households") { mergeHouseholds() }
            DevDivider()
            DevActionRow(title: "⚠️ Wipe ALL stats (points, XP, streaks, badges, task history)") { wipeAllStats() }
            DevDivider()
            DevActionRow(title: "Wipe all points + lifetime XP") { wipePoints() }
            DevDivider()
            DevActionRow(title: "Wipe all streaks + badges") { wipeStreaksAndBadges() }
            DevDivider()
            DevActionRow(title: "Dump state to share log") { dumpState() }
            DevDivider()
            DevActionRow(title: "Nuke ALL local data (hard delete)") { nukeAll() }
            DevDivider()
        }
    }

    private func wipeAllStats() {
        // 1. Points + XP
        for m in members { m.points = 0; m.lifetimePoints = 0 }
        // 2. Task completion history — clear completedAt so card stats reset to 0
        for t in allTasks {
            if t.completedAt != nil { t.completedAt = nil }
            if t.isCompleted { t.isCompleted = false }
            t.completionCount = 0
        }
        try? moc.save()
        // 3. Streaks + badges from UserDefaults
        let ud = UserDefaults.standard
        ud.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("streak_") || $0.hasPrefix("badges_") || $0.hasPrefix("reminder_streak_") }
            .forEach { ud.removeObject(forKey: $0) }
        message = "Wiped all stats: points, XP, streaks, badges, task completion history."
    }

    private func wipePoints() {
        for m in members {
            m.points = 0
            m.lifetimePoints = 0
        }
        try? moc.save()
        message = "Wiped points + lifetime XP for \(members.count) member(s)."
    }

    private func wipeStreaksAndBadges() {
        let ud = UserDefaults.standard
        let keysToRemove = ud.dictionaryRepresentation().keys.filter {
            $0.hasPrefix("streak_") || $0.hasPrefix("badges_") || $0.hasPrefix("reminder_streak_")
        }
        keysToRemove.forEach { ud.removeObject(forKey: $0) }
        message = "Wiped streaks + badges (\(keysToRemove.count) keys cleared)."
    }

    private func mergeHouseholds() {
        let stack = CasaCoreDataStack.shared
        let privates = households.filter { $0.objectID.persistentStore === stack.privateStore }
        guard privates.count > 1 else { message = "Only one private household."; return }
        func liveCount(_ h: Household) -> Int {
            ((h.members as? Set<FamilyMember>) ?? []).filter { $0.deletedAtValue == nil }.count
        }
        let survivor = privates.max(by: { a, b in
            let am = liveCount(a), bm = liveCount(b)
            if am != bm { return am < bm }
            return a.createdAt > b.createdAt
        })!
        var moved = 0
        for h in privates where h !== survivor {
            for m in (h.members as? Set<FamilyMember>) ?? [] { m.household = survivor; moved += 1 }
            for t in (h.tasks as? Set<TaskItem>) ?? [] { t.household = survivor; moved += 1 }
            for g in (h.goals as? Set<FamilyGoal>) ?? [] { g.household = survivor; moved += 1 }
            for e in (h.events as? Set<FamilyEvent>) ?? [] { e.household = survivor; moved += 1 }
            h.softDelete()
        }
        try? moc.save()
        message = "Merged \(privates.count) → 1. Moved \(moved) child records."
    }

    private func dumpState() {
        let stack = CasaCoreDataStack.shared
        let meUid = UserDefaults.standard.string(forKey: "meUid") ?? ""
        var out = "\n===== STATE DUMP @ \(Date()) =====\n"
        out += "userName=\(userName)  meUid=\(meUid)\n"
        out += "HOUSEHOLDS (\(households.count)):\n"
        for h in households {
            let s = h.objectID.persistentStore === stack.sharedStore ? "SHARED" : "PRIVATE"
            let live = ((h.members as? Set<FamilyMember>) ?? []).filter { $0.deletedAtValue == nil }.count
            out += "  [\(s)] \(h.name) uid=\(h.uid.uuidString.prefix(8)) members=\(live)\n"
        }
        out += "FAMILYMEMBERS (\(members.count)):\n"
        for m in members {
            let s = m.objectID.persistentStore === stack.sharedStore ? "SHARED" : "PRIVATE"
            let isMe = m.uid.uuidString == meUid ? " ← ME" : ""
            let idTag = m.userID.isEmpty ? "no-id" : "id=\(m.userID.prefix(10))…"
            out += "  [\(s)] \(m.name) role=\(m.roleLevel) \(idTag)\(isMe)\n"
        }
        out += "===== END =====\n"
        CasalistAppDelegate.appendShareLog(out)
        message = "State dumped. Tap 'View sync log' to see."
    }

    private func nukeAll() {
        let entities = ["FamilyMember", "TaskItem", "FamilyGoal", "FamilyEvent",
                        "ChoreTemplate", "Household"]
        var total = 0
        for name in entities {
            let req = NSFetchRequest<NSManagedObject>(entityName: name)
            if let objs = try? moc.fetch(req) {
                for o in objs { moc.delete(o) }
                total += objs.count
            }
        }
        try? moc.save()
        let defaults = UserDefaults.standard
        // Clear identity AppStorage too so the welcome screen actually
        // shows on reopen. Without clearing userName, the auto-self-heal
        // recreates a FamilyMember from the cached name on next foreground
        // and looks like the nuke didn't work.
        defaults.removeObject(forKey: "meUid")
        defaults.removeObject(forKey: "failedShareRecordIDs")
        defaults.removeObject(forKey: "userName")
        defaults.removeObject(forKey: "householdName")
        let kv = NSUbiquitousKeyValueStore.default
        kv.removeObject(forKey: CasalistAppDelegate.lastShareURLKey)
        kv.synchronize()
        message = "Hard-deleted \(total) records + cleared userName. Force-quit + reopen."
    }
}

// MARK: – Owner tools

private struct DevOwnerBlock: View {
    @Binding var message: String
    @Environment(\.managedObjectContext) private var moc
    @AppStorage("userName") private var userName: String = ""
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)],
                  predicate: NSPredicate(format: "deletedAt == nil"))
    private var households: FetchedResults<Household>

    var body: some View {
        Group {
            DevActionRow(title: "Move me into shared store") { moveMe() }
            DevDivider()
            DevActionRow(title: "Demote me to standard") { demoteMe() }
            DevDivider()
        }
    }

    private func moveMe() {
        let stack = CasaCoreDataStack.shared
        guard let shared = households.first(where: { $0.objectID.persistentStore === stack.sharedStore }) else {
            message = "No shared household — accept an invite first."; return
        }
        let trimmed = userName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { message = "Set your name first."; return }
        let req: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
        req.predicate = NSPredicate(format: "deletedAt == nil AND name ==[c] %@", trimmed)
        let matches = (try? moc.fetch(req)) ?? []
        let priv = matches.first(where: { $0.objectID.persistentStore === stack.privateStore })
        let inShared = matches.first(where: { $0.objectID.persistentStore === stack.sharedStore })
        if inShared != nil && priv == nil { message = "Already in shared store."; return }
        let new = FamilyMember(context: moc, name: trimmed,
                               role: priv?.role ?? "Member",
                               colorHex: Int(priv?.colorHex ?? 0x7AB97D),
                               roleLevel: .standard)
        moc.assign(new, toStoreOf: shared)
        new.household = shared
        if let blob = priv?.photoBlob { new.photoBlob = blob }
        if let pts = priv?.points { new.points = pts }
        priv?.softDelete()
        UserDefaults.standard.set(new.uid.uuidString, forKey: "meUid")
        try? moc.save()
        message = "Created \(trimmed) in shared store. Will sync in ~30s."
    }

    private func demoteMe() {
        let trimmed = userName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { message = "Set your name first."; return }
        let req: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
        req.predicate = NSPredicate(format: "deletedAt == nil AND name ==[c] %@", trimmed)
        let matches = (try? moc.fetch(req)) ?? []
        for m in matches { m.roleLevel = FamilyRole.standard.rawValue }
        try? moc.save()
        message = "Set \(matches.count) record(s) to standard."
    }
}

// MARK: – Wipe

private struct DevWipeBlock: View {
    @Binding var message: String
    @Binding var confirmWipe: Bool
    @Environment(\.managedObjectContext) private var moc

    var body: some View {
        Button(role: .destructive) { confirmWipe = true } label: {
            HStack {
                Image(systemName: "trash").font(.system(size: 14, weight: .bold))
                Text("Clear all data").font(.system(size: 14, weight: .heavy))
                Spacer()
            }
            .foregroundStyle(.red)
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .confirmationDialog("Clear chores/goals/events?", isPresented: $confirmWipe, titleVisibility: .visible) {
            Button("Wipe", role: .destructive) { wipeAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deletes tasks, goals, chores, events. Members + household + profile preserved.")
        }
    }

    private func wipeAll() {
        let entities = ["TaskItem", "FamilyGoal", "FamilyEvent", "ChoreTemplate"]
        var total = 0
        for name in entities {
            let req = NSFetchRequest<NSManagedObject>(entityName: name)
            if let objs = try? moc.fetch(req) {
                for o in objs { moc.delete(o) }
                total += objs.count
            }
        }
        try? moc.save()
        message = "Wiped \(total) records. Family + household preserved."
    }
}

// MARK: – Message footer

private struct DevMessageBlock: View {
    let message: String
    var body: some View {
        if message.isEmpty {
            EmptyView()
        } else {
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: – Shared mini-components

private struct DevDivider: View {
    var body: some View {
        Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 1).padding(.leading, 16)
    }
}

private struct DevInfoRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack {
            Text(title).font(.system(size: 14, weight: .semibold))
            Spacer()
            Text(value).font(.system(size: 14, weight: .heavy)).foregroundStyle(.secondary)
        }.padding(.horizontal, 16).padding(.vertical, 12)
    }
}

private struct DevActionRow: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 14, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }.buttonStyle(.row)
    }
}

// MARK: - Widget diagnostic

/// Surfaces the App Group state for the widget so we can tell at a
/// glance whether the main app is writing the snapshot to the
/// correct shared container (where the Widget Extension reads from).
// MARK: – Notifications diagnostic

private struct DevNotificationsDiagnosticBlock: View {
    @State private var info: String = "(tap to check)"

    var body: some View {
        Group {
            DevActionRow(title: "Notification permission check") { checkPermission() }
            DevDivider()
            DevActionRow(title: "Fire test notification (10s)") { fireTest() }
            DevDivider()
            DevActionRow(title: "List pending notifications") { listPending() }
            DevDivider()
            if !info.isEmpty {
                Text(info)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 16).padding(.bottom, 12)
                DevDivider()
            }
        }
    }

    private func checkPermission() {
        Task {
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            let label: String
            switch status {
            case .authorized: label = "authorized"
            case .denied:     label = "DENIED"
            case .notDetermined: label = "notDetermined"
            case .provisional: label = "provisional"
            case .ephemeral:  label = "ephemeral"
            @unknown default: label = "unknown"
            }
            await MainActor.run { info = "Status: \(label)" }
        }
    }

    private func fireTest() {
        Task {
            let granted = await NotificationsManager.requestAuth()
            guard granted else {
                await MainActor.run { info = "Permission denied — go to Settings > Notifications > Casalist Dev" }
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "Notification test"
            content.body = "Fired at \(Date().formatted(date: .omitted, time: .standard))"
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
            let req = UNNotificationRequest(identifier: "dev-test-\(UUID().uuidString)", content: content, trigger: trigger)
            do {
                try await UNUserNotificationCenter.current().add(req)
                await MainActor.run { info = "Test notification queued — lock screen in 10s" }
            } catch {
                await MainActor.run { info = "add() error: \(error)" }
            }
        }
    }

    private func listPending() {
        Task {
            let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
            let taskNotifs = pending.filter { $0.identifier.hasPrefix("task-") }
            var lines = ["Pending: \(pending.count) total, \(taskNotifs.count) task-*"]
            for r in taskNotifs.prefix(10) {
                let triggerDesc: String
                if let t = r.trigger as? UNCalendarNotificationTrigger {
                    let dc = t.dateComponents
                    triggerDesc = "\(dc.year ?? 0)-\(dc.month ?? 0)-\(dc.day ?? 0) \(dc.hour ?? 0):\(String(format: "%02d", dc.minute ?? 0))"
                } else if let t = r.trigger as? UNTimeIntervalNotificationTrigger {
                    triggerDesc = "in \(Int(t.timeInterval))s"
                } else {
                    triggerDesc = "?"
                }
                lines.append("• \(r.identifier.suffix(20)) @ \(triggerDesc)")
            }
            if taskNotifs.count > 10 { lines.append("... +\(taskNotifs.count - 10) more") }
            await MainActor.run { info = lines.joined(separator: "\n") }
        }
    }
}

private struct DevWidgetDiagnosticBlock: View {
    @State private var info: String = "(tap to check)"

    var body: some View {
        Group {
            DevActionRow(title: "Widget App Group diagnostic") { run() }
            DevDivider()
            if !info.isEmpty {
                Text(info)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 16).padding(.bottom, 12)
                DevDivider()
            }
        }
    }

    private func run() {
        var lines: [String] = []
        lines.append("group: \(AppGroup.identifier)")
        let url = AppGroup.containerURL
        let isFallback = !url.absoluteString.contains("/Group/") &&
                         !url.absoluteString.contains("Containers/Shared/AppGroup")
        lines.append("URL: \(url.lastPathComponent)/.../")
        lines.append("path-tail: ...\(url.absoluteString.suffix(60))")
        lines.append("fallback?: \(isFallback ? "YES (App Group NOT linked)" : "no (App Group OK)")")
        if let snap = TodayReminderSnapshot.load() {
            lines.append("snapshot: \(snap.entries.count) entries")
            lines.append("written: \(snap.generatedAt.formatted(date: .omitted, time: .standard))")
        } else {
            lines.append("snapshot: not found at this path")
        }
        info = lines.joined(separator: "\n")
    }
}
