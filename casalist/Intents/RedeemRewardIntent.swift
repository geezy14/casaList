import AppIntents
import CoreData
import Foundation

/// "Hey Siri, redeem the screen time reward in Casalist." Creates a
/// PENDING redemption request — same shape AddGoalView produces when
/// a kid taps a reward — that lands in the admin inbox for approval.
/// Build 20's GoalApproval.approve(in:) handles the rest (auto-debit
/// wallet + auto-redeem) when an admin approves.
struct RedeemRewardIntent: AppIntent {
    static var title: LocalizedStringResource = "Redeem Reward"
    static var description = IntentDescription(
        "Asks your family admin for a reward. Lands in their inbox for approval.",
        categoryName: "Rewards"
    )

    @Parameter(
        title: "Reward",
        description: "What you want to redeem (e.g. '30 minutes screen time').",
        requestValueDialog: "Which reward?"
    )
    var rewardLabel: String

    @Parameter(
        title: "Cost",
        description: "How many points it should cost (optional — the admin can set the final price).",
        default: 0,
        inclusiveRange: (0, 10000)
    )
    var pointCost: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Redeem \(\.$rewardLabel) in Casalist") {
            \.$pointCost
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let label = rewardLabel.trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty else {
            throw $rewardLabel.needsValueError("Which reward?")
        }

        let context = CasaCoreDataStack.shared.context
        let userName = UserDefaults.standard.string(forKey: "userName") ?? ""
        let trimmedUser = userName.trimmingCharacters(in: .whitespaces)
        guard !trimmedUser.isEmpty else {
            return .result(dialog: "I need to know who you are first — open Casalist once to set your name.")
        }

        let goal = FamilyGoal(
            context: context,
            ownerName: GoalApproval.makePendingOwnerName(trimmedUser),
            label: label,
            targetPoints: max(0, pointCost)
        )

        // Scope to the active household so the right admin inbox surfaces it.
        let householdReq = Household.fetchRequest()
        householdReq.predicate = NSPredicate(format: "deletedAt == nil")
        if let h = (try? context.fetch(householdReq))?.first {
            context.assign(goal, toStoreOf: h)
            goal.household = h
        }
        try? context.save()

        let dialog: IntentDialog = pointCost > 0
            ? "Asked the admins for \(label) — \(pointCost) points."
            : "Asked the admins for \(label). They'll set the price."
        return .result(dialog: dialog)
    }
}
