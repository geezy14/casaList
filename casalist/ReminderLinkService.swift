import Foundation
import EventKit
import CoreData
import Combine

/// Bridges Casalist reminders (TaskItem, category="reminders") to a
/// user-selected Apple Reminders list. Mirrors the architecture of
/// `CalendarLinkService` one-for-one — same two-way pattern, same
/// per-device design, same AppStorage + UserDefaults mapping.
///
/// Two responsibilities:
/// 1. **Mirror push**: When a Casalist reminder is created or edited,
///    write a matching EKReminder into the linked list so it shows
///    up in iOS Reminders.app.
/// 2. **Read-only fetch**: When the Reminders view asks for items,
///    load EKReminders from the linked list so the user can see
///    non-Casalist reminders alongside their pinned ones.
///
/// Per-device by design. Each device decides whether to mirror based
/// on its own `reminderLinkID` AppStorage value. Local mapping
/// (TaskItem.uid → EKReminder.calendarItemIdentifier) lives in
/// UserDefaults so CloudKit sync doesn't have to know about EventKit
/// identifiers.
@MainActor
final class ReminderLinkService: NSObject, ObservableObject {
    static let shared = ReminderLinkService()

    @Published private(set) var authorizationStatus: EKAuthorizationStatus
    @Published private(set) var availableLists: [EKCalendar] = []

    private let store = EKEventStore()

    /// AppStorage-backed identifier of the linked Reminders list.
    /// Empty when no list is linked.
    var linkedListID: String {
        get { UserDefaults.standard.string(forKey: "reminderLinkID") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "reminderLinkID") }
    }

    private let mappingKey = "reminderLinkMapping"

    override private init() {
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
        super.init()
    }

    // MARK: – Authorization

    /// Reminders.app uses a different access scope than Calendar. On
    /// iOS 17+ we ask for `requestFullAccessToReminders`; on older
    /// systems we fall back to `requestAccess(to: .reminder)`.
    func requestAccess() async {
        if #available(iOS 17.0, *) {
            do {
                _ = try await store.requestFullAccessToReminders()
            } catch {
                // User declined or some other error.
            }
        } else {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                store.requestAccess(to: .reminder) { _, _ in
                    cont.resume()
                }
            }
        }
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
        if hasReadAccess {
            // EventKit sometimes returns an empty calendar set on the
            // first read right after the permission prompt resolves.
            // Retry once with a short delay if we get nothing back.
            refreshLists()
            if availableLists.isEmpty {
                try? await Task.sleep(nanoseconds: 400_000_000)
                refreshLists()
            }
        }
    }

    /// Re-read auth status from EventKit. Call from .onAppear so users
    /// who flipped Privacy → Reminders in iOS Settings get the picker
    /// to materialize without an app restart.
    func refreshAuthStatus() {
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
        if hasReadAccess { refreshLists() }
    }

    private var hasReadAccess: Bool {
        if #available(iOS 17.0, *) {
            return authorizationStatus == .fullAccess || authorizationStatus == .authorized
        }
        return authorizationStatus == .authorized
    }

    private var hasWriteAccess: Bool {
        if #available(iOS 17.0, *) {
            return authorizationStatus == .fullAccess || authorizationStatus == .writeOnly || authorizationStatus == .authorized
        }
        return authorizationStatus == .authorized
    }

    // MARK: – Reminders list inventory

    func refreshLists() {
        guard hasReadAccess else { return }
        availableLists = store.calendars(for: .reminder).sorted { $0.title < $1.title }
    }

    /// The EKCalendar (Reminders list) the user picked, or nil.
    var linkedList: EKCalendar? {
        guard !linkedListID.isEmpty else { return nil }
        return store.calendar(withIdentifier: linkedListID)
    }

    // MARK: – Mirror push

    /// Create or update a mirrored EKReminder for a Casalist reminder
    /// TaskItem. No-op if no list is linked or we don't have write
    /// access. Idempotent — re-running for the same TaskItem updates
    /// the existing EKReminder in place.
    @discardableResult
    func mirror(_ task: TaskItem) -> Bool {
        guard hasWriteAccess, let cal = linkedList else { return false }
        let mapping = mappingDict()
        let casaUid = task.uid
        let existing = mapping[casaUid].flatMap { store.calendarItem(withIdentifier: $0) as? EKReminder }
        let ek = existing ?? EKReminder(eventStore: store)
        ek.calendar = cal
        ek.title = task.task
        ek.notes = "Casalist: \(task.effectiveRepeatKind.isEmpty ? "pinned" : task.effectiveRepeatKind)"
        ek.isCompleted = task.isCompleted
        if let due = task.dueDate {
            ek.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: due
            )
        } else {
            ek.dueDateComponents = nil
        }
        do {
            try store.save(ek, commit: true)
            var m = mapping
            m[casaUid] = ek.calendarItemIdentifier
            saveMapping(m)
            return true
        } catch {
            return false
        }
    }

    /// Remove the mirrored EKReminder for a Casalist reminder. No-op
    /// if no mapping exists.
    func unmirror(uid: String) {
        let mapping = mappingDict()
        let key = uid
        guard let ekID = mapping[key],
              let ek = store.calendarItem(withIdentifier: ekID) as? EKReminder else {
            return
        }
        do {
            try store.remove(ek, commit: true)
            var m = mapping
            m.removeValue(forKey: key)
            saveMapping(m)
        } catch {
            // Leave the mapping intact; user can clean up manually.
        }
    }

    // MARK: – Read-only fetch

    /// Fetch EKReminders from the linked list. Returns an empty array
    /// when no list is linked or we don't have read access. Async
    /// because EventKit's reminder fetch is asynchronous (unlike
    /// `predicateForEvents`, which is sync).
    func fetchReminders(includeCompleted: Bool = false) async -> [EKReminder] {
        guard hasReadAccess, let cal = linkedList else { return [] }
        let predicate = includeCompleted
            ? store.predicateForReminders(in: [cal])
            : store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: [cal])
        return await withCheckedContinuation { (cont: CheckedContinuation<[EKReminder], Never>) in
            store.fetchReminders(matching: predicate) { results in
                cont.resume(returning: results ?? [])
            }
        }
    }

    // MARK: – Local mapping helpers

    private func mappingDict() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: mappingKey) as? [String: String] ?? [:]
    }

    private func saveMapping(_ m: [String: String]) {
        UserDefaults.standard.set(m, forKey: mappingKey)
    }
}
