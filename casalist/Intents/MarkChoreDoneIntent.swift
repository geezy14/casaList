import AppIntents
import CoreData
import Foundation

/// "Hey Siri, mark take out trash done in Casalist." Finds the best
/// open-chore match assigned to the current user (or any member if the
/// title is a confident global match) and toggles it completed via the
/// existing FamilyPoints.toggle so points + streaks + the household-
/// wide auto-redeem flow all behave exactly like a tap inside the app.
struct MarkChoreDoneIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Chore Done"
    static var description = IntentDescription(
        "Marks one of your open Casalist chores as done. Picks the best match by name.",
        categoryName: "Chores"
    )

    @Parameter(
        title: "Chore",
        description: "Name of the chore to mark done. Partial matches are OK (e.g. 'trash' finds 'Take out trash').",
        requestValueDialog: "Which chore are you finishing?"
    )
    var choreTitle: String

    static var parameterSummary: some ParameterSummary {
        Summary("Mark \(\.$choreTitle) done in Casalist")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let needle = choreTitle.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else {
            throw $choreTitle.needsValueError("Which chore are you finishing?")
        }

        let context = CasaCoreDataStack.shared.context
        let userName = UserDefaults.standard.string(forKey: "userName") ?? ""
        let trimmedUser = userName.trimmingCharacters(in: .whitespaces).lowercased()

        // Pull all open chores (chore-category), prefer ones assigned to me.
        let req: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        req.predicate = NSPredicate(
            format: "isCompleted == NO AND deletedAt == nil AND (category ==[c] %@ OR category ==[c] %@ OR category ==[c] %@)",
            "chores", "home", "maintenance"
        )
        let candidates = (try? context.fetch(req)) ?? []

        // Score: exact title match > prefix > substring; mine-first tiebreaker.
        let scored: [(TaskItem, Int)] = candidates.compactMap { t in
            let title = t.task.lowercased()
            let score: Int
            if title == needle { score = 100 }
            else if title.hasPrefix(needle) { score = 60 }
            else if title.contains(needle) { score = 30 }
            else { return nil }
            let mine = (t.assignee ?? "").lowercased() == trimmedUser
            return (t, score + (mine ? 10 : 0))
        }
        .sorted { $0.1 > $1.1 }

        guard let best = scored.first?.0 else {
            return .result(dialog: "I couldn't find an open chore matching \(choreTitle).")
        }

        // Snapshot the members fetch so FamilyPoints.toggle can credit
        // correctly (it needs the member array for streak / award routing).
        let mReq: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
        mReq.predicate = NSPredicate(format: "deletedAt == nil")
        let members = (try? context.fetch(mReq)) ?? []

        let title = best.task
        let pts = Int(best.points) + Int(best.bonusPoints)
        FamilyPoints.toggle(best, in: members)
        try? context.save()

        let dialog: IntentDialog = pts > 0
            ? "Marked \(title) done — \(pts) points."
            : "Marked \(title) done."
        return .result(dialog: dialog)
    }
}
