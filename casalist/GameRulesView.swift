import SwiftUI

// MARK: - Settings Section (wired into SettingsView)

struct GameRulesSettingsSection: View {
    let isAdmin: Bool
    @State private var showRules = false

    var body: some View {
        Button { showRules = true } label: {
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color(rgb: 0x7B5EA7)))
                Text(isAdmin ? "Game Rules & Point Values" : "View Game Rules")
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showRules) {
            GameRulesView(isAdmin: isAdmin)
        }
    }
}

// MARK: - Full Rules View

struct GameRulesView: View {
    let isAdmin: Bool
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = GameRulesStore.shared

    // Calculator state
    @State private var calcDollars: String = ""
    @State private var rateText: String = ""

    // Single enum to drive all sheets — avoids chaining ambiguity
    private enum ActiveSheet: Identifiable {
        case editTier(RewardTier)
        case editCat(CategoryPointRule)
        case addTier
        case addCat
        case editRedeem(RedeemableItem)
        case addRedeem
        var id: String {
            switch self {
            case .editTier(let t): return "editTier-\(t.id)"
            case .editCat(let c): return "editCat-\(c.id)"
            case .addTier: return "addTier"
            case .addCat: return "addCat"
            case .editRedeem(let r): return "editRedeem-\(r.id)"
            case .addRedeem: return "addRedeem"
            }
        }
    }
    @State private var activeSheet: ActiveSheet? = nil

    var body: some View {
        NavigationStack {
            rulesListView
                .navigationTitle(isAdmin ? "Game Rules" : "📋 Game Rules")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .sheet(item: $activeSheet) { sheet in
                    sheetContent(for: sheet)
                }
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .editTier(let tier):
            TierEditSheet(tier: tier) { updated in
                if let i = store.rules.rewardTiers.firstIndex(where: { $0.id == updated.id }) {
                    store.rules.rewardTiers[i] = updated
                }
            }
        case .editCat(let rule):
            CatEditSheet(rule: rule) { updated in
                if let i = store.rules.categoryRules.firstIndex(where: { $0.id == updated.id }) {
                    store.rules.categoryRules[i] = updated
                }
            }
        case .addTier:
            TierEditSheet(tier: RewardTier(name: "", minPoints: 200, emoji: "🎁", description: "")) { newTier in
                store.rules.rewardTiers.append(newTier)
                store.rules.rewardTiers.sort { $0.minPoints < $1.minPoints }
            }
        case .addCat:
            CatEditSheet(rule: CategoryPointRule(category: "", emoji: "✅", defaultPoints: 10, description: "")) { newRule in
                store.rules.categoryRules.append(newRule)
            }
        case .editRedeem(let item):
            RedeemEditSheet(item: item) { updated in
                if let i = store.rules.redeemableItems.firstIndex(where: { $0.id == updated.id }) {
                    store.rules.redeemableItems[i] = updated
                }
            }
        case .addRedeem:
            RedeemEditSheet(item: RedeemableItem(emoji: "🎁", name: "", points: 50, category: "Treats")) { newItem in
                store.rules.redeemableItems.append(newItem)
            }
        }
    }

    private var rulesListView: some View {
        List {
            // Reward calculator
            calculatorSection

            // Reward tiers
            Section(header: Label("REWARD TIERS", systemImage: "trophy.fill"),
                    footer: Text(isAdmin
                                 ? "Set the minimum points needed to unlock each reward tier. Kids and standard members see these thresholds."
                                 : "Save up points to unlock reward tiers. Ask an admin to redeem your reward.")) {
                tierRows()
            }

            // Category point values
            Section(header: Label("TASK POINT VALUES", systemImage: "bolt.fill"),
                    footer: Text(isAdmin
                                 ? "Default points suggested when creating tasks in each category. Individual tasks can still be adjusted."
                                 : "How many points each type of task is typically worth.")) {
                catRows()
            }

            // Redeemable item catalog
            Section(header: Label("REDEEMABLE ITEMS", systemImage: "gift.fill"),
                    footer: Text(isAdmin
                                 ? "Pre-built items kids tap to propose a reward at a known price. Tapping always still requires admin approval."
                                 : "Tap any of these on the Rewards tab to send your family a quick request.")) {
                redeemRows()
            }

            // Chore expiration window
            Section(header: Label("CHORE EXPIRATION", systemImage: "hourglass"),
                    footer: Text(isAdmin
                                 ? "Chores not finished within this window can still be checked off, but won't award points. Recurring chores never expire — each occurrence has its own clock."
                                 : "How long you have to finish a chore before it stops paying points.")) {
                expirationRow
            }

            if isAdmin {
                Section {
                    Button(role: .destructive) { store.reset() } label: {
                        Label("Reset to defaults", systemImage: "arrow.counterclockwise")
                    }
                }
            }
        }
    }

    // MARK: - Expiration Row

