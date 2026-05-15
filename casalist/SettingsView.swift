import SwiftUI
import CoreData
import CloudKit
import UIKit
import UserNotifications
import UniformTypeIdentifiers

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
    @State private var awardTarget: FamilyMember? = nil
    @State private var awardAmount: Int = 5
    @State private var deleteTarget: FamilyMember? = nil
    @State private var showAddMember: Bool = false
    @State private var showTrash: Bool = false
    @State private var showRestorePicker: Bool = false
    @State private var backupStatus: String? = nil
    @State private var showHelp: Bool = false
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial: Bool = false
    @AppStorage("appearancePref") private var appearancePref: String = "system"  // system | light | dark
    @AppStorage("paletteName") private var paletteName: String = "ember"  // ember | vivid | anchor
    @AppStorage("backupEnabled") private var backupEnabled: Bool = true

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var members: FetchedResults<FamilyMember>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var tasks: FetchedResults<TaskItem>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var households: FetchedResults<Household>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyGoal.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var goals: FetchedResults<FamilyGoal>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \FamilyEvent.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var events: FetchedResults<FamilyEvent>

    private var P: CasalistCottage.Palette { CasalistCottage.Palette.resolve(sys == .dark) }
    private var me: FamilyMember? {
        FamilyPermissions.currentMember(members: members, userName: userName, meUid: meUid)
    }
    private var iAmOwner: Bool { me?.isOwner ?? false }
    private var iAmAdmin: Bool { me?.canManageFamily ?? false }
    private var adminCount: Int { FamilyPermissions.adminCount(in: members) }
    private var sortedFamilyMembers: [FamilyMember] {
        members.sorted { a, b in
            let ra = roleSortKey(a.level), rb = roleSortKey(b.level)
            if ra != rb { return ra < rb }
            return a.createdAt < b.createdAt
        }
    }
    private func roleSortKey(_ r: FamilyRole) -> Int {
        switch r {
        case .owner: return 0
        case .admin: return 1
        case .standard: return 2
        case .kid: return 3
        }
    }

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
            FamilyPermissions.ensureOwner(members: members, context: moc, userName: userName, meUid: meUid)
            adoptMeIfNeeded()
            await refreshNotifStatus()
            await refreshPending()
        }
        .onChange(of: userName) { _, _ in
            // If the user renames themselves and the old meUid claim no longer
            // points at any existing member (e.g. after purging a shared
            // household), drop it so adoptMeIfNeeded can re-claim the right one.
            if !meUid.isEmpty, !members.contains(where: { $0.uid.uuidString == meUid }) {
                meUid = ""
            }
            adoptMeIfNeeded()
        }
        .onChange(of: notificationsEnabled) { _, on in
            Task {
                if on {
                    _ = await NotificationsManager.requestAuth()
                    await NotificationsManager.syncFromContext(moc)
                    await NotificationsManager.scheduleWeeklyRecap(in: moc)
                } else {
                    await NotificationsManager.cancelAll()
                    await NotificationsManager.cancelWeeklyRecap()
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
        .sheet(item: $awardTarget) { t in awardPointsSheet(target: t) }
        .alert("Remove \(deleteTarget?.name ?? "")?", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        ), presenting: deleteTarget) { m in
            Button("Remove", role: .destructive) {
                deleteMember(m)
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: { m in
            Text("\(m.name) moves to Trash. You have \(Trash.retentionDays) days to restore them from Settings → Data → Trash.")
        }
        .sheet(isPresented: $showTrash) { TrashView() }
        .fileImporter(isPresented: $showRestorePicker, allowedContentTypes: [.json, .data]) { result in
            switch result {
            case .success(let url):
                let didStart = url.startAccessingSecurityScopedResource()
                defer { if didStart { url.stopAccessingSecurityScopedResource() } }
                let restore = CloudBackup.restore(from: url, into: moc)
                switch restore {
                case .success(let n):
                    backupStatus = n == 0 ? "Nothing new to restore — your data was already up to date." : "Restored \(n) record\(n == 1 ? "" : "s")."
                case .failure(let err):
                    backupStatus = err.message
                }
            case .failure(let err):
                backupStatus = "Couldn't pick file: \(err.localizedDescription)"
            }
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
            appearanceSection
            notificationsSection
            backupSection
            dataSection
            aboutSection
            #if DEBUG
            developerSection
            #endif
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
                    ForEach(Array(sortedFamilyMembers.enumerated()), id: \.element.uid) { idx, m in
                        memberRow(m)
                        if idx < sortedFamilyMembers.count - 1 { divider }
                    }
                }
                if iAmAdmin || members.isEmpty || me == nil {
                    if !members.isEmpty { divider }
                    Button { showAddMember = true } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill").font(.system(size: 14, weight: .bold))
                            Text("Add family member").font(.system(size: 14, weight: .heavy))
                            Spacer()
                        }
                        .foregroundStyle(P.peach)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }.buttonStyle(.plain)
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
        .sheet(isPresented: $showAddMember) { AddFamilyMemberView() }
    }

    private func memberRow(_ m: FamilyMember) -> some View {
        let isMe = m.uid.uuidString == meUid || m.name.lowercased() == userName.lowercased()
        return HStack(spacing: 12) {
            avatar(for: m)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(m.name).font(.system(size: 15, weight: .heavy))
                    if isMe {
                        Text("YOU").font(.system(size: 8, weight: .heavy))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(P.peach.opacity(0.22)))
                            .foregroundStyle(P.peach)
                    }
                }
                HStack(spacing: 6) {
                    roleControl(for: m)
                    Text("·").font(.system(size: 10)).foregroundStyle(P.textMuted)
                    Text("\(m.points) pts").font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textMuted)
                }
            }
            Spacer()
            if iAmAdmin && !isMe {
                Button { awardTarget = m; awardAmount = 5 } label: {
                    Image(systemName: "gift.fill").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(P.peach)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(P.peach.opacity(0.12)))
                }.buttonStyle(.plain)
            }
            if canDelete(m, isMe: isMe) {
                Button { deleteTarget = m } label: {
                    Image(systemName: "trash").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(P.textMuted)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(P.textMuted.opacity(0.08)))
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    private func awardPointsSheet(target: FamilyMember) -> some View {
        let current = Int(target.points)
        let projected = max(0, current + awardAmount)
        let effectiveDelta = projected - current   // what'll actually be applied after clamping ≥0
        return NavigationStack {
            ZStack {
                P.bg.ignoresSafeArea()
                VStack(spacing: 16) {
                    Image(systemName: "gift").font(.system(size: 36)).foregroundStyle(P.peach)
                    Text("Adjust points for \(target.name)").font(.system(size: 17, weight: .heavy))

                    // Big current → new preview so it's always clear what will land.
                    HStack(spacing: 14) {
                        VStack {
                            Text("Now").font(.system(size: 10, weight: .heavy)).tracking(0.8).foregroundStyle(P.textMuted)
                            Text("\(current)").font(.system(size: 30, weight: .heavy))
                            Text("pts").font(.system(size: 10)).foregroundStyle(P.textMuted)
                        }.frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 14).fill(P.surface))
                        Image(systemName: "arrow.right").foregroundStyle(P.textMuted)
                        VStack {
                            Text("New").font(.system(size: 10, weight: .heavy)).tracking(0.8).foregroundStyle(P.peach)
                            Text("\(projected)").font(.system(size: 30, weight: .heavy)).foregroundStyle(P.peach)
                            Text("pts").font(.system(size: 10)).foregroundStyle(P.textMuted)
                        }.frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 14).fill(P.peach.opacity(0.12)))
                    }
                    .padding(.horizontal, 4)

                    Stepper(value: $awardAmount, in: -1000...1000, step: 1) {
                        HStack {
                            Text("Change").font(.system(size: 13, weight: .heavy)).foregroundStyle(P.textMuted)
                            Spacer()
                            Text("\(awardAmount >= 0 ? "+" : "")\(awardAmount) pts").font(.system(size: 16, weight: .heavy))
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(P.surface))

                    HStack(spacing: 8) {
                        ForEach([-25, -10, -5, 5, 10, 25], id: \.self) { step in
                            Button { awardAmount += step } label: {
                                Text("\(step > 0 ? "+" : "")\(step)").font(.system(size: 12, weight: .heavy))
                                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                                    .background(Capsule().fill(step >= 0 ? P.peach.opacity(0.18) : P.surfaceAlt))
                                    .foregroundStyle(step >= 0 ? P.peach : P.textMuted)
                            }.buttonStyle(.plain)
                        }
                    }

                    Button { awardAmount = -current } label: {
                        Text("Zero out").font(.system(size: 12, weight: .heavy))
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(Capsule().fill(P.surfaceAlt))
                            .foregroundStyle(P.text)
                    }.buttonStyle(.plain)
                        .disabled(current == 0)

                    Spacer(minLength: 0)

                    HStack(spacing: 12) {
                        Button("Cancel") { awardTarget = nil }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Capsule().fill(P.surfaceAlt))
                            .foregroundStyle(P.text)
                        Button {
                            target.points = Int64(projected)
                            try? moc.save()
                            awardTarget = nil
                        } label: {
                            Text("Apply").font(.system(size: 14, weight: .heavy))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Capsule().fill(P.peach))
                        .foregroundStyle(.white)
                        .disabled(effectiveDelta == 0)
                    }
                }
                .padding(20)
            }
            .foregroundStyle(P.text)
        }
        .presentationDetents([.medium, .large])
    }

    /// You can delete any non-self member whose household lives in your own
    /// private store — that's your own household, or a shared one you own. A
    /// share joiner can't delete members from the inviter's household (those
    /// records live in the joiner's *shared* store).
    private func canDelete(_ m: FamilyMember, isMe: Bool) -> Bool {
        // Only protect the *actual* claimed-me record (uid match). Stale members
        // that merely share the current userName are deletable so old test
        // identities can be cleaned out.
        if !meUid.isEmpty, m.uid.uuidString == meUid { return false }
        guard let store = m.objectID.persistentStore else { return true }
        return store == CasaCoreDataStack.shared.privateStore
    }

    private func deleteMember(_ m: FamilyMember) {
        m.softDelete()
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
        } else if iAmAdmin {
            // Owner and admin can both retag any non-owner member.
            Menu {
                ForEach(FamilyRole.assignable, id: \.self) { r in
                    Button {
                        setRole(m, to: r)
                    } label: {
                        Label(r.label, systemImage: r.symbol)
                    }
                }
            } label: {
                roleBadge(m.level)
            }
        } else {
            roleBadge(m.level)
        }
    }

    private func roleBadge(_ r: FamilyRole) -> some View {
        let tint: Color
        switch r {
        case .owner: tint = P.butter
        case .admin: tint = P.peach
        case .kid:   tint = P.sky
        case .standard: tint = P.textMuted
        }
        return HStack(spacing: 3) {
            Image(systemName: r.symbol).font(.system(size: 8, weight: .heavy))
            Text(r.label.uppercased()).font(.system(size: 9, weight: .heavy)).tracking(0.5)
        }
        .foregroundStyle(tint)
    }

    private func setRole(_ m: FamilyMember, to next: FamilyRole) {
        if next == .admin && adminCount >= 2 && m.level != .admin {
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

    /// Withdraws this device from every CKShare it has accepted by purging
    /// every shared-zone the shared store knows about. After this, the shared
    /// household (and all its members/tasks/etc.) disappears locally — the
    /// inviter's copy is untouched.
    private func leaveSharedHouseholds() {
        let stack = CasaCoreDataStack.shared
        guard let sharedStore = stack.sharedStore else {
            wipeMessage = "Shared store not available."
            return
        }
        let sharedHouseholds = households.filter { $0.objectID.persistentStore == sharedStore }
        guard !sharedHouseholds.isEmpty else {
            wipeMessage = "No shared households to leave."
            return
        }
        var zoneIDs = Set<CKRecordZone.ID>()
        for h in sharedHouseholds {
            if let record = try? stack.container.record(for: h.objectID) {
                zoneIDs.insert(record.recordID.zoneID)
            }
        }
        guard !zoneIDs.isEmpty else {
            wipeMessage = "No CloudKit zones to purge yet — try again in a moment."
            return
        }
        let count = sharedHouseholds.count
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
            if let failure {
                wipeMessage = "Leave failed: \(failure.localizedDescription)"
            } else {
                wipeMessage = "Left \(count) shared household\(count == 1 ? "" : "s")."
            }
        }
    }

    /// Fetches the share for the user's private household, prints every
    /// participant's name / acceptance / permission, then upgrades any
    /// non-owner with read-only permission to read-write so their writes
    /// actually flow back to the owner. Saves the modified share via
    /// CKModifyRecordsOperation on the private DB.
    private func inspectAndFixShare() {
        let stack = CasaCoreDataStack.shared
        guard let mine = households.first(where: { $0.objectID.persistentStore == stack.privateStore }) else {
            wipeMessage = "No private household to inspect."
            return
        }
        let shareMap: [NSManagedObjectID: CKShare]
        do {
            shareMap = try stack.container.fetchShares(matching: [mine.objectID])
        } catch {
            wipeMessage = "fetchShares failed: \(error.localizedDescription)"
            return
        }
        guard let share = shareMap[mine.objectID] else {
            wipeMessage = "Household isn't shared yet."
            return
        }
        let fmt = PersonNameComponentsFormatter()
        var report = "Participants (\(share.participants.count)):\n"
        var changed = false
        for p in share.participants {
            let nameStr: String
            if let comps = p.userIdentity.nameComponents {
                nameStr = fmt.string(from: comps)
            } else if let email = p.userIdentity.lookupInfo?.emailAddress {
                nameStr = email
            } else {
                nameStr = "?"
            }
            let accept: String
            switch p.acceptanceStatus {
            case .accepted: accept = "accepted"
            case .pending: accept = "pending"
            case .removed: accept = "removed"
            case .unknown: accept = "unknown"
            @unknown default: accept = "?"
            }
            let perm: String
            switch p.permission {
            case .readOnly: perm = "readOnly"
            case .readWrite: perm = "readWrite"
            case .none: perm = "none"
            case .unknown: perm = "unknown"
            @unknown default: perm = "?"
            }
            let role: String = p.role == .owner ? "owner" : (p.role == .privateUser ? "private" : "public")
            report += "• \(nameStr) | \(role) | \(accept) | \(perm)\n"
            if p.role != .owner && p.permission != .readWrite {
                p.permission = .readWrite
                changed = true
            }
        }
        if !changed {
            wipeMessage = report + "\nAll participants already read-write."
            return
        }
        // Persist the updated share to the private DB.
        let ck = CKContainer(identifier: casalistCloudKitContainerID)
        let op = CKModifyRecordsOperation(recordsToSave: [share], recordIDsToDelete: nil)
        op.qualityOfService = .userInitiated
        op.savePolicy = .changedKeys
        op.modifyRecordsResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    wipeMessage = report + "\nFixed: forced read-write on \(share.participants.count - 1) participant(s)."
                case .failure(let err):
                    wipeMessage = report + "\nSave share failed: \(err.localizedDescription)"
                }
            }
        }
        ck.privateCloudDatabase.add(op)
    }

    /// Reports which store every local record lives in. Useful for confirming
    /// joiner-side records actually landed in the shared store (not the
    /// private one) — that's the precondition for them being uploaded to the
    /// share owner's CloudKit zone.
    private func inspectStoreAssignments() {
        let stack = CasaCoreDataStack.shared
        func storeLabel(for obj: NSManagedObject) -> String {
            guard let s = obj.objectID.persistentStore else { return "?" }
            if s == stack.privateStore { return "PRIV" }
            if s == stack.sharedStore { return "SHARED" }
            return "other"
        }
        var lines: [String] = []
        lines.append("Households:")
        for h in households {
            lines.append("• \(h.name) [\(storeLabel(for: h))] members=\(h.members?.count ?? 0)")
        }
        lines.append("\nMembers:")
        for m in members {
            lines.append("• \(m.name) (\(m.points)pt) [\(storeLabel(for: m))]")
        }
        lines.append("\nTasks (open):")
        for t in tasks where !t.isCompleted {
            lines.append("• \(t.task) → \(t.assignee ?? "?") [\(storeLabel(for: t))]")
        }
        lines.append("\nGoals:")
        for g in goals {
            let redeemed = g.isRedeemed ? " ✓" : ""
            lines.append("• \(g.label) for \(g.ownerName) \(g.targetPoints)pt\(redeemed) [\(storeLabel(for: g))]")
        }
        wipeMessage = lines.joined(separator: "\n")
    }

    /// Reads the tail of share-log.txt (where CasaCoreDataStack writes every
    /// CK setup/import/export event) and shows the last ~30 lines so we can
    /// triage sync issues without devicectl.
    private func loadRecentSyncLog() {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            wipeMessage = "Documents dir not found."
            return
        }
        let url = docs.appendingPathComponent("share-log.txt")
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            wipeMessage = "No sync log yet — relaunch the app to start recording events."
            return
        }
        let lines = text.split(separator: "\n").suffix(30)
        wipeMessage = lines.joined(separator: "\n")
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

    // MARK: Appearance

    private var appearanceSection: some View {
        section(title: "APPEARANCE") {
            VStack(spacing: 0) {
                Picker("Theme", selection: $appearancePref) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16).padding(.vertical, 12)
                divider
                VStack(alignment: .leading, spacing: 10) {
                    Text("COLOR PALETTE")
                        .font(.system(size: 10, weight: .heavy)).tracking(1.0)
                        .foregroundStyle(P.textMuted)
                    HStack(spacing: 8) {
                        paletteSwatch("ember", label: "Ember")
                        paletteSwatch("vivid", label: "Vivid")
                        paletteSwatch("anchor", label: "Anchor")
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .cardBg(P)
        }
    }

    /// Swatch button — shows the palette's primary + a couple accents and the
    /// label. Tapping it swaps the active palette via AppStorage. Re-renders
    /// the whole app because Root observes `paletteName`.
    private func paletteSwatch(_ name: String, label: String) -> some View {
        let active = paletteName == name
        let swatch = CasalistCottage.Palette.resolveForPreview(name, dark: false)
        return Button { paletteName = name } label: {
            VStack(spacing: 6) {
                HStack(spacing: 0) {
                    swatch.peach.frame(maxWidth: .infinity, maxHeight: .infinity)
                    swatch.mint.frame(maxWidth: .infinity, maxHeight: .infinity)
                    swatch.butter.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                Text(label).font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(active ? P.text : P.textDim)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(active ? P.surfaceAlt : Color.clear))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(active ? P.peach : P.border, lineWidth: active ? 2 : 1)
            )
        }.buttonStyle(.plain)
    }

    // MARK: About

    private var versionLine: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "Version \(v) (build \(b))"
    }

    private var aboutSection: some View {
        section(title: "ABOUT") {
            VStack(spacing: 0) {
                Button { showHelp = true } label: {
                    HStack {
                        Image(systemName: "questionmark.circle.fill").font(.system(size: 14)).foregroundStyle(P.peach)
                        Text("How Casalist works").font(.system(size: 14, weight: .heavy)).foregroundStyle(P.text)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(P.textMuted)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }.buttonStyle(.plain)
                divider
                HStack {
                    Text("Build").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text(versionLine).font(.system(size: 12, weight: .semibold)).foregroundStyle(P.textMuted)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .cardBg(P)
        }
        .sheet(isPresented: $showHelp) { HelpView() }
    }

    // MARK: Backup (iCloud Drive)

    private var lastBackupText: String {
        if let d = CloudBackup.lastSnapshotDate {
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .short
            return "Last backup \(f.localizedString(for: d, relativeTo: Date()))"
        }
        return "No backup yet"
    }

    private var backupSection: some View {
        section(title: "BACKUP") {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(P.sky.opacity(0.22)).frame(width: 44, height: 44)
                        Image(systemName: "icloud.fill").font(.system(size: 20)).foregroundStyle(P.sky)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("iCloud Drive Backup").font(.system(size: 14, weight: .heavy))
                        Text(CloudBackup.isAvailable ? lastBackupText : "iCloud Drive unavailable")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(P.textMuted)
                    }
                    Spacer()
                    if CloudBackup.isAvailable {
                        Text("ON").font(.system(size: 9, weight: .heavy)).tracking(0.5)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(P.mint.opacity(0.25)))
                            .foregroundStyle(P.mint)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                divider
                Toggle(isOn: $backupEnabled) {
                    Text("Auto-back up daily").font(.system(size: 14, weight: .semibold))
                }
                .tint(P.peach)
                .padding(.horizontal, 16).padding(.vertical, 8)
                divider
                actionButton("Back up now") {
                    let result = CloudBackup.snapshot(in: moc)
                    switch result {
                    case .success: backupStatus = "Backed up to iCloud Drive."
                    case .failure(let err): backupStatus = err.message
                    }
                }
                divider
                actionButton("Restore from backup…") { showRestorePicker = true }
                if let backupStatus {
                    divider
                    Text(backupStatus).font(.caption).foregroundStyle(P.textMuted)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .cardBg(P)
        }
    }

    // MARK: Data

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: false)],
        predicate: NSPredicate(format: "deletedAt != nil")
    ) private var trashedTasks: FetchedResults<TaskItem>
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: false)],
        predicate: NSPredicate(format: "deletedAt != nil")
    ) private var trashedMembers: FetchedResults<FamilyMember>
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FamilyGoal.createdAt, ascending: false)],
        predicate: NSPredicate(format: "deletedAt != nil")
    ) private var trashedGoals: FetchedResults<FamilyGoal>
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FamilyEvent.startDate, ascending: false)],
        predicate: NSPredicate(format: "deletedAt != nil")
    ) private var trashedEvents: FetchedResults<FamilyEvent>

    private var trashedCount: Int {
        trashedTasks.count + trashedMembers.count + trashedGoals.count + trashedEvents.count
    }

    private var dataSection: some View {
        section(title: "DATA") {
            VStack(spacing: 0) {
                Button { showTrash = true } label: {
                    HStack {
                        Image(systemName: "trash").font(.system(size: 13, weight: .semibold)).foregroundStyle(P.coral)
                        Text("Trash").font(.system(size: 14, weight: .heavy)).foregroundStyle(P.text)
                        Spacer()
                        if trashedCount > 0 {
                            Text("\(trashedCount)").font(.system(size: 11, weight: .heavy))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(P.coral.opacity(0.2)))
                                .foregroundStyle(P.coral)
                        }
                        Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(P.textMuted)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }.buttonStyle(.plain)
                if iAmAdmin {
                    divider
                    Button(role: .destructive) { confirmWipe = true } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.system(size: 16, weight: .bold)).foregroundStyle(P.coral)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reset all data").font(.system(size: 14, weight: .heavy)).foregroundStyle(P.coral)
                                Text("Clears every chore, goal, event, streak, and badge. Family members and household stay.")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(P.textMuted)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }.buttonStyle(.plain)
                }
                if let wipeMessage {
                    divider
                    Text(wipeMessage).font(.caption).foregroundStyle(P.textMuted)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                }
            }
            .cardBg(P)
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
                actionButton("Send weekly recap test (5s)") {
                    Task {
                        await NotificationsManager.sendRecapTestNow(in: moc)
                        await MainActor.run { lastTestResult = "Weekly recap test scheduled — fires in 5s." }
                    }
                }
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
                if households.contains(where: { $0.objectID.persistentStore == CasaCoreDataStack.shared.sharedStore }) {
                    actionButton("Leave shared household") { leaveSharedHouseholds() }
                    divider
                }
                actionButton("Inspect & fix share permissions") { inspectAndFixShare() }
                divider
                actionButton("Inspect local store assignments") { inspectStoreAssignments() }
                divider
                actionButton("View sync log (last 30)") { loadRecentSyncLog() }
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
        if let data = m.photoBlob, let ui = UIImage(data: data) {
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
        try? moc.save()
        wipeMessage = "Seeded — wait ~10s then deploy via Dashboard. Temp member: \(tempName)"
    }

    /// Comprehensive reset — hard-deletes every TaskItem / FamilyGoal /
    /// FamilyEvent / ChoreTemplate (including soft-deleted "trash"
    /// records), resets all member points to 0, clears the routine
    /// templates blob on every household, and wipes the per-device
    /// UserDefaults caches (streaks, badges, quick-add history, push
    /// notification dedup sets). The household entity itself and every
    /// FamilyMember row stay intact so the family structure survives.
    private func wipeAll() {
        // Use fetch-everything rather than the bound @FetchRequest lists so
        // we also catch deletedAt != nil records that the views filter out.
        let allTasks    = (try? moc.fetch(TaskItem.fetchRequest())) ?? []
        let allGoals    = (try? moc.fetch(FamilyGoal.fetchRequest())) ?? []
        let allEvents   = (try? moc.fetch(FamilyEvent.fetchRequest())) ?? []
        let allChores   = (try? moc.fetch(ChoreTemplate.fetchRequest())) ?? []
        let totalBefore = allTasks.count + allGoals.count + allEvents.count + allChores.count

        for t in allTasks  { moc.delete(t) }
        for g in allGoals  { moc.delete(g) }
        for e in allEvents { moc.delete(e) }
        for c in allChores { moc.delete(c) }

        // Reset member points + clear routine templates on every household.
        let allMembers     = (try? moc.fetch(FamilyMember.fetchRequest())) ?? []
        for m in allMembers { m.points = 0 }
        let allHouseholds  = (try? moc.fetch(Household.fetchRequest())) ?? []
        for h in allHouseholds { h.routinesJSON = "" }

        try? moc.save()

        // Per-device UserDefaults that mirror Core Data state.
        let d = UserDefaults.standard
        d.removeObject(forKey: "streakStateJSON")
        d.removeObject(forKey: "awardedBadgesJSON")
        d.removeObject(forKey: "choreRoutinesJSON")
        d.removeObject(forKey: "quickAddHistoryJSON")
        d.removeObject(forKey: "notifiedAssignmentUIDs")
        d.removeObject(forKey: "notifiedRedemptionUIDs")
        d.removeObject(forKey: "notifiedPendingRequestUIDs")

        // Cancel any due-date or recap notifications scheduled for now-deleted records.
        Task {
            await NotificationsManager.cancelAll()
            await NotificationsManager.cancelWeeklyRecap()
        }

        wipeMessage = "Cleared \(totalBefore) records + all caches. Family and household preserved."
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
