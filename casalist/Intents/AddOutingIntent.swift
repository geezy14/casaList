import AppIntents
import CoreData
import Foundation

/// "Hey Siri, plan a family outing in Casalist for soccer practice
/// tomorrow at 5pm." Creates a Family TaskItem container + the paired
/// FamilyEvent so it shows on the Schedule and flows through Apple
/// Calendar mirror — mirrors AddFamilyTripView.save's exact behavior.
struct AddOutingIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Family Outing"
    static var description = IntentDescription(
        "Adds a family outing to Casalist and the household calendar.",
        categoryName: "Family"
    )

    @Parameter(
        title: "Outing",
        description: "What's the outing? (e.g. 'Soccer practice')",
        requestValueDialog: "What's the outing?"
    )
    var outingTitle: String

    @Parameter(
        title: "When",
        description: "When does it start?",
        requestValueDialog: "When?"
    )
    var startDate: Date

    @Parameter(
        title: "Ends",
        description: "Optional end date / time. Leave unset for an all-day outing.",
        default: nil
    )
    var endDate: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Plan \(\.$outingTitle) in Casalist") {
            \.$startDate
            \.$endDate
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = outingTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw $outingTitle.needsValueError("What's the outing?")
        }

        let context = CasaCoreDataStack.shared.context
        let userName = UserDefaults.standard.string(forKey: "userName") ?? ""
        let trimmedUser = userName.trimmingCharacters(in: .whitespaces)
        let cal = Calendar.current

        // Did the user specify a time, or just a date? Siri's date parser
        // returns midnight when it only got a day. Treat midnight-on-the-
        // dot as "all-day". (Heuristic — same one AddFamilyTripView uses.)
        let comps = cal.dateComponents([.hour, .minute], from: startDate)
        let hasTime = (comps.hour ?? 0) != 0 || (comps.minute ?? 0) != 0
        let resolvedStart = hasTime ? startDate : cal.startOfDay(for: startDate)
        let resolvedEnd: Date? = {
            guard let e = endDate else { return nil }
            if hasTime { return e }
            return cal.isDate(e, inSameDayAs: startDate) ? nil : cal.startOfDay(for: e)
        }()

        // Outing container (TaskItem, family-category, points -1 sentinel).
        let trip = TaskItem(
            context: context,
            task: trimmed,
            dueDate: resolvedStart,
            category: "family",
            points: -1,
            createdBy: trimmedUser
        )
        trip.endDate = resolvedEnd

        let householdReq = Household.fetchRequest()
        householdReq.predicate = NSPredicate(format: "deletedAt == nil")
        let household = (try? context.fetch(householdReq))?.first
        if let h = household {
            context.assign(trip, toStoreOf: h)
            trip.household = h
        }

        // Paired calendar event — same shape AddFamilyTripView creates.
        let event = FamilyEvent(
            context: context,
            title: trimmed,
            startDate: resolvedStart,
            isAllDay: !hasTime,
            location: "",
            attendees: "",
            notes: "casalist-outing-uid:\(trip.uid)",
            repeatKind: "",
            createdBy: trimmedUser,
            notifyMode: "household"
        )
        event.endDate = resolvedEnd
        event.announceHousehold = true
        if let h = household {
            context.assign(event, toStoreOf: h)
            event.household = h
        }

        try? context.save()
        Task { await NotificationsManager.scheduleNow(for: trip) }
        Task { await NotificationsManager.scheduleEvent(for: event) }
        CalendarLinkService.shared.mirror(event)

        let when = formatWhen(resolvedStart, allDay: !hasTime)
        return .result(dialog: IntentDialog("Added \(trimmed) — \(when)."))
    }

    private func formatWhen(_ d: Date, allDay: Bool) -> String {
        let f = DateFormatter()
        f.dateFormat = allDay ? "EEE MMM d" : "EEE MMM d 'at' h:mm a"
        return f.string(from: d)
    }
}
