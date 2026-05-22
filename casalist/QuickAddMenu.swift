import SwiftUI

/// The quick-add control that replaces the settings cog in the top bars.
/// Tap → opens the add screen directly (which itself has New task / New
/// bundle / Reminder tabs), so there's no redundant picker step.
struct QuickAddMenu: View {
    let palette: CasalistCottage.Palette
    @State private var showAdd = false

    private var P: CasalistCottage.Palette { palette }

    var body: some View {
        Button { showAdd = true } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(P.text)
                .frame(width: 38, height: 38)
                .background(Circle().fill(P.surfaceAlt))
        }
        .sheet(isPresented: $showAdd) { AddTaskView() }
    }
}
