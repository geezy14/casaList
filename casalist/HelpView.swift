import SwiftUI

/// First-launch tour + on-demand help screen. Pages explain the household
/// model: roles, points, family list vs. personal tasks, goal approval,
/// trash, backup. Skippable. Re-openable from Settings → About.
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var sys
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial: Bool = false
    @State private var page: Int = 0

    private var P: CasalistCottage.Palette { CasalistCottage.Palette.resolve(sys == .dark) }

    private let pages: [Page] = [
        Page(emoji: "🏡", title: "Welcome to Casalist",
             body: "A private family household app. Track chores, points, goals, schedule, and a shared family list — synced across everyone's iCloud account."),
        Page(emoji: "👨‍👩‍👧‍👦", title: "Four roles",
             body: "Owner runs the household. Admins help manage. Standard members are regular adults. Kids see a simpler view and submit goals for parent approval."),
        Page(emoji: "🧹", title: "Chores & points",
             body: "Parents assign chores with point values. Kids complete them and earn points. Points stack up toward goals — saved up for things like a Switch game or movie night."),
        Page(emoji: "🪴", title: "Family List",
             body: "A shared 'wall' anyone can drop something on (fix the leaky faucet, pick up the cake). Anyone can tap Claim to take it on, or Mark Done if they did it."),
        Page(emoji: "🎯", title: "Goals & approvals",
             body: "Owners + admins create goals directly. Kids submit goals — they wait in the parents' Inbox (tray icon) for Approve or Deny. Once approved, the kid can earn toward it and Redeem when they hit the target."),
        Page(emoji: "🗑️", title: "Trash & backup",
             body: "Anything you delete moves to Trash for 30 days — restore from Settings → Data. We also write a daily snapshot to your iCloud Drive (Files app → Casalist → Backups)."),
        Page(emoji: "✅", title: "You're set",
             body: "Add your family from the Home top bar (person+badge icon). Invite the other adults / kids via their iCloud account. Tap any chore tile to dive in. Have fun.")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                P.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    TabView(selection: $page) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { i, p in
                            pageView(p).tag(i)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .indexViewStyle(.page(backgroundDisplayMode: .always))

                    VStack(spacing: 10) {
                        if page < pages.count - 1 {
                            Button { withAnimation { page += 1 } } label: {
                                Text("Next").font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(Capsule().fill(P.peach))
                            }.buttonStyle(.plain)
                        } else {
                            Button {
                                hasSeenTutorial = true
                                dismiss()
                            } label: {
                                Text("Got it").font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(Capsule().fill(P.mint))
                            }.buttonStyle(.plain)
                        }
                        if page < pages.count - 1 {
                            Button {
                                hasSeenTutorial = true
                                dismiss()
                            } label: {
                                Text("Skip").font(.system(size: 13, weight: .semibold)).foregroundStyle(P.textMuted)
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24).padding(.bottom, 20)
                }
            }
            .foregroundStyle(P.text)
            .navigationBarHidden(true)
        }
    }

    private func pageView(_ p: Page) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Text(p.emoji).font(.system(size: 88))
            Text(p.title).font(.system(size: 26, weight: .heavy)).multilineTextAlignment(.center)
            Text(p.body)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(P.textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }

    private struct Page: Identifiable {
        let id = UUID()
        let emoji: String
        let title: String
        let body: String
    }
}
