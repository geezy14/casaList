import SwiftUI

/// View modifier that adds an iOS-style left-edge swipe-back gesture for
/// modally presented views (fullScreenCovers don't get the native swipe
/// the way pushed NavigationStack screens do). Drag from the left ~30pt of
/// the view rightward past 80pt → dismisses.
struct SwipeToDismissModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content.gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .global)
                .onEnded { value in
                    let startedFromEdge = value.startLocation.x < 30
                    let swipedRight = value.translation.width > 80
                    let mostlyHorizontal = abs(value.translation.width) > abs(value.translation.height)
                    if startedFromEdge && swipedRight && mostlyHorizontal {
                        dismiss()
                    }
                }
        )
    }
}

extension View {
    /// iOS-style left-edge swipe-back to dismiss the current view.
    func swipeToDismiss() -> some View { modifier(SwipeToDismissModifier()) }
}
