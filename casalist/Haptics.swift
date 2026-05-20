import UIKit

/// Shared, retained feedback generators.
///
/// The app previously fired haptics with
/// `UINotificationFeedbackGenerator().notificationOccurred(.success)` — a
/// fresh generator created inline and deallocated immediately. Rapidly
/// creating/destroying generators (e.g. checking off several chores in a
/// row) leaves the Taptic Engine un-prepared and makes it stop responding
/// after a few taps. Retaining one generator and calling `prepare()`
/// before each play keeps the engine warm so haptics keep firing.
@MainActor
enum Haptics {
    private static let notify = UINotificationFeedbackGenerator()
    private static let impactLight = UIImpactFeedbackGenerator(style: .light)

    /// Success "thunk" — used when a chore/quest is checked off.
    static func success() {
        notify.prepare()
        notify.notificationOccurred(.success)
        // Re-prime for the next call so back-to-back completions keep buzzing.
        notify.prepare()
    }

    static func warning() {
        notify.prepare()
        notify.notificationOccurred(.warning)
        notify.prepare()
    }

    static func light() {
        impactLight.prepare()
        impactLight.impactOccurred()
        impactLight.prepare()
    }
}
