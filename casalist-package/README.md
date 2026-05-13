# Casalist — SwiftUI directions handoff

Five distinct design directions for the Casalist home dashboard + Chore Rewards screen, each as a self-contained SwiftUI file. Drop the ones you want into Xcode and call e.g. `CasalistHearth.Home()`.

## Files

| File | Direction | Vibe |
|---|---|---|
| `CasalistShared.swift` | **Required** | Data models, family avatars, `Color(rgb:)` helper. All other files depend on this. |
| `CasalistHearth.swift` | **1 · Hearth** | Warm, homey, Apple-native. Cream + terracotta + sage. Default light, supports dark. iOS 17+. |
| `CasalistGlasshouse.swift` | **2 · Glasshouse** | Modern fintech glass. Aurora gradient bg + Liquid Glass cards + gradient accents. Default dark, supports light. **iOS 26+** (uses `.glassEffect()`). |
| `CasalistCottage.swift` | **3 · Cottage** | Playful family-friendly. Rounded everything, pastel color blocks, sticky-note agenda. Default light. iOS 17+. |
| `CasalistNotebook.swift` | **4 · Notebook** | Notion-style minimal. Monochrome + one accent, hairline borders, info-dense. iOS 17+. |
| `CasalistNeon.swift` | **5 · Neon** | Bold expressive color blocks. Brutalist meets neon. Black/white + lime/magenta/cyan/orange. Default dark. iOS 17+. |

Each direction file exposes:
- `<Direction>.Home()` — the dashboard
- `<Direction>.Rewards()` — the Chore Rewards / leaderboard screen

Both screens include a sun/moon toggle in the top-right that flips between light and dark mode, overriding the system theme.

## Target

- **iOS 17+** for Hearth, Cottage, Notebook, Neon.
- **iOS 26+** for Glasshouse (Liquid Glass APIs).
- **Xcode 17+**.
- No third-party dependencies. All icons are SF Symbols.

## Drop in

1. Drag `CasalistShared.swift` plus any direction file(s) into your Xcode project.
2. Present the home screen anywhere:

```swift
NavigationStack {
    CasalistHearth.Home()      // or .Glasshouse / .Cottage / .Notebook / .Neon
        .navigationDestination(for: String.self) { _ in
            CasalistHearth.Rewards()
        }
}
```

The Chore Rewards screen calls `@Environment(\.dismiss)` for the back button, so it works inside any `NavigationStack` or `.sheet`.

## Wire up

Currently the `+` buttons, "Claim" buttons, quick-add, and back chevrons are visual only — wire them to your data layer.

Family, agenda, modules, leaderboard, recent rewards, and goals all read from `Casalist.*` static data in `CasalistShared.swift`. Replace with your CloudKit / SwiftData fetches:

```swift
extension Casalist {
    static var family: [CLFamilyMember] { /* fetch from CloudKit */ }
    static var agenda: [CLAgendaItem] { /* today's items */ }
    static var activity: [CLActivity] { /* feed */ }
    // ...
}
```

Keep the shape of each model type (`CLFamilyMember`, `CLAgendaItem`, etc.) and every direction renders correctly.

## Family roster

The default mock data uses geezy / Lorena / Donovan / Dakodoa with assigned colors per member. Each member's color is used across:
- Avatar gradient
- Activity feed names
- Leaderboard bars
- Goal progress fills

Change `Casalist.family` in `CasalistShared.swift` to swap names/colors.
