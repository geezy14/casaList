import SwiftUI

/// Top-of-screen warning when `CasaCoreDataStack` has fallen back to the
/// local-only sqlite store because CloudKit-backed stores failed to load.
/// Without this banner the app looks fully functional even though sync is
/// effectively off — changes made now won't reach other family members.
struct LocalFallbackBannerOverlay: ViewModifier {
    @ObservedObject private var stack = CasaCoreDataStack.shared

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .top, spacing: 0) {
            if stack.isLocalFallback {
                LocalFallbackBanner()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: stack.isLocalFallback)
    }
}

private struct LocalFallbackBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "icloud.slash.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Sync is unavailable")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Changes you make now stay on this device and may not appear for family members. Reopen the app once iCloud is reachable.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(red: 0.85, green: 0.30, blue: 0.20),
                         Color(red: 0.95, green: 0.50, blue: 0.20)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}
