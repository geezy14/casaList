import SwiftUI

/// View modifier that adds an iOS-style left-edge swipe-back gesture for
/// modally presented views (fullScreenCovers don't get the native swipe
/// the way pushed NavigationStack screens do).
///
/// Uses a SwiftUI `DragGesture` with `simultaneousGesture` so it never
/// blocks buttons, text fields, or scroll views — taps pass through
/// uninterrupted. The gesture only fires when the drag STARTS within 44pt
/// of the left edge and moves rightward past a velocity/distance threshold.
///
/// When `action` is supplied, that runs instead of `dismiss()` —
/// useful for TabView pages where "back" means switching the visible
/// tag, not dismissing a sheet/cover.
struct SwipeToDismissModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    var action: (() -> Void)? = nil

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .global)
                .onEnded { value in
                    let startX  = value.startLocation.x
                    let tx      = value.translation.width
                    let ty      = value.translation.height
                    let vx      = value.velocity.width
                    guard startX < 44 else { return }           // must start at left edge
                    guard tx > 60 || vx > 400 else { return }  // distance or velocity
                    guard abs(tx) > abs(ty) else { return }     // mostly horizontal
                    triggerBack()
                }
        )
    }

    private func triggerBack() {
        if let action { action() } else { dismiss() }
    }
}

extension View {
    /// iOS-style left-edge swipe-back to dismiss the current view.
    func swipeToDismiss() -> some View { modifier(SwipeToDismissModifier()) }

    /// iOS-style left-edge swipe-back that runs a custom action (e.g.
    /// switching tabs back to dashboard for a TabView page).
    func swipeBack(action: @escaping () -> Void) -> some View {
        modifier(SwipeToDismissModifier(action: action))
    }
}
