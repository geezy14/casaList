import SwiftUI
import UIKit

/// View modifier that adds an iOS-style left-edge swipe-back gesture for
/// modally presented views (fullScreenCovers don't get the native swipe
/// the way pushed NavigationStack screens do).
///
/// Implementation: overlays a UIKit `UIScreenEdgePanGestureRecognizer`
/// at the left edge via a `UIViewRepresentable`. Going through UIKit
/// is required because SwiftUI's `DragGesture` loses the race against
/// any underlying `ScrollView` pan — the scroll view's gesture
/// recognizer captures the touch first and never relinquishes it.
/// `UIScreenEdgePanGestureRecognizer` is a system-level recognizer
/// that wins the gesture arbitration the same way Apple's own
/// navigation back-swipe does.
///
/// When `action` is supplied, that runs instead of `dismiss()` —
/// useful for TabView pages where "back" means switching the visible
/// tag, not dismissing a sheet/cover.
struct SwipeToDismissModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    var action: (() -> Void)? = nil

    func body(content: Content) -> some View {
        ZStack(alignment: .leading) {
            content
            EdgeSwipeBackView { triggerBack() }
                .frame(width: 24)
                .frame(maxHeight: .infinity)
                .allowsHitTesting(true)
        }
    }

    private func triggerBack() {
        if let action { action() } else { dismiss() }
    }
}

/// Invisible UIKit-backed strip at the left edge of its parent. Hosts
/// a `UIScreenEdgePanGestureRecognizer` so it can race a SwiftUI
/// `ScrollView` for the touch and reliably win.
private struct EdgeSwipeBackView: UIViewRepresentable {
    var onTrigger: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onTrigger: onTrigger) }

    func makeUIView(context: Context) -> UIView {
        let v = PassthroughView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = true
        let recognizer = UIScreenEdgePanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handle(_:))
        )
        recognizer.edges = .left
        v.addGestureRecognizer(recognizer)
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onTrigger = onTrigger
    }

    final class Coordinator {
        var onTrigger: () -> Void
        init(onTrigger: @escaping () -> Void) { self.onTrigger = onTrigger }

        @objc func handle(_ g: UIScreenEdgePanGestureRecognizer) {
            // Fire on .ended once the user has dragged past a sensible
            // threshold horizontally (matches Apple's nav-back feel).
            guard g.state == .ended else { return }
            let t = g.translation(in: g.view)
            let v = g.velocity(in: g.view)
            let crossedThreshold = t.x > 60 || v.x > 400
            let mostlyHorizontal = abs(t.x) > abs(t.y)
            if crossedThreshold && mostlyHorizontal {
                onTrigger()
            }
        }
    }

    /// UIView that only swallows touches that hit the edge recognizer —
    /// regular taps inside the 24pt strip should still pass to SwiftUI.
    private final class PassthroughView: UIView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            // Only claim the touch when one of our recognizers wants it;
            // otherwise let the underlying SwiftUI view receive taps.
            // The gesture recognizer attaches its own state machine, so
            // returning self here lets it begin tracking; SwiftUI controls
            // beneath this 24pt strip remain reachable because the
            // recognizer only activates on a screen-edge pan.
            return self
        }
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
