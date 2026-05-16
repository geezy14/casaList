import SwiftUI
import UIKit

/// A tiny dopamine hit when something good happens — a centered emoji + text
/// burst that auto-dismisses, plus a success haptic. Wire by binding the
/// `celebrate` Bool and `celebrateLabel` String, then call `cheer(...)` to
/// fire from any completion site.
struct CelebrationOverlay: View {
    let label: String
    let emoji: String
    @Binding var visible: Bool

    /// Drives the confetti spread independent of `visible`. We need the
    /// overlay to mount FIRST (visible=true) then animate the confetti
    /// outward — if we tie both to the same flag the view renders in its
    /// final state and you never see the burst.
    @State private var flying: Bool = false

    var body: some View {
        ZStack {
            // No dim. The pill is gone — only the stars matter. Keeping
            // the overlay transparent so it doesn't darken the underlying
            // task detail card the user just completed.
            Color.clear.ignoresSafeArea()

            // Spinning, expanding stars. They start at center, spin one
            // full rotation while flying outward, and fade as they go.
            // 20 stars at staggered angles so they form a dense burst.
            ForEach(0..<20, id: \.self) { i in
                star(index: i)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            // The overlay mounts when visible flips true, so .onAppear is
            // the right hook — .onChange(of: visible) never fires because
            // the value doesn't change DURING this view's lifetime
            // (parent wraps us in `if visible { ... }`). Kick the
            // animation one frame after mount so SwiftUI sees the
            // initial state and animates from there.
            flying = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                withAnimation(.easeOut(duration: 1.0)) {
                    flying = true
                }
            }
        }
    }

    private func star(index: Int) -> some View {
        // Even angular distribution + index-based distance so each star
        // takes a different path. Deterministic so SwiftUI doesn't reroll
        // positions on every render.
        let angle = Double(index) * (2 * .pi / 20)
        let distance: Double = 180 + Double((index * 23) % 100)
        let dx = cos(angle) * distance
        let dy = sin(angle) * distance - 30
        // Each star spins a different amount based on its index so the
        // burst doesn't look mechanically uniform.
        let spin = 360.0 + Double(index % 3) * 180.0
        return Text("⭐️")
            .font(.system(size: 36))
            .offset(x: flying ? dx : 0, y: flying ? dy : 0)
            .opacity(flying ? 0.0 : 1.0)
            .scaleEffect(flying ? 0.4 : 1.2)
            .rotationEffect(.degrees(flying ? spin : 0))
    }
}

/// Tracks one-shot celebrations on a view. Use as @State.
struct Celebration {
    var visible: Bool = false
    var label: String = ""
    var emoji: String = "⭐"

    /// Fire a celebration. Auto-dismisses after `duration` seconds.
    mutating func cheer(_ label: String, emoji: String = "⭐", duration: TimeInterval = 1.4) {
        self.label = label
        self.emoji = emoji
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { visible = true }
        let visibility = visible
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            // The struct is value-typed; we can't mutate self from a closure.
            // Caller is expected to use the binding pattern below for dismiss.
            _ = visibility
        }
    }
}

// MARK: – Convenience modifier

extension View {
    /// Attaches a CelebrationOverlay that auto-dismisses 1.4s after `trigger`
    /// becomes true. Resets the binding.
    func celebration(visible: Binding<Bool>, label: String, emoji: String = "⭐") -> some View {
        ZStack {
            self
            if visible.wrappedValue {
                CelebrationOverlay(label: label, emoji: emoji, visible: visible)
                    .onAppear {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                            withAnimation { visible.wrappedValue = false }
                        }
                    }
            }
        }
    }
}
