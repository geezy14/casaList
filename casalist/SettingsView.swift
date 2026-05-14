import SwiftUI
import SwiftData
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("householdName") private var householdName: String = "My Household"
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @State private var notifStatus: String = "Checking…"

    @Query(sort: \FamilyMember.createdAt) private var members: [FamilyMember]
    @Query private var tasks: [TaskItem]
    @Query private var households: [Household]
    @Query private var goals: [FamilyGoal]
    @Query private var chores: [ChoreTemplate]
    @Query private var events: [FamilyEvent]

    @State private var confirmWipe: Bool = false
    @State private var wipeMessage: String? = nil
    @State private var pendingCount: Int = 0
    @State private var lastTestResult: String? = nil
    @State private var pendingList: [String] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Your profile") {
                    TextField("Your name", text: $userName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                }
                Section("Household") {
                    TextField("Household name", text: $householdName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                }
                Section("Notifications") {
                    Toggle("Due-date reminders", isOn: $notificationsEnabled)
                    HStack {
                        Text("System permission").font(.subheadline)
                        Spacer()
                        Text(notifStatus).font(.subheadline).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Pending notifications").font(.subheadline)
                        Spacer()
                        Text("\(pendingCount)").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Button("Send test notification (5s)") { Task { await sendTestNotification(delay: 5) } }
                    Button("Send test (30s — lock the phone)") { Task { await sendTestNotification(delay: 30) } }
                    Button("Refresh scheduled list") { Task { await refreshPending() } }
                    if !pendingList.isEmpty {
                        DisclosureGroup("Scheduled (\(pendingList.count))") {
                            ForEach(pendingList, id: \.self) { line in
                                Text(line).font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if notifStatus.contains("Denied") {
                        Button("Open iOS Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    if let lastTestResult {
                        Text(lastTestResult).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("Family") {
                    if members.isEmpty {
                        Text("No family members yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(members) { m in
                            HStack(spacing: 12) {
                                avatar(for: m)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.name).font(.system(size: 15, weight: .semibold))
                                    if !m.role.isEmpty {
                                        Text(m.role).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(m.points) pts")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .onDelete(perform: removeMember)
                    }
                }
                Section("Developer") {
                    HStack {
                        Text("Family members"); Spacer()
                        Text("\(members.count)").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Tasks"); Spacer()
                        Text("\(tasks.count)").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Households"); Spacer()
                        Text("\(households.count)").foregroundStyle(.secondary)
                    }
                    Button { seedSchemaRecords() } label: {
                        Label("Seed schema records", systemImage: "square.and.arrow.down")
                    }
                    Button(role: .destructive) { confirmWipe = true } label: {
                        Label("Clear all data", systemImage: "trash")
                    }
                    if let wipeMessage {
                        Text(wipeMessage).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Text("Casalist")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task {
                await refreshNotifStatus()
                await refreshPending()
            }
            .onChange(of: notificationsEnabled) { _, on in
                Task {
                    if on {
                        _ = await NotificationsManager.requestAuth()
                        await NotificationsManager.syncFromContext(modelContext)
                    } else {
                        await NotificationsManager.cancelAll()
                    }
                    await refreshNotifStatus()
                }
            }
            .confirmationDialog(
                "Clear all data?",
                isPresented: $confirmWipe,
                titleVisibility: .visible
            ) {
                Button("Wipe everything", role: .destructive) { wipeAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Deletes all tasks, goals, chores, and events on this device. Family members, household, and your profile are preserved. Cannot be undone.")
            }
        }
    }

    private func seedSchemaRecords() {
        let name = userName.trimmingCharacters(in: .whitespaces)
        let ownerName = name.isEmpty ? "Test" : name
        if members.first(where: { $0.name == ownerName }) == nil {
            modelContext.insert(FamilyMember(name: ownerName, role: "You", colorHex: 0xC97357))
        }
        modelContext.insert(FamilyGoal(ownerName: ownerName, label: "Schema test", targetPoints: 100))
        modelContext.insert(ChoreTemplate(label: "Schema test", points: 10, symbol: "checkmark.circle"))
        try? modelContext.save()
        wipeMessage = "Seeded one of each model — wait ~10s then deploy via Dashboard."
    }

    private func wipeAll() {
        let totalBefore = tasks.count + goals.count + chores.count + events.count
        for t in tasks { modelContext.delete(t) }
        for g in goals { modelContext.delete(g) }
        for c in chores { modelContext.delete(c) }
        for e in events { modelContext.delete(e) }
        // Reset point balances on members but keep the members themselves.
        for m in members { m.points = 0 }
        try? modelContext.save()
        wipeMessage = "Cleared \(totalBefore) records. Family and household preserved."
    }

    private func removeMember(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(members[index])
        }
        try? modelContext.save()
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
            await MainActor.run {
                lastTestResult = "Test scheduled \(Int(delay))s from now."
            }
        } catch {
            await MainActor.run {
                lastTestResult = "Failed to schedule: \(error.localizedDescription)"
            }
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

    @ViewBuilder
    private func avatar(for m: FamilyMember) -> some View {
        if let data = m.photoData, let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable().scaledToFill()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
        } else {
            Text(String(m.name.prefix(1)).uppercased())
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(m.color))
        }
    }
}
