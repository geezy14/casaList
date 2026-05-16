import Foundation
import EventKit
import CoreData
import Combine

/// Bridges FamilyEvent records to a user-selected Apple Calendar.
///
/// Two responsibilities:
/// 1. **Mirror push**: When a FamilyEvent is created or edited, write a
///    matching EKEvent into the linked calendar so it shows up in iOS
///    Calendar / iCal.
/// 2. **Read-only fetch**: When the Schedule view asks for events in a
///    date range, load EKEvents from the linked calendar so the user
///    can see their family + non-Casalist calendar events together.
///
/// Per-device by design. Each device decides whether to mirror based on
/// its own `calendarLinkID` AppStorage value. Local mapping
/// (FamilyEvent.uid → EKEvent.eventIdentifier) lives in UserDefaults so
/// CloudKit sync doesn't have to know about EventKit identifiers.
@MainActor
final class CalendarLinkService: NSObject, ObservableObject {
    static let shared = CalendarLinkService()

    @Published private(set) var authorizationStatus: EKAuthorizationStatus
    @Published private(set) var availableCalendars: [EKCalendar] = []

    private let store = EKEventStore()

    /// AppStorage-backed identifier of the linked calendar. Empty when
    /// no calendar is linked. Reading from UserDefaults directly so the
    /// service doesn't have to import SwiftUI.
    var linkedCalendarID: String {
        get { UserDefaults.standard.string(forKey: "calendarLinkID") ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: "calendarLinkID")
        }
    }

    private let mappingKey = "calendarLinkMapping"

    override private init() {
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        super.init()
    }

    // MARK: – Authorization

    /// Asks the user for calendar access. iOS 17+ has the distinction
    /// between write-only and full-access; we ask for full because we
    /// need to both write our mirrored events AND read events for the
    /// schedule display.
    func requestAccess() async {
        if #available(iOS 17.0, *) {
            do {
                _ = try await store.requestFullAccessToEvents()
            } catch {
                // User declined or some other error — status reflects it.
            }
        } else {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                store.requestAccess(to: .event) { _, _ in
                    cont.resume()
                }
            }
        }
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        if hasReadAccess { refreshCalendars() }
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

    // MARK: – Calendar list

    func refreshCalendars() {
        guard hasReadAccess else { return }
        availableCalendars = store.calendars(for: .event).sorted { $0.title < $1.title }
    }

    /// The EKCalendar the user picked, or nil if none.
    var linkedCalendar: EKCalendar? {
        guard !linkedCalendarID.isEmpty else { return nil }
        return store.calendar(withIdentifier: linkedCalendarID)
    }

    // MARK: – Mirror push

    /// Create or update a mirrored EKEvent for a FamilyEvent. No-op if
    /// no calendar is linked or we don't have write access. Idempotent
    /// — re-running for the same FamilyEvent updates the existing
    /// EKEvent in place.
    @discardableResult
    func mirror(_ event: FamilyEvent) -> Bool {
        guard hasWriteAccess, let cal = linkedCalendar else { return false }
        let mapping = mappingDict()
        let familyUid = event.uid.uuidString
        let existing = mapping[familyUid].flatMap { store.event(withIdentifier: $0) }
        let ek = existing ?? EKEvent(eventStore: store)
        ek.calendar = cal
        ek.title = event.title
        ek.startDate = event.startDate
        ek.endDate = event.isAllDay
            ? Calendar.current.date(byAdding: .day, value: 1, to: event.startDate) ?? event.startDate.addingTimeInterval(3600)
            : event.startDate.addingTimeInterval(3600)
        ek.isAllDay = event.isAllDay
        ek.location = event.location.isEmpty ? nil : event.location
        ek.notes = "Casalist: \(event.attendees.isEmpty ? "Family-wide" : event.attendees)\n\(event.notes)"
        do {
            try store.save(ek, span: .thisEvent)
            var m = mapping
            m[familyUid] = ek.eventIdentifier
            saveMapping(m)
            return true
        } catch {
            return false
        }
    }

    /// Remove the mirrored EKEvent for a FamilyEvent. No-op if no
    /// mapping exists.
    func unmirror(uid: UUID) {
        let mapping = mappingDict()
        let key = uid.uuidString
        guard let ekID = mapping[key], let ek = store.event(withIdentifier: ekID) else {
            return
        }
        do {
            try store.remove(ek, span: .thisEvent)
            var m = mapping
            m.removeValue(forKey: key)
            saveMapping(m)
        } catch {
            // Leave the mapping intact; user can clean up manually.
        }
    }

    // MARK: – Read-only fetch

    /// Fetch EKEvents from the linked calendar within a date range.
    /// Returns an empty array when no calendar is linked or no access.
    func fetchEvents(from start: Date, to end: Date) -> [EKEvent] {
        guard hasReadAccess, let cal = linkedCalendar else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: [cal])
        return store.events(matching: predicate)
    }

    // MARK: – Local mapping helpers

    private func mappingDict() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: mappingKey) as? [String: String] ?? [:]
    }

    private func saveMapping(_ m: [String: String]) {
        UserDefaults.standard.set(m, forKey: mappingKey)
    }
}
