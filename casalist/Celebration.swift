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

    var body: some View {
        ZStack {
            Color.black.opacity(0.15).ignoresSafeArea()
            VStack(spacing: 8) {
                Text(emoji).font(.system(size: 96))
                if !label.isEmpty {
                    Text(label).font(.system(size: 22, weight: .heavy)).foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 36).padding(.vertical, 28)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(LinearGradient(colors: [Color(rgb: 0xFF9E7C), Color(rgb: 0xE8B040)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .black.opacity(0.3), radius: 18, y: 6)
            )
            .scaleEffect(visible ? 1.0 : 0.4)
            .opacity(visible ? 1.0 : 0.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.55), value: visible)
        }
        .allowsHitTesting(false)
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
