import SwiftUI

/// Surfaces `CasaCoreDataStack.lastSaveError` to the user.
///
/// The stack already publishes save failures (commit e51e8b3) and posts
/// `.casaCoreDataSaveDidFail`, but until this banner exists the only
/// people who see them are devs reading NSLog or share-log.txt. A
/// silent rollback feels to the user like their tap "worked" — they
/// don't realize the chore wasn't actually marked done, or the new
/// reminder didn't save.
///
/// Banner pinned to the top safe-area inset (under the local-fallback
/// banner if both are active). Auto-dismisses 6 seconds after the
/// error first appears so a transient blip doesn't camp on the UI
/// forever; tap-to-dismiss for impatience.
struct SaveErrorBannerOverlay: ViewModifier {
    @ObservedObject private var stack = CasaCoreDataStack.shared
    @State private var dismissedAt: Date? = nil

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if let err = stack.lastSaveError, dismissedAt == nil {
                    SaveErrorBanner(message: shortMessage(for: err)) {
                        dismissedAt = Date()
                        // Don't clear the published error — the next
                        // successful save still needs to flip it to nil.
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: ObjectIdentifier(err as AnyObject)) {
                        // Auto-dismiss after 6s.
                        try? await Task.sleep(nanoseconds: 6_000_000_000)
                        dismissedAt = Date()
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: stack.lastSaveError == nil)
            .onChange(of: stack.lastSaveError == nil) { _, isNil in
                if isNil { dismissedAt = nil }  // ready to show the next one
            }
    }

    private func shortMessage(for error: Error) -> String {
        let ns = error as NSError
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
            return underlying.localizedDescription
        }
        return ns.localizedDescription
    }
}

private struct SaveErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Couldn't save change")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "xmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(red: 0.78, green: 0.22, blue: 0.18),
                         Color(red: 0.92, green: 0.40, blue: 0.18)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
    }
}