    /// Admin-editable picker that controls how many days after the
    /// due date (or createdAt, when there's no due date) a chore stops
    /// awarding points. Stored on the household via `GameRulesStore`
    /// so it syncs across devices.
    @ViewBuilder
    private var expirationRow: some View {
        if isAdmin {
            Picker(selection: $store.rules.expirationWindowDays) {
                Text("Off").tag(0)
                Text("1 day").tag(1)
                Text("3 days").tag(3)
                Text("7 days").tag(7)
                Text("14 days").tag(14)
            } label: {
                Label("Expires after", systemImage: "hourglass")
            }
        } else {
            HStack {
                Label("Expires after", systemImage: "hourglass")
                Spacer()
                Text(expirationLabel(store.rules.expirationWindowDays))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func expirationLabel(_ days: Int) -> String {
        switch days {
        case 0:    return "Off"
        case 1:    return "1 day"
        default:   return "\(days) days"
        }
    }

    // MARK: - Calculator Section

    private var calculatorSection: some View {
        Section(header: Label("REWARD CALCULATOR", systemImage: "dollarsign.circle.fill")) {
            calculatorCard
        }
    }

    private var calculatorCard: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Rate row (admin only)
            if isAdmin {
                HStack(spacing: 6) {
                    Text("Rate:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("\(store.rules.pointsPerDollar)", text: $rateText)
                        .keyboardType(.numberPad)
                        .font(.system(size: 13, weight: .heavy))
                        .frame(width: 48)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Color(.systemGray5)))
                        .onChange(of: rateText) { _, val in
                            if let n = Int(val), n > 0 { store.rules.pointsPerDollar = n }
                        }
                        .onAppear { rateText = "\(store.rules.pointsPerDollar)" }
                    Text("pts per $1")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            // Dollar input + result
            HStack(alignment: .center, spacing: 0) {
                // Input side
                HStack(spacing: 4) {
                    Text("$")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.secondary)
                    TextField("0", text: $calcDollars)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 36, weight: .heavy))
                        .frame(minWidth: 60)
                        .fixedSize()
                }

                Spacer()

                // Result side
                if let dollars = Double(calcDollars), dollars > 0 {
                    let pts = Int((dollars * Double(store.rules.pointsPerDollar)).rounded())
                    HStack(spacing: 4) {
                        Image(systemName: "equal")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(pts)")
                                .font(.system(size: 28, weight: .heavy))
                                .foregroundStyle(Color(rgb: 0x7B5EA7))
                            Text("pts needed")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("type an amount")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(.systemGray3))
                }
            }

            // Tier badge
            if let dollars = Double(calcDollars), dollars > 0 {
                let pts = Int((dollars * Double(store.rules.pointsPerDollar)).rounded())
                tierUnlockBadge(for: pts)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func tierUnlockBadge(for pts: Int) -> some View {
        let sorted = store.rules.rewardTiers.sorted { $0.minPoints > $1.minPoints }
        if let unlocked = sorted.first(where: { pts >= $0.minPoints }) {
            HStack(spacing: 6) {
                Text(unlocked.emoji)
                Text("Unlocks \(unlocked.name)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(rgb: 0x7B5EA7))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color(rgb: 0x7B5EA7).opacity(0.15)))
        } else {
            let lowest = store.rules.rewardTiers.sorted { $0.minPoints < $1.minPoints }.first
            if let t = lowest {
                HStack(spacing: 6) {
                    Text(t.emoji)
                    Text("\(t.minPoints - pts) more pts for \(t.name)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Tier / Cat Rows

    @ViewBuilder
    private func tierRows() -> some View {
        ForEach(store.rules.rewardTiers) { tier in
            tierRow(tier)
        }
        .onDelete { offsets in if isAdmin { deleteTier(at: offsets) } }
        if isAdmin {
            Button { activeSheet = .addTier } label: {
                Label("Add reward tier", systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(rgb: 0x7B5EA7))
            }
        }
    }

    @ViewBuilder
    private func catRows() -> some View {
        ForEach(store.rules.categoryRules) { rule in
            catRow(rule)
        }
        .onDelete { offsets in if isAdmin { deleteCat(at: offsets) } }
        if isAdmin {
            Button { activeSheet = .addCat } label: {
                Label("Add category rule", systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(rgb: 0x7B5EA7))
            }
        }
    }

    private func tierRow(_ tier: RewardTier) -> some View {
        HStack(spacing: 12) {
            Text(tier.emoji).font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text(tier.name).font(.system(size: 14, weight: .heavy))
                Text(tier.description)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(tier.minPoints) pts")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.secondary)
                if let dollars = tier.dollarValue {
                    Text(dollars.truncatingRemainder(dividingBy: 1) == 0
                         ? "~$\(Int(dollars))"
                         : "~$\(String(format: "%.2f", dollars))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.green.opacity(0.8))
                }
            }
            if isAdmin {
                Button { activeSheet = .editTier(tier) } label: {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(rgb: 0x7B5EA7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func catRow(_ rule: CategoryPointRule) -> some View {
        HStack(spacing: 12) {
            Text(rule.emoji).font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.category).font(.system(size: 14, weight: .heavy))
                Text(rule.description)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 4) {
                if rule.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.orange.opacity(0.8))
                }
                Text("\(rule.defaultPoints) pts")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.secondary)
            }
            if isAdmin {
                Button { activeSheet = .editCat(rule) } label: {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(rgb: 0x7B5EA7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func deleteTier(at offsets: IndexSet) {
        store.rules.rewardTiers.remove(atOffsets: offsets)
    }
    private func deleteCat(at offsets: IndexSet) {
        store.rules.categoryRules.remove(atOffsets: offsets)
    }
    private func deleteRedeem(at offsets: IndexSet) {
        store.rules.redeemableItems.remove(atOffsets: offsets)
    }

    // MARK: - Redeem rows

    @ViewBuilder
    private func redeemRows() -> some View {
        if store.rules.redeemableItems.isEmpty {
            Text("No items yet. Add one below.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
        } else {
            ForEach(store.rules.redeemableItems) { item in
                redeemRow(item)
            }
            .onDelete { offsets in if isAdmin { deleteRedeem(at: offsets) } }
        }
        if isAdmin {
            Button { activeSheet = .addRedeem } label: {
                Label("Add redeemable item", systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(rgb: 0x7B5EA7))
            }
        }
    }

    private func redeemRow(_ item: RedeemableItem) -> some View {
        HStack(spacing: 12) {
            Text(item.emoji).font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.system(size: 14, weight: .heavy))
                Text(item.category)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(item.points) pts")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.secondary)
            if isAdmin {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if isAdmin { activeSheet = .editRedeem(item) } }
    }
}

// MARK: - Tier Edit Sheet

private struct TierEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: RewardTier
    @State private var dollarText: String = ""
    let onSave: (RewardTier) -> Void

    init(tier: RewardTier, onSave: @escaping (RewardTier) -> Void) {
        _draft = State(initialValue: tier)
        let dv = tier.dollarValue
        _dollarText = State(initialValue: dv != nil
            ? (dv!.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(dv!))" : String(format: "%.2f", dv!))
            : "")
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tier name") {
                    TextField("e.g. Medium Reward", text: $draft.name)
                }
                Section("Emoji") {
                    TextField("🎁", text: $draft.emoji)
                }
                Section("Minimum points") {
                    Stepper("\(draft.minPoints) pts", value: $draft.minPoints, in: 0...10000, step: 25)
                }
                Section(header: Text("Dollar value (optional)"),
                        footer: Text("Shown as an approximate dollar equivalent on the tier. Leave blank to hide.")) {
                    HStack {
                        Text("$").foregroundStyle(.secondary)
                        TextField("e.g. 70", text: $dollarText)
                            .keyboardType(.decimalPad)
                    }
                }
                Section("Description") {
                    TextField("What can they redeem this for?", text: $draft.description, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(draft.name.isEmpty ? "New Tier" : draft.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        draft.dollarValue = Double(dollarText)
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Category Edit Sheet

private struct CatEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: CategoryPointRule
    let onSave: (CategoryPointRule) -> Void

    init(rule: CategoryPointRule, onSave: @escaping (CategoryPointRule) -> Void) {
        _draft = State(initialValue: rule)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category name") {
                    TextField("e.g. Chores", text: $draft.category)
                }
                Section("Emoji") {
                    TextField("🧹", text: $draft.emoji)
                }
                Section(header: Text("Default points"),
                        footer: Text(draft.isLocked
                                     ? "Locked — tasks in this category are always worth exactly \(draft.defaultPoints) pts. No one can change it per task."
                                     : "Points pre-fill when this category is picked. Can still be adjusted per task.")) {
                    Stepper("\(draft.defaultPoints) pts", value: $draft.defaultPoints, in: 0...500, step: 5)
                    Toggle(isOn: $draft.isLocked) {
                        HStack(spacing: 6) {
                            Image(systemName: draft.isLocked ? "lock.fill" : "lock.open")
                                .foregroundStyle(draft.isLocked ? Color.orange : Color.secondary)
                            Text(draft.isLocked ? "Points locked" : "Lock points")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                }
                Section("Description") {
                    TextField("Short description", text: $draft.description)
                }
            }
            .navigationTitle(draft.category.isEmpty ? "New Category Rule" : draft.category)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(draft); dismiss() }
                        .disabled(draft.category.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Redeem Edit Sheet

private struct RedeemEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: RedeemableItem
    let onSave: (RedeemableItem) -> Void

    init(item: RedeemableItem, onSave: @escaping (RedeemableItem) -> Void) {
        _draft = State(initialValue: item)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Emoji") {
                    TextField("🎁", text: $draft.emoji)
                }
                Section("Item name") {
                    TextField("e.g. 30 min screen time", text: $draft.name)
                }
                Section("Points") {
                    Stepper("\(draft.points) pts", value: $draft.points, in: 5...10_000, step: 5)
                }
                Section("Category") {
                    TextField("e.g. Treats, Privileges, Outings", text: $draft.category)
                }
            }
            .navigationTitle(draft.name.isEmpty ? "New Item" : draft.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(draft); dismiss() }
                        .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty || draft.emoji.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
