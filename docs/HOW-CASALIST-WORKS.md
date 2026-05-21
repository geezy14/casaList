# 🏡 How Casalist Works

## The big idea
Casalist turns running a household into a lightweight game. Adults set up
chores worth points; kids (and anyone) complete them to earn points, climb
levels, build streaks, unlock badges, and cash points in for real rewards.
Everything syncs across the whole family in real time over iCloud.

The core loop:
> **Do chores → earn points → level up + cash in rewards → repeat**

---

## 💰 Points — two buckets (this trips people up)
Every person has **two** point counters:

| Counter | What it does | Goes down? |
|---|---|---|
| **Balance (spendable)** | Your currency. Cash it in for rewards. | Yes — drops when you redeem |
| **Lifetime (XP)** | All-time total. Drives your **level**. | **Never** — only climbs |

Completing a chore adds to **both**. Redeeming a reward subtracts only from
your **balance** — your level never drops for spending. Points an admin
awards with the **+/- buttons** also count toward lifetime (so given points
level you up, not just your balance).

Chores are worth up to **15 base points** (set per category in Game Rules);
anything above 15 comes from **bonuses** (chore bundles, etc.).

---

## 🎚️ Levels (1 → 10) and the climb
Your **lifetime points** unlock 10 levels. The curve is gentle early and
steep late — quick wins at the start, a real grind to Legend:

| Lvl | Name | Lifetime pts | Chores* | Tier |
|---|---|---|---|---|
| 1 | Rookie | 0 | 0 | 🌱 Sprout |
| 2 | Broom Pilot | 25 | 2 | 🌱 Sprout |
| 3 | Mop Jockey | 60 | 4 | 🌱 Sprout |
| 4 | Chore Warrior | 110 | 8 | 🔥 Ember |
| 5 | Task Slayer | 180 | 12 | 🔥 Ember |
| 6 | Achiever | 280 | 19 | 🔥 Ember |
| 7 | Pro | 420 | 28 | 🔥 Ember |
| 8 | Expert | 620 | 41 | 💎 Diamond |
| 9 | Master | 940 | 63 | 💎 Diamond |
| 10 | Legend | 1,300 | 87 | 💎 Diamond |

\* approx chores to reach, at 15 pts each. First 5 levels in ~12 chores;
Legend ≈ 87. (Higher-value or bonus chores get there faster.)

The hero card shows an **XP bar** filling toward your *next* level — so
day-to-day you're chasing a small, reachable number, not the 1,300.

---

## 🏆 Tiers (the avatar badge + ring)
Three tiers group the 10 levels, each with its own non-medal badge and ring
color (kept distinct from the leaderboard's 🥇🥈🥉 placement medals):

| Tier | Badge | Ring | Levels |
|---|---|---|---|
| **Sprout** | 🌱 | Green | 1–3 |
| **Ember** | 🔥 | Orange | 4–7 |
| **Diamond** | 💎 | Cyan | 8–10 |

Tier follows your level, which follows lifetime points — so a person in 1st
place who's only Level 4 shows an Ember badge (tier), while the gold "1" next
to their name is their placement (rank). Two different things.

---

## 🔥 Streaks
**Daily streak** (per person): complete at least one point chore today →
streak +1; do it again tomorrow → it grows (`current` + all-time `best`
tracked). Miss a day → resets to 0. There's a **1-day grace** (still counts
if your last completion was today or yesterday).

**Reminder streaks** are separate — each recurring reminder carries its own
🔥 counter when checked off on schedule.

---

## 🏅 Badges (9, per person, auto-unlocked)
| Badge | How to earn |
|---|---|
| 🎯 First chore | Complete your first chore |
| 🔟 Ten down | 10 chores |
| 🥇 Half-century | 50 chores |
| 💯 100 club | 100 cumulative points |
| 🚀 500 club | 500 points |
| 🔥 3-day streak | Best streak ≥ 3 |
| 📅 Week strong | Best streak ≥ 7 |
| 🏆 Two-week wonder | Best streak ≥ 14 |
| 🎁 First reward | Redeem your first reward |

---

## 🎁 Rewards economy
**Exchange rate: 5 points = $1.** Reward costs scale off that:

| Reward | $ | Points | Chores @15 |
|---|---|---|---|
| Small | $10 | 50 | ~4 |
| Medium | $30 | 150 | 10 |
| Large | $75 | 375 | 25 |
| (example) | $70 | 350 | ~24 |

There's also a **curated redeem catalog** (tap to request at a fixed cost):
30 min screen time 25 · 1 hr gaming 50 · pick the movie 40 · pick dinner 50
· stay up late 25 · skip a chore 75 · ice cream trip 100 · store trip 100 ·
arcade day 250 · small toy 125.

Requests go to an admin to **approve/deny** (admins set the final price for
free-form requests). You can attach a **web link** to an item so the parent
sees exactly what's being asked for. Already-requested items show a
**PENDING** pill; unaffordable ones show "Need X more pts."

All of this is editable per household in **Settings → Game Rules** (rate,
reward tiers, category point values, catalog items, chore expiration).

---

## 👨‍👩‍👧 Roles
- **Admin / Owner** — sets rules + point values, approves rewards, adjusts
  points with +/-, manages the family.
- **Kid / Standard** — completes chores, requests rewards (needs approval),
  sees a personalized view.

## ⚡ Active Quests & 🏆 Leaderboard
ACTIVE QUESTS = the open, point-earning chores (kids see their own; admins
see everyone's, grouped). Recurring chores leave the list when done and
return on their next scheduled day. The leaderboard ranks everyone by
points with a gold/silver/bronze podium.

## 🔗 Family sharing
One household shared across everyone's iPhones via iCloud/CloudKit — a chore
created on one phone shows on all within seconds. Each person picks their own
layout (Classic / Rings / Calm / Kanban) per device.
