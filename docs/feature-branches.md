# Feature branches built 2026-05-14 (cr3 session)

Eight feature branches sitting locally, one per idea. Each branched off
`main`, builds clean against `generic/platform=iOS`, and is independent
of the others — you can push and test in any order.

To deploy any one to a phone, say "push <branch>" and the active
replicant will check it out + devicectl install. To keep, say
"merge <branch>" and it'll fold into main.

| Branch | Headline | Where it shows up | Notes |
|---|---|---|---|
| `starfield` | Kid-mode UI with bright palette | Auto-appears when a member's role is Kid; replaces the 3-tab adult shell with a 3-section kid screen | Adults flip role back to Standard to restore adult UI |
| `routines` | Bundle multiple chores into one-tap spawns | wand.and.stars icon in Home top bar (owner/admin only) | Templates local to device; spawned tasks sync |
| `streaks` | Streak counter + 9 badge achievements | 🔥/🎖 chips next to each member's name on the adult Rewards STANDINGS row | Per-device storage; Kid view chips appear when merged with starfield |
| `recap` | Sunday 7pm weekly family digest push | Notification body lists top 3 earners + open chore count | Pure local notification; respects the existing reminders toggle |
| `team-goals` | Whole-family goals everyone contributes to | New "👨‍👩‍👧‍👦 Whole family" option in Add Goal assignee picker | Progress = sum of all members' points; redeem is celebration-only, no deduction |
| `quick-add` | One-tap chip strip to re-spawn recent chores | "QUICK ADD" row below the main quick-add input on Home (owner/admin only) | Last 8 distinct chores; long-press chip to Remove |
| `avatar-levels` | Tier rings + emblems on every family avatar | Bronze/Silver/Gold/Platinum rings on CLAvatar based on lifetime points | Rookie (0–49) · Bronze (50–149) · Silver (150–299) · Gold (300–499) · Platinum (500+) |
| `family-stats` | Read-only family aggregates page | chart.bar.fill icon in Home top bar (everyone) | Hero stats + top earner + most-claimed chores + weekday chart + goals breakdown |

## How to test each

Once a branch is on your phone (via `push <branch>`):

- **starfield**: change a member's role to Kid (Settings → FAMILY → tap role pill → Kid on the adult device). On that member's device, the app should switch to the kid view on next foreground. Tap a chore's checkmark → see the +N pts celebration.
- **routines**: tap the wand icon top-right of Home → + to create a routine → add 2–3 tasks → save → tap "Spawn now" on the card → confirm "for today" → check MyToDo for the spawned tasks.
- **streaks**: complete one chore today, leaderboard should show 🔥1. Complete another tomorrow → 🔥2. Hitting 3 days awards the "3-day streak" badge automatically.
- **recap**: Sunday 7pm → notification fires. To test before Sunday, edit the weekday in `NotificationsManager.scheduleWeeklyRecap` (or just wait).
- **team-goals**: Add Goal → select "👨‍👩‍👧‍👦 Whole family" → set a target like 50 pts → save. As any member earns points, the goal card's progress reflects the family total.
- **quick-add**: create a few tasks via Add Task. Each appears as a chip on Home. Tap chip → instant re-spawn for today with the same details.
- **avatar-levels**: any member with ≥50 points now has a colored ring around their avatar everywhere it appears.
- **family-stats**: tap the chart icon on Home → scroll through the stats page.

## If you want a combo

Order of merges if you want them all:

```bash
git checkout main
git merge starfield
git merge routines
git merge streaks         # streaks references kid view in Rewards only, no conflict
git merge recap
git merge team-goals
git merge quick-add
git merge avatar-levels   # touches Cottage in many places — may need light conflict resolution
git merge family-stats
```

Most pairs are independent. The two most likely to conflict on merge:
- `quick-add` adds a `canManage` helper to Home; `routines` also adds one. Whichever merges first wins; the second is a no-op identical helper that gets dropped.
- `avatar-levels` rewrites every CLAvatar callsite — anything that touches Cottage's avatar code (e.g. a future branch adding a new view that calls CLAvatar) will need a small re-swap to LeveledAvatar.

## What's intentionally not built

- **Photo-proof chores** — needs CloudKit asset sync, deferred until photo-sync TODO is closed.
- **Apple Watch app** — needs a new Xcode target, best done with Geezy at the keyboard.
- **Lock-screen widget** — same; new extension target.
- **iMessage app** — same.
- **Bedtime mode for kids** — pairs naturally with starfield; build after starfield is verified.

Anything else? See `~/.claude/projects/-Users-geezy-Documents-casaList/memory/` for active TODOs.
