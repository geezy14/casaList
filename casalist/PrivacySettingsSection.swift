import SwiftUI
import CoreLocation

/// Privacy section for Settings — currently houses the live-location
/// share toggle. Isolated in its own View struct for the same reason
/// the notification + developer sections are (avoid iOS 26 metadata
/// demangler stack overflows from large TupleView bodies).
struct PrivacySettingsSection: View {
    @StateObject private var loc = LocationSharingService.shared
    @AppStorage("shareMyLocation") private var shareMyLocation: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PRIVACY")
                .font(.system(size: 11, weight: .heavy)).tracking(1.2)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                PrivacyLocationToggleRow(shareMyLocation: $shareMyLocation,
                                         authStatus: loc.authorizationStatus,
                                         lastError: loc.lastError)
                if loc.authorizationStatus == .denied || loc.authorizationStatus == .restricted {
                    PrivacyOpenSettingsRow()
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .onChange(of: shareMyLocation) { _, on in
            if on { loc.start() } else { loc.stop() }
        }
    }
}

private struct PrivacyLocationToggleRow: View {
    @Binding var shareMyLocation: Bool
    let authStatus: CLAuthorizationStatus
    let lastError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Share my location with family", isOn: $shareMyLocation)
            Text(captionText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private var captionText: String {
        switch authStatus {
        case .denied, .restricted:
            return "Location access denied. Enable in iOS Settings → Privacy → Location."
        case .authorizedAlways:
            return "Updates when you move (background)."
        case .authorizedWhenInUse:
            return "Updates while Casalist is open. Tap to allow background updates."
        case .notDetermined:
            return shareMyLocation
                ? "iOS will ask permission when you toggle this."
                : "Off — no coordinates leave your device."
        @unknown default:
            return ""
        }
    }
}

private struct PrivacyOpenSettingsRow: View {
    var body: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack {
                Text("Open iOS Settings").font(.system(size: 14, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }.buttonStyle(.row)
    }
}
