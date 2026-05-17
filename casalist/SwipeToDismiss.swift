import SwiftUI
import UIKit

/// View modifier that adds an iOS-style left-edge swipe-back gesture for
/// modally presented views (fullScreenCovers don't get the native swipe
/// the way pushed NavigationStack screens do).
///
/// Implementation: overlays a full-height UIKit pan recognizer that only
/// activates when the gesture STARTS within 44 pt of the left edge. A
/// plain UIPanGestureRecognizer is used instead of the system-level
/// UIScreenEdgePanGestureRecognizer because iOS 26 intercepts edge pans
/// at the window level (for the new navigation chrome) before our
/// UIViewRepresentable view can see them.
///
/// When `action` is supplied, that runs instead of `dismiss()` —
/// useful for TabView pages where "back" means switching the visible
/// tag, not dismissing a sheet/cover.
struct SwipeToDismissModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    var action: (() -> Void)? = nil

    func body(content: Content) -> some View {
        content.overlay(
            EdgePanView { triggerBack() }
                .allowsHitTesting(true)
                .ignoresSafeArea()
        )
    }

    private func triggerBack() {
        if let action { action() } else { dismiss() }
    }
}

/// Full-size transparent UIKit view that intercepts left-edge pans.
/// Uses `shouldRecognizeSimultaneously` so it never blocks scroll views.
private struct EdgePanView: UIViewRepresentable {
    var onTrigger: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onTrigger: onTrigger) }

    func makeUIView(context: Context) -> PassthroughView {
        let v = PassthroughView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = true
        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handle(_:))
        )
        pan.delegate = context.coordinator
        // Allow simultaneous recognition with scroll views so we
        // don't accidentally steal scroll events.
        v.addGestureRecognizer(pan)
        return v
    }

    func updateUIView(_ uiView: PassthroughView, context: Context) {
        context.coordinator.onTrigger = onTrigger
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTrigger: () -> Void
        private var startLocation: CGPoint = .zero

        init(onTrigger: @escaping () -> Void) { self.onTrigger = onTrigger }

        // Allow our pan to coexist with UIScrollView's pan — we only
        // TRIGGER if the gesture started at the left edge, so even if
        // we run alongside a scroll gesture we won't actually fire.
        func gestureRecognizer(
            _ g: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }

        // Require that the gesture starts near the left edge of the
        // containing view. The touch threshold (44pt) matches Apple's
        // own interactive-pop zone on NavigationStack.
        func gestureRecognizer(
            _ g: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            startLocation = touch.location(in: g.view)
            return startLocation.x < 44
        }

        @objc func handle(_ g: UIPanGestureRecognizer) {
            guard g.state == .ended else { return }
            // Guard again: must have started at left edge.
            guard startLocation.x < 44 else { return }
            let t = g.translation(in: g.view)
            let v = g.velocity(in: g.view)
            let crossedThreshold = t.x > 60 || v.x > 400
            let mostlyHorizontal = abs(t.x) > abs(t.y)
            if crossedThreshold && mostlyHorizontal {
                onTrigger()
            }
        }
    }

    /// Transparent pass-through view — taps fall through to SwiftUI;
    /// only the pan recognizer captures input (and only when it starts
    /// at the left edge).
    final class PassthroughView: UIView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            // Return self so the pan recognizer can begin, but only for
            // touches that start in the left 44pt zone. Touches outside
            // that zone fall through to underlying views.
            return point.x < 44 ? self : nil
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
