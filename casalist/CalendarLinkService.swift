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

    /// Asks the user for calendar access. We ask for full access because
    /// we need both write (mirror our events into the linked calendar)
    /// AND read (display the linked calendar's events on the Schedule
    /// tab). Deployment target is iOS 17+ so the pre-17 path is gone.
    func requestAccess() async {
        do {
            _ = try await store.requestFullAccessToEvents()
        } catch {
            // User declined or some other error — status reflects it.
        }
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        if hasReadAccess { refreshCalendars() }
    }

    /// Re-check the authorization status from EventKit. Call this when
    /// returning to the foreground in case the user toggled permission
    /// in Settings → Privacy.
    func refreshAuthorizationStatus() {
        let next = EKEventStore.authorizationStatus(for: .event)
        if next != authorizationStatus {
            authorizationStatus = next
        }
        if hasReadAccess { refreshCalendars() }
    }

    private var hasReadAccess: Bool {
        authorizationStatus == .fullAccess
    }

    private var hasWriteAccess: Bool {
        authorizationStatus == .fullAccess || authorizationStatus == .writeOnly
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
        // Honor the user-set endDate when present; otherwise fall back
        // to all-day (24h) or a 1h default for timed events.
        if let end = event.endDate, end > event.startDate {
            ek.endDate = end
        } else if event.isAllDay {
            ek.endDate = Calendar.current.date(byAdding: .day, value: 1, to: event.startDate) ?? event.startDate.addingTimeInterval(3600)
        } else {
            ek.endDate = event.startDate.addingTimeInterval(3600)
        }
        ek.isAllDay = event.isAllDay
        ek.location = event.location.isEmpty ? nil : event.location
        ek.notes = "Casalist: \(event.attendees.isEmpty ? "Family-wide" : event.attendees)\n\(event.notes)"
        // Translate Casalist's repeatKind into an EKRecurrenceRule so the
        // event actually recurs in Apple Calendar. Without this, a "weekly
        // every Monday" event syncs as a one-shot. Replace any existing
        // rules every time so updates flow through cleanly.
        ek.recurrenceRules = nil
        if let rule = recurrenceRule(for: event) {
            ek.addRecurrenceRule(rule)
        }
        do {
            // .futureEvents propagates rule changes across the recurring
            // series when we're updating an existing mirrored event;
            // EventKit falls back to .thisEvent semantics for one-shots.
            try store.save(ek, span: existing != nil ? .futureEvents : .thisEvent)
            var m = mapping
            m[familyUid] = ek.eventIdentifier
            saveMapping(m)
            return true
        } catch {
            return false
        }
    }

    /// Build an EKRecurrenceRule from a FamilyEvent's `repeatKind`.
    /// Returns nil for non-recurring events.
    private func recurrenceRule(for event: FamilyEvent) -> EKRecurrenceRule? {
        let kind = event.repeatKind
        if kind.isEmpty { return nil }

        // Custom RepeatRule (encoded as `custom:{...}` JSON in repeatKind)
        if let rule = RepeatRule.decode(kind) {
            switch rule.unit {
            case .minute, .hour:
                // EventKit doesn't support sub-day frequencies; skip.
                return nil
            case .day:
                return EKRecurrenceRule(recurrenceWith: .daily, interval: max(1, rule.interval), end: nil)
            case .week:
                let days: [EKRecurrenceDayOfWeek]?
                if let wds = rule.weekdays, !wds.isEmpty {
                    days = wds.compactMap { EKWeekday(rawValue: $0).map { EKRecurrenceDayOfWeek($0) } }
                } else if let wd = rule.weekday, let day = EKWeekday(rawValue: wd) {
                    days = [EKRecurrenceDayOfWeek(day)]
                } else {
                    days = nil
                }
                return EKRecurrenceRule(
                    recurrenceWith: .weekly,
                    interval: max(1, rule.interval),
                    daysOfTheWeek: days,
                    daysOfTheMonth: nil,
                    monthsOfTheYear: nil,
                    weeksOfTheYear: nil,
                    daysOfTheYear: nil,
                    setPositions: nil,
                    end: nil
                )
            case .month:
                return EKRecurrenceRule(recurrenceWith: .monthly, interval: max(1, rule.interval), end: nil)
            case .year:
                return EKRecurrenceRule(recurrenceWith: .yearly, interval: max(1, rule.interval), end: nil)
            }
        }

        // Legacy string kinds
        switch kind {
        case "daily":
            return EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        case "weekly":
            return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        case "monthly":
            return EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)
        case "yearly":
            return EKRecurrenceRule(recurrenceWith: .yearly, interval: 1, end: nil)
        case "weekdays":
            // Mon-Fri only — weekly recurrence on weekdays 2..6.
            let weekdays: [EKRecurrenceDayOfWeek] = (2...6).compactMap { raw in
                EKWeekday(rawValue: raw).map { EKRecurrenceDayOfWeek($0) }
            }
            return EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                daysOfTheWeek: weekdays,
                daysOfTheMonth: nil,
                monthsOfTheYear: nil,
                weeksOfTheYear: nil,
                daysOfTheYear: nil,
                setPositions: nil,
                end: nil
            )
        default:
            return nil
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

    /// True when this device has an Apple Calendar linked AND there is a
    /// live EKEvent mirroring this FamilyEvent. Callers use this to skip
    /// scheduling a Casalist local push for events that Apple Calendar
    /// is already alerting on — otherwise the user gets two pushes for
    /// one event (one from iOS Calendar's default alert, one from
    /// `NotificationsManager.scheduleEvent`).
    ///
    /// Returns false when no calendar is linked, when the mapping is
    /// missing, or when the mapped EKEvent has been deleted in iOS
    /// Calendar (mapping stale).
    func isMirrored(uid: UUID) -> Bool {
        guard linkedCalendar != nil else { return false }
        let mapping = mappingDict()
        guard let ekID = mapping[uid.uuidString] else { return false }
        return store.event(withIdentifier: ekID) != nil
    }

    // MARK: – Local mapping helpers

    private func mappingDict() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: mappingKey) as? [String: String] ?? [:]
    }

    private func saveMapping(_ m: [String: String]) {
        UserDefaults.standard.set(m, forKey: mappingKey)
    }
}
