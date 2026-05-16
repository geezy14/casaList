import SwiftUI
import MapKit
import CoreData

/// Shows every family member who's actively sharing location as a pin
/// on a map. Read-only — sharing toggle lives in Settings → Privacy.
struct FamilyMapView: View {
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.createdAt, ascending: true)],
        predicate: NSPredicate(format: "deletedAt == nil")
    )
    private var members: FetchedResults<FamilyMember>

    private var sharingMembers: [FamilyMember] {
        members.filter { $0.isSharingLocation && $0.locationUpdatedAt != nil }
    }

    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            Group {
                if sharingMembers.isEmpty {
                    emptyState
                } else {
                    Map(position: $camera) {
                        ForEach(sharingMembers, id: \.uid) { m in
                            let coord = CLLocationCoordinate2D(latitude: m.latitude, longitude: m.longitude)
                            Annotation(m.name, coordinate: coord) {
                                MemberPin(member: m)
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationTitle("Where's everyone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { recenter() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Nobody is sharing yet")
                .font(.system(size: 17, weight: .heavy))
            Text("Family members can opt in via Settings → Privacy → Share my location.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private func recenter() {
        let coords = sharingMembers.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        guard !coords.isEmpty else { return }
        // Fit all pins with some padding. For a single member, zoom in.
        if coords.count == 1 {
            let c = coords[0]
            camera = .region(MKCoordinateRegion(
                center: c,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
            return
        }
        let lats = coords.map(\.latitude)
        let lngs = coords.map(\.longitude)
        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLng = lngs.min() ?? 0
        let maxLng = lngs.max() ?? 0
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.01, (maxLat - minLat) * 1.5),
            longitudeDelta: max(0.01, (maxLng - minLng) * 1.5)
        )
        camera = .region(MKCoordinateRegion(center: center, span: span))
    }
}

private struct MemberPin: View {
    let member: FamilyMember

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(Color(rgb: UInt32(member.colorHex)))
                    .frame(width: 36, height: 36)
                if let blob = member.photoBlob, let ui = UIImage(data: blob) {
                    Image(uiImage: ui)
                        .resizable().scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                } else {
                    Text(initial)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
            if let updated = member.locationUpdatedAt {
                Text(updatedLabel(updated))
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(Color.black.opacity(0.7)))
                    .foregroundStyle(.white)
            }
        }
    }

    private var initial: String {
        String(member.name.prefix(1)).uppercased()
    }

    private func updatedLabel(_ d: Date) -> String {
        let seconds = Date().timeIntervalSince(d)
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h" }
        return "\(Int(seconds / 86400))d"
    }
}
