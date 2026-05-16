import SwiftUI
import CoreData
import CloudKit
import UIKit

struct InviteFamilyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var moc
    @AppStorage("householdName") private var householdName: String = "My Household"

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)], predicate: NSPredicate(format: "deletedAt == nil"))
    private var households: FetchedResults<Household>

    @State private var accountStatus: CKAccountStatus = .couldNotDetermine
    @State private var statusMessage: String = "Checking iCloud…"
    @State private var preparingShare: Bool = false
    @State private var errorMessage: String? = nil

    private let stack = CasaCoreDataStack.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    nameField
                    statusCard
                    if let errorMessage { errorBanner(errorMessage) }
                    howItWorks
                    Spacer(minLength: 8)

                    Button { Task { await prepareAndShare() } } label: {
                        HStack(spacing: 8) {
                            if preparingShare { ProgressView().tint(.white) }
                            Label(preparingShare ? "Preparing…" : "Send invite",
                                  systemImage: "person.crop.circle.badge.plus")
                                .font(.system(size: 17, weight: .heavy))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Capsule().fill(accountStatus == .available && !preparingShare ? Color.accentColor : Color.gray.opacity(0.5)))
                        .foregroundStyle(.white)
                    }
                    .disabled(accountStatus != .available || preparingShare || householdName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(20)
            }
            .navigationTitle("Invite family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .task { await refreshStatus() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Share your household")
                .font(.system(size: 26, weight: .heavy))
            Text("Everyone you invite sees the same tasks, family members, and rewards in real time.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HOUSEHOLD NAME").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(.secondary)
            TextField("Brown Family", text: $householdName)
                .font(.system(size: 16, weight: .heavy))
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                .submitLabel(.done)
        }
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: accountStatus == .available ? "checkmark.icloud.fill" : "exclamationmark.icloud")
                .font(.system(size: 22))
                .foregroundStyle(accountStatus == .available ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("iCloud").font(.system(size: 14, weight: .heavy))
                Text(statusMessage).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(msg).font(.system(size: 12, weight: .semibold))
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.15)))
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOW IT WORKS").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(.secondary)
            row(num: 1, title: "Tap Send invite", sub: "Casalist creates a private share for your household.")
            row(num: 2, title: "Pick people", sub: "Send the link via Messages, Mail, or copy it.")
            row(num: 3, title: "They tap the link", sub: "Casalist opens on their device and they join.")
        }
    }

    private func row(num: Int, title: String, sub: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(num)")
                .font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .heavy))
                Text(sub).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            }
        }
    }

    private func refreshStatus() async {
        let container = CKContainer(identifier: casalistCloudKitContainerID)
        do {
            let status = try await container.accountStatus()
            await MainActor.run {
                accountStatus = status
                statusMessage = Self.message(for: status)
            }
        } catch {
            await MainActor.run {
                accountStatus = .couldNotDetermine
                statusMessage = "Could not reach iCloud: \(error.localizedDescription)"
            }
        }
    }

    /// Sweep through all child entities and attach any record that has no
    /// household to the given household. Catches records from older app
    /// versions where the household relationship didn't exist.
    private func adoptOrphans(into household: Household) {
        let memberReq: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
        memberReq.predicate = NSPredicate(format: "household == nil")
        for m in (try? moc.fetch(memberReq)) ?? [] { m.household = household }

        let taskReq: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        taskReq.predicate = NSPredicate(format: "household == nil")
        for t in (try? moc.fetch(taskReq)) ?? [] { t.household = household }

        let goalReq: NSFetchRequest<FamilyGoal> = FamilyGoal.fetchRequest()
        goalReq.predicate = NSPredicate(format: "household == nil")
        for g in (try? moc.fetch(goalReq)) ?? [] { g.household = household }

        let eventReq: NSFetchRequest<FamilyEvent> = FamilyEvent.fetchRequest()
        eventReq.predicate = NSPredicate(format: "household == nil")
        for e in (try? moc.fetch(eventReq)) ?? [] { e.household = household }
    }

    private static func message(for status: CKAccountStatus) -> String {
        switch status {
        case .available: return "Signed in. Ready to share."
        case .noAccount: return "No iCloud account. Sign in in Settings → Apple ID."
        case .restricted: return "iCloud access is restricted on this device."
        case .couldNotDetermine: return "Checking iCloud status…"
        case .temporarilyUnavailable: return "iCloud is temporarily unavailable. Try again shortly."
        @unknown default: return "Unknown iCloud status."
        }
    }

    @MainActor
    private func prepareAndShare() async {
        preparingShare = true
        errorMessage = nil
        let trimmedName = householdName.trimmingCharacters(in: .whitespaces)

        let household: Household
        if let existing = households.first {
            household = existing
        } else {
            guard let fresh = HouseholdProvisioner.ensureHouseholdExists(in: moc) else {
                preparingShare = false
                errorMessage = "Could not create a household to share."
                return
            }
            household = fresh
        }
        household.name = trimmedName

        // Adopt any orphan records (no household yet) into this household.
        adoptOrphans(into: household)
        try? moc.save()

        // Try to share. NSPersistentCloudKitContainer needs the household to be
        // exported to CloudKit first. If we just created it, retry a few times
        // with a small delay while the background export catches up.
        for attempt in 1...6 {
            do {
                let (_, share, ckContainer) = try await stack.container.share([household], to: nil)
                share[CKShare.SystemFieldKey.title] = trimmedName as CKRecordValue
                share.publicPermission = .none
                preparingShare = false
                // Present the standard iOS share sheet with the CKShare URL —
                // unlike Apple's UICloudSharingController this exposes ALL
                // share destinations including AirDrop. The CKShare itself
                // was already saved server-side by the share() call above.
                presentShareSheet(for: share, container: ckContainer)
                return
            } catch let error as NSError where error.code == 134410 && attempt < 6 {
                // Ineligible — record not exported yet. Wait and retry.
                try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_500_000_000)
                continue
            } catch {
                preparingShare = false
                errorMessage = "Could not prepare share: \(error.localizedDescription)"
                return
            }
        }
        preparingShare = false
        errorMessage = "Couldn't share yet — Casalist is still syncing the household to iCloud. Try again in a few seconds."
    }

    @MainActor
    private func presentShareSheet(for share: CKShare, container: CKContainer) {
        // share.url is populated by NSPersistentCloudKitContainer.share()
        // after the server save. Poll briefly in the rare case it's still nil.
        Task { @MainActor in
            for _ in 0..<10 {
                if share.url != nil { break }
                try? await Task.sleep(for: .milliseconds(300))
            }
            guard let url = share.url else {
                errorMessage = "Share URL didn't materialize — try again in a moment."
                return
            }
            let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)

            guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                  let window = scene.windows.first(where: { $0.isKeyWindow }),
                  let root = window.rootViewController else { return }
            var top = root
            while let presented = top.presentedViewController { top = presented }
            // For iPad: anchor the popover near the top center so it doesn't
            // crash on iPad layouts.
            if let popover = activity.popoverPresentationController {
                popover.sourceView = top.view
                popover.sourceRect = CGRect(x: top.view.bounds.midX, y: 60, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            top.present(activity, animated: true)
        }
    }
}
