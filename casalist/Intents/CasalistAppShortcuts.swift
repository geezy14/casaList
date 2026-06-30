import AppIntents

/// Registers Casalist's App Intents as Siri / Spotlight / Shortcuts
/// surfaces. Each phrase must include `\(.applicationName)` so iOS
/// knows it's our app being addressed. The system parses parameters
/// from the spoken phrase when `\(.applicationName)` is followed by a
/// parameter placeholder.
struct CasalistAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateChoreIntent(),
            phrases: [
                "Add a chore to \(.applicationName)",
                "Add chore in \(.applicationName)",
                "Create a chore in \(.applicationName)",
                "New \(.applicationName) chore",
            ],
            shortTitle: "Add Chore",
            systemImageName: "checklist"
        )
        AppShortcut(
            intent: MarkChoreDoneIntent(),
            phrases: [
                "Mark a chore done in \(.applicationName)",
                "Finish a chore in \(.applicationName)",
                "Complete chore in \(.applicationName)",
                "I finished a chore in \(.applicationName)",
            ],
            shortTitle: "Mark Chore Done",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: AddOutingIntent(),
            phrases: [
                "Plan a family outing in \(.applicationName)",
                "Add an outing to \(.applicationName)",
                "Schedule \(.applicationName) outing",
                "New family outing in \(.applicationName)",
            ],
            shortTitle: "Add Outing",
            systemImageName: "calendar.badge.plus"
        )
        AppShortcut(
            intent: RedeemRewardIntent(),
            phrases: [
                "Redeem a reward in \(.applicationName)",
                "Request a reward in \(.applicationName)",
                "Cash in points in \(.applicationName)",
            ],
            shortTitle: "Redeem Reward",
            systemImageName: "gift"
        )
    }

    /// Make sure shortcuts appear in Spotlight + the Shortcuts app the
    /// moment a user installs / updates — not just after the user manually
    /// opens the app. The system handles re-indexing automatically.
    static let shortcutTileColor: ShortcutTileColor = .orange
}
