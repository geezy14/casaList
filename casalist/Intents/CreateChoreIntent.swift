import AppIntents
import CoreData
import Foundation

/// "Hey Siri, add 'take out trash' to Casalist." Creates a chore from
/// outside the app — voice, Spotlight, Shortcuts, widgets. Returns a
/// dialog string so Siri can read back what it did.
struct CreateChoreIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Chore"
    static var description = IntentDescription(
        "Creates a new chore in Casalist. Optionally assign it to a family member and set the points.",
        categoryName: "Chores"
    )

    @Parameter(
        title: "Chore",
        description: "What needs to get done (e.g. 'Take out trash').",
        requestValueDialog: "What's the chore?"
    )
    var choreTitle: String

    @Parameter(
        title: "Assign to",
        description: "Name of the family member this chore is for. Leave blank for anyone.",
        default: ""
    )
    var assigneeName: String

    @Parameter(
        title: "Points",
        description: "Points awarded on completion.",
        default: 10,
        inclusiveRange: (0, 500)
    )
    var points: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$choreTitle) to Casalist") {
            \.$assigneeName
            \.$points
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = choreTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw $choreTitle.needsValueError("What should the chore be?")
        }

        let context = CasaCoreDataStack.shared.context
        let userName = UserDefaults.standard.string(forKey: "userName") ?? ""

        let chore = TaskItem(
            context: context,
            task: trimmed,
            assignee: assigneeName.isEmpty ? nil : assigneeName,
            dueDate: nil,
            category: "chores",
            isCompleted: false,
            points: max(0, points),
            createdBy: userName.trimmingCharacters(in: .whitespaces)
        )
        // Route to the active household so it appears for the family.
        let householdReq = Household.fetchRequest()
        householdReq.predicate = NSPredicate(format: "deletedAt == nil")
        if let household = (try? context.fetch(householdReq))?.first {
            context.assign(chore, toStoreOf: household)
            chore.household = household
        }
        try? context.save()

        let who = assigneeName.isEmpty ? "the family" : assigneeName
        let dialog: IntentDialog = points > 0
            ? "Added \(trimmed) for \(who) — worth \(points) points."
            : "Added \(trimmed) for \(who)."
        return .result(dialog: dialog)
    }
}
