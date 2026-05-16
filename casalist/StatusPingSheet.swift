import SwiftUI
import CoreData

/// Manual status broadcast — tap a preset or type custom text, hit Send,
/// every family member gets a local push notification.
///
/// Mechanism: creates a TaskItem with category = "statusping". That
/// record syncs via CloudKit. Each device's foreground sync runs
/// `NotificationsManager.detectAndNotifyStatusPings` which fires a local
/// push for any new ping not from this device. The ping record itself
/// is ephemeral — filtered out of every task list, and auto-purged
/// after 24h via the existing Trash mechanism.
struct StatusPingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var moc
    @AppStorage("userName") private var userName: String = ""
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)],
                  predicate: NSPredicate(format: "deletedAt == nil"))
    private var households: FetchedResults<Household>

    @State private var customText: String = ""

    private let presets: [(emoji: String, text: String)] = [
        ("🚗", "On my way home"),
        ("🛒", "At the store"),
        ("⏰", "Running late"),
        ("🍽️", "Dinner's ready"),
        ("🆘", "I need help"),
        ("👋", "Just checking in")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Quick send") {
                    ForEach(presets, id: \.text) { p in
                        Button {
                            send(message: "\(p.emoji) \(p.text)")
                        } label: {
                            HStack {
                                Text(p.emoji).font(.system(size: 22))
                                Text(p.text).font(.system(size: 16, weight: .semibold))
                                Spacer()
                                Image(systemName: "paperplane.fill").foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Section("Custom") {
                    TextField("Type a message…", text: $customText, axis: .vertical)
                        .lineLimit(2...4)
                    Button {
                        let trimmed = customText.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        send(message: trimmed)
                    } label: {
                        Label("Send", systemImage: "paperplane.fill")
                    }
                    .disabled(customText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Section {
                    Label("Sends a notification to everyone in your household.",
                          systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ping family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func send(message: String) {
        let trimmedUser = userName.trimmingCharacters(in: .whitespaces)
        let ping = TaskItem(
            context: moc,
            task: message,
            category: StatusPing.category,
            points: 0,
            createdBy: trimmedUser
        )
        if let h = households.preferredTarget {
            moc.assign(ping, toStoreOf: h)
            ping.household = h
        }
        try? moc.save()
        dismiss()
    }
}

/// Sentinel + helpers for the status-ping subsystem.
enum StatusPing {
    /// Category value stored on TaskItem for ping records. Filtered out
    /// of every other task view by predicate.
    static let category = "statusping"

    /// Predicate fragment to filter pings out of task fetches. Append
    /// to existing predicates that aren't specifically looking for pings.
    static let excludePredicate = NSPredicate(format: "category != %@", category)
}
