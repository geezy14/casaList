import SwiftUI
import MapKit
import Combine

/// A bundled location result — text + coordinates — that we hand back to the
/// caller (AddEventView) when the user picks an autocomplete suggestion.
struct PickedLocation: Equatable {
    var name: String
    var subtitle: String
    var latitude: Double
    var longitude: Double

    var displayName: String {
        subtitle.isEmpty ? name : "\(name), \(subtitle)"
    }
}

/// MKLocalSearchCompleter wrapped so SwiftUI can observe the search results
/// as `@StateObject`. Update `query` and `results` publishes the suggestions.
final class LocationCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query: String = "" { didSet { completer.queryFragment = query } }
    @Published var results: [MKLocalSearchCompletion] = []

    private let completer: MKLocalSearchCompleter

    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async { self.results = completer.results }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async { self.results = [] }
    }

    /// Resolve a tapped suggestion to a full MKMapItem (coordinates).
    func resolve(_ completion: MKLocalSearchCompletion) async -> PickedLocation? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        guard let response = try? await search.start(),
              let item = response.mapItems.first else { return nil }
        let coord = item.placemark.coordinate
        return PickedLocation(
            name: completion.title,
            subtitle: completion.subtitle,
            latitude: coord.latitude,
            longitude: coord.longitude
        )
    }
}

/// Modal location picker. Search-as-you-type, suggestions list, tap to pick.
struct LocationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var completer = LocationCompleter()
    let onPick: (PickedLocation) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search for a place", text: $completer.query)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                    }
                }
                if !completer.results.isEmpty {
                    Section("Suggestions") {
                        ForEach(Array(completer.results.enumerated()), id: \.offset) { _, r in
                            Button {
                                pick(r)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.title).foregroundStyle(.primary)
                                    if !r.subtitle.isEmpty {
                                        Text(r.subtitle).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.row)
                        }
                    }
                } else if !completer.query.isEmpty {
                    Section {
                        Text("No matches yet — try a longer query.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Pick a location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func pick(_ completion: MKLocalSearchCompletion) {
        Task {
            if let picked = await completer.resolve(completion) {
                await MainActor.run {
                    onPick(picked)
                    dismiss()
                }
            }
        }
    }
}

/// Read-only preview map showing a single pin for a stored location.
/// When `radius` > 0 the map also draws a translucent circle so the
/// caller can visualize the geofence area for location-based reminders.
struct LocationMiniMap: View {
    let latitude: Double
    let longitude: Double
    let title: String
    /// Geofence radius in meters. 0 hides the circle and falls back
    /// to a fixed-zoom view (legacy behavior used by AddEventView).
    var radiusMeters: Double = 0

    private var coord: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Pick a map span that frames the geofence with breathing room.
    /// ~111 km per degree of latitude → convert radius to degrees and
    /// scale up so the circle fills ~60% of the map width.
    private var region: MKCoordinateRegion {
        let baseSpan: Double = 0.01
        let span: Double
        if radiusMeters > 0 {
            let degrees = radiusMeters / 111_000
            span = max(baseSpan, degrees * 3.2)
        } else {
            span = baseSpan
        }
        return MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
    }

    var body: some View {
        // `id: radiusMeters` forces the map to recompute its position
        // when the slider moves so the framing keeps up.
        Map(initialPosition: .region(region)) {
            Marker(title, coordinate: coord)
            if radiusMeters > 0 {
                MapCircle(center: coord, radius: radiusMeters)
                    .foregroundStyle(Color.accentColor.opacity(0.22))
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
        .id(radiusMeters)
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .disabled(true) // read-only preview — tap doesn't pan
    }
}
