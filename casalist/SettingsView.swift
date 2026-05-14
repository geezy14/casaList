import SwiftUI
import CoreData
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(\.colorScheme) private var sys
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var moc
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("householdName") private var householdName: String = "My Household"
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("meUid") private var meUid: String = ""

    @State private var notifStatus: String = "Checking…"
    @State private var pendingCount: Int = 0
    @State private var lastTestResult: String? = nil
    @State private var pendingList: [String] = []
    @State private var confirmWipe: Bool = false
    @State private var wipeMessage: String? = nil
    @State private var promoteTarget: FamilyMember? = nil
    @State private var showPromote: Bool = false
    @State private var transferTarget: FamilyMember? = nil
    @State private var showTransfer: Bool = false

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)])
    private var members: FetchedResults<FamilyMember>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: true)])
    private var tasks: FetchedResults<TaskItem>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)])
    private var households: FetchedResults<Household>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyGoal.createdAt, ascending: true)])
    private var goals: FetchedResults<FamilyGoal>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \ChoreTemplate.createdAt, ascending: true)])
    private var chores: FetchedResults<ChoreTemplate>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyEvent.createdAt, ascending: true)])
    private var events: FetchedResults<FamilyEvent>

    private var P: CasalistCottage.Palette { CasalistCottage.Palette.resolve(sys == .dark) }
    private var me: FamilyMember? {
        FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)
    }
    private var iAmOwner: Bool { me?.isOwner ?? false }
    private var iAmAdmin: Bool { me?.canManageFamily ?? false }
    private var adminCount: Int { FamilyPermissions.adminCount(in: members) }

    var body: some View {
        ZStack {
            P.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                ScrollView { content }.scrollIndicators(.hidden)
            }
        }
        .foregroundStyle(P.text)
        .task {
            removeSchemaSeedMembers()
            FamilyPermissions.ensureOwner(members: members, context: moc)
            adoptMeIfNeeded()
            await refreshNotifStatus()
            await refreshPending()
        }
        .onChange(of: notificationsEnabled) { _, on in
            Task {
                if on {
                    _ = await NotificationsManager.requestAuth()
                    await NotificationsManager.syncFromContext(moc)
                } else {
                    await NotificationsManager.cancelAll()
                }
                await refreshNotifStatus()
            }
        }
        .confirmationDialog("Clear all data?", isPresented: $confirmWipe, titleVisibility: .visible) {
            Button("Wipe everything", role: .destructive) { wipeAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deletes all tasks, goals, chores, and events on this device. Family members, household, and your profile are preserved. Cannot be undone.")
        }
        .alert("Change role?", isPresented: $showPromote, presenting: promoteTarget) { m in
            let next: FamilyRole = m.level == .admin ? .standard : .admin
            Button(next == .admin ? "Make admin" : "Remove admin") { setRole(m, to: next) }
            Button("Cancel", role: .cancel) {}
        } message: { m in
            let next: FamilyRole = m.level == .admin ? .standard : .admin
            Text(next == .admin
                ? "\(m.name) will be able to invite members, manage chores, and adjust points."
                : "\(m.name) will become a standard member.")
        }
        .sheet(isPresented: $showTransfer) {
            if let t = transferTarget { transferOwnerSheet(target: t) }
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(P.text)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(P.surfaceAlt))
            }
            Spacer()
            Text("Settings").font(.system(size: 16, weight: .heavy))
            Spacer()
            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            profileSection
            householdSection
            familySection
            notificationsSection
            developerSection
            Text("Casalist").font(.caption).foregroundStyle(P.textMuted)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
    }

    // MARK: Profile

    private var profileSection: some View {
        section(title: "PROFILE") {
            VStack(spacing: 0) {
                fieldRow(title: "Your name") {
                    TextField("Your name", text: $userName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(P.text)
                }
                if let me {
                    divider
                    HStack {
                        Text("Your role").font(.system(size: 14, weight: .semibold))
                        Spacer()
                        roleBadge(me.level)
                    }.padding(.horizontal, 16).padding(.vertical, 12)
                }
            }
            .cardBg(P)
        }
    }

    // MARK: Household

    private var householdSection: some View {
        section(title: "HOUSEHOLD") {
            VStack(spacing: 0) {
                fieldRow(title: "Household name") {
                    TextField("Household name", text: $householdName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .multilineTextAlignment(.trailing)
                        .disabled(!iAmAdmin)
                        .foregroundStyle(iAmAdmin ? P.text : P.textMuted)
                }
            }
            .cardBg(P)
        }
    }

    // MARK: Family / roles

    private var familySection: some View {
        section(title: "FAMILY") {
            VStack(spacing: 0) {
                if members.isEmpty {
                    Text("No family members yet")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(P.textMuted)
                        .frame(maxWidth: .infinity).padding(.vertical, 22)
                } else {
                    ForEach(Array(members.enumerated()), id: \.element.uid) { idx, m in
                        memberRow(m)
                        if idx < members.count - 1 { divider }
                    }
                }
            }
            .cardBg(P)
            if iAmOwner && members.count > 1 {
                Text("Tap a star to promote an admin. Hold the crown to transfer ownership.")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(P.textMuted)
                    .padding(.horizontal, 4).padding(.top, 4)
            }
        }
    }

    private func memberRow(_ m: FamilyMember) -> some View {
        let isMe = m.uid.uuidString == meUid || m.name.lowercased() == userName.lowercased()
        return HStack(spacing: 12) {
            avatar(for: m)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(m.name).font(.system(size: 14, weight: .heavy))
                    if isMe {
                        Text("YOU").font(.system(size: 9, weight: .heavy))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(P.peach.opacity(0.25)))
                            .foregroundStyle(P.peach)
                    }
                }
                Text("\(m.points) pts").font(.caption).foregroundStyle(P.textMuted)
            }
            Spacer()
            roleControl(for: m)
            if iAmOwner && !isMe {
                Button { deleteMember(m) } label: {
                    Image(systemName: "trash").font(.system(size: 12))
                        .foregroundStyle(P.textMuted)
                        .frame(width: 30, height: 30)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func deleteMember(_ m: FamilyMember) {
        moc.delete(m)
        try? moc.save()
    }

    @ViewBuilder
    private func roleControl(for m: FamilyMember) -> some View {
        if m.isOwner {
            Button {
                if iAmOwner && m.uid.uuidString == me?.uid.uuidString {
                    transferTarget = m; showTransfer = true
                }
            } label: {
                roleBadge(.owner)
            }.buttonStyle(.plain)
        } else if iAmOwner {
            Button { promoteTarget = m; showPromote = true } label: {
                roleBadge(m.level)
            }.buttonStyle(.plain)
        } else {
            roleBadge(m.level)
        }
    }

    private func roleBadge(_ r: FamilyRole) -> some View {
        let tint: Color = r == .owner ? P.butter : (r == .admin ? P.peach : P.textMuted)
        return HStack(spacing: 4) {
            Image(systemName: r.symbol).font(.system(size: 10, weight: .heavy))
            Text(r.label).font(.system(size: 11, weight: .heavy))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(tint.opacity(0.18)))
        .foregroundStyle(tint)
    }

    private func setRole(_ m: FamilyMember, to next: FamilyRole) {
        if next == .admin && adminCount >= 2 {
            wipeMessage = "Max 2 admins. Demote one first."
            return
        }
        m.roleLevel = next.rawValue
        try? moc.save()
    }

    private func transferOwnerSheet(target: FamilyMember) -> some View {
        NavigationStack {
            ZStack {
                P.bg.ignoresSafeArea()
                VStack(spacing: 16) {
                    Image(systemName: "crown.fill").font(.system(size: 36)).foregroundStyle(P.butter)
                    Text("Transfer ownership?").font(.system(size: 20, weight: .heavy))
                    Text("Pick a family member to make the new household owner. You'll become an admin.")
                        .font(.system(size: 13)).foregroundStyle(P.textDim)
                        .multilineTextAlignment(.center).padding(.horizontal, 24)
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(members.filter { !$0.isOwner }) { m in
                                Button {
                                    transferOwnership(to: m)
                                    showTransfer = false
                                } label: {
                                    HStack(spacing: 12) {
                                        avatar(for: m)
                                        Text(m.name).font(.system(size: 14, weight: .heavy))
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(P.textMuted)
                                    }.padding(.horizontal, 14).padding(.vertical, 10)
                                }.buttonStyle(.plain)
                                if m.uid != members.filter({ !$0.isOwner }).last?.uid { divider }
                            }
                        }.cardBg(P)
                    }
                    Button("Cancel") { showTransfer = false }
                        .font(.system(size: 14, weight: .heavy)).foregroundStyle(P.textMuted)
                }
                .padding(20)
            }
            .foregroundStyle(P.text)
        }
    }

    private func transferOwnership(to newOwner: FamilyMember) {
        for m in members where m.isOwner { m.roleLevel = FamilyRole.admin.rawValue }
        newOwner.roleLevel = FamilyRole.owner.rawValue
        try? moc.save()
    }

    private func removeSchemaSeedMembers() {
        let stale = members.filter {
            $0.name.hasPrefix("Schema-")
            || $0.role == "Schema seed"
            || ($0.name == "Test" && $0.role == "You")
        }
        for m in stale { moc.delete(m) }
        if !stale.isEmpty { try? moc.save() }
    }

    private func adoptMeIfNeeded() {
        guard meUid.isEmpty else { return }
        let trimmed = userName.trimmingCharacters(in: .whitespaces).lowercased()
        if !trimmed.isEmpty, let m = members.first(where: { $0.name.lowercased() == trimmed }) {
            meUid = m.uid.uuidString
        }
    }

    // MARK: Notifications

    private var notificationsSection: some View {
        section(title: "NOTIFICATIONS") {
            VStack(spacing: 0) {
                Toggle("Due-date reminders", isOn: $notificationsEnabled)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .tint(P.peach)
                divider
                infoRow("System permission", value: notifStatus)
                divider
                infoRow("Pending notifications", value: "\(pendingCount)")
                divider
                actionButton("Send test (5s)") { Task { await sendTestNotification(delay: 5) } }
                divider
                actionButton("Send test (30s — lock phone)") { Task { await sendTestNotification(delay: 30) } }
                divider
                actionButton("Refresh scheduled list") { Task { await refreshPending() } }
                if !pendingList.isEmpty {
                    divider
                    DisclosureGroup("Scheduled (\(pendingList.count))") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(pendingList, id: \.self) { line in
                                Text(line).font(.caption.monospaced()).foregroundStyle(P.textMuted)
                            }
                        }.padding(.top, 4)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .accentColor(P.peach)
                }
                if notifStatus.contains("Denied") {
                    divider
                    actionButton("Open iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                if let lastTestResult {
                    divider
                    Text(lastTestResult).font(.caption).foregroundStyle(P.textMuted)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                }
            }.cardBg(P)
        }
    }

    // MARK: Developer

    private var developerSection: some View {
        section(title: "DEVELOPER") {
            VStack(spacing: 0) {
                infoRow("Family members", value: "\(members.count)")
                divider
                infoRow("Tasks", value: "\(tasks.count)")
                divider
                infoRow("Households", value: "\(households.count)")
                divider
                actionButton("Seed schema records") { seedSchemaRecords() }
                divider
                actionButton("Init CloudKit schema (dev)") {
                    Task {
                        do {
                            try CasaCoreDataStack.shared.initializeCloudKitSchemaForDevelopment()
                            await MainActor.run { wipeMessage = "Schema initialized in Dev. Diff + deploy via Dashboard." }
                        } catch {
                            let ns = error as NSError
                            let full = "\(ns)\n\nUserInfo:\n\(ns.userInfo as AnyObject)"
                            // Write to a file we can read later with devicectl device info files
                            if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                                let url = docs.appendingPathComponent("init-error.txt")
                                try? full.data(using: .utf8)?.write(to: url)
                            }
                            NSLog("Casa initializeCloudKitSchema FULL ERROR: \(full)")
                            await MainActor.run { wipeMessage = "init failed (full error written to docs/init-error.txt): \(ns.localizedDescription)" }
                        }
                    }
                }
                divider
                actionButton("Remove test members") {
                    removeSchemaSeedMembers()
                    wipeMessage = "Removed any Schema-* test members."
                }
                divider
                Button(role: .destructive) { confirmWipe = true } label: {
                    HStack {
                        Image(systemName: "trash").font(.system(size: 14, weight: .bold))
                        Text("Clear all data").font(.system(size: 14, weight: .heavy))
                        Spacer()
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                if let wipeMessage {
                    divider
                    Text(wipeMessage).font(.caption).foregroundStyle(P.textMuted)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                }
            }.cardBg(P)
        }
    }

    // MARK: Building blocks

    @ViewBuilder
    private func section<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 11, weight: .heavy)).tracking(1.2)
                .foregroundStyle(P.textDim).padding(.leading, 4)
            content()
        }
    }

    private func fieldRow<C: View>(title: String, @ViewBuilder field: () -> C) -> some View {
        HStack {
            Text(title).font(.system(size: 14, weight: .semibold))
            Spacer()
            field()
        }.padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func infoRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).font(.system(size: 14, weight: .semibold))
            Spacer()
            Text(value).font(.system(size: 14, weight: .heavy)).foregroundStyle(P.textMuted)
        }.padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 14, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(P.textMuted)
            }
            .foregroundStyle(P.text)
            .padding(.horizontal, 16).padding(.vertical, 12)
        }.buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle().fill(P.border).frame(height: 1).padding(.leading, 16)
    }

    @ViewBuilder
    private func avatar(for m: FamilyMember) -> some View {
        if let data = m.photoData, let ui = UIImage(data: data) {
            Image(uiImage: ui).resizable().scaledToFill()
                .frame(width: 36, height: 36).clipShape(Circle())
        } else {
            Text(String(m.name.prefix(1)).uppercased())
                .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                .frame(width: 36, height: 36).background(Circle().fill(m.color))
        }
    }

    // MARK: Actions

    private func seedSchemaRecords() {
        let tempName = "Schema-\(UUID().uuidString.prefix(6))"
        let temp = FamilyMember(context: moc, name: tempName, role: "Schema seed", colorHex: 0xC97357, roleLevel: .admin)
        if let h = households.first {
            moc.assign(temp, toStoreOf: h)
            temp.household = h
        }
        let name = userName.trimmingCharacters(in: .whitespaces)
        let ownerName = name.isEmpty ? "Test" : name
        let goal = FamilyGoal(context: moc, ownerName: ownerName, label: "Schema test", targetPoints: 100)
        if let h = households.first {
            moc.assign(goal, toStoreOf: h)
            goal.household = h
        }
        let chore = ChoreTemplate(context: moc, label: "Schema test", points: 10, symbol: "checkmark.circle")
        if let h = households.first {
            moc.assign(chore, toStoreOf: h)
            chore.household = h
        }
        try? moc.save()
        wipeMessage = "Seeded — wait ~10s then deploy via Dashboard. Temp member: \(tempName)"
    }

    private func wipeAll() {
        let totalBefore = tasks.count + goals.count + chores.count + events.count
        for t in tasks { moc.delete(t) }
        for g in goals { moc.delete(g) }
        for c in chores { moc.delete(c) }
        for e in events { moc.delete(e) }
        for m in members { m.points = 0 }
        try? moc.save()
        wipeMessage = "Cleared \(totalBefore) records. Family and household preserved."
    }

    private func refreshPending() async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let f = DateFormatter()
        f.dateFormat = "MMM d h:mm a"
        let lines = pending.map { req -> String in
            let when: String
            if let cal = req.trigger as? UNCalendarNotificationTrigger,
               let next = cal.nextTriggerDate() {
                when = f.string(from: next)
            } else if let ti = req.trigger as? UNTimeIntervalNotificationTrigger,
                      let next = ti.nextTriggerDate() {
                when = f.string(from: next)
            } else {
                when = "?"
            }
            let title = req.content.title
            return "\(when) — \(title.isEmpty ? req.identifier : title)"
        }.sorted()
        await MainActor.run {
            pendingCount = pending.count
            pendingList = lines
        }
    }

    private func sendTestNotification(delay: TimeInterval = 5) async {
        let granted = await NotificationsManager.requestAuth()
        let status = await NotificationsManager.currentStatus()
        if !granted || status == .denied {
            await MainActor.run {
                lastTestResult = "Permission denied. Open iOS Settings → Casalist → Notifications → Allow."
            }
            await refreshNotifStatus()
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Casalist test"
        content.body = "If you see this, notifications are working."
        content.sound = .default
        content.badge = NSNumber(value: 1)
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: "test-\(UUID().uuidString)", content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
            await MainActor.run { lastTestResult = "Test scheduled \(Int(delay))s from now." }
        } catch {
            await MainActor.run { lastTestResult = "Failed to schedule: \(error.localizedDescription)" }
        }
        await refreshPending()
    }

    private func refreshNotifStatus() async {
        let status = await NotificationsManager.currentStatus()
        let label: String
        switch status {
        case .authorized: label = "Allowed"
        case .denied: label = "Denied — enable in iOS Settings"
        case .notDetermined: label = "Not asked yet"
        case .provisional: label = "Provisional"
        case .ephemeral: label = "Ephemeral"
        @unknown default: label = "Unknown"
        }
        await MainActor.run { notifStatus = label }
    }
}

private extension View {
    func cardBg(_ P: CasalistCottage.Palette) -> some View {
        self
            .background(RoundedRectangle(cornerRadius: 22).fill(P.surface))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(P.border, lineWidth: 1.5))
    }
}
