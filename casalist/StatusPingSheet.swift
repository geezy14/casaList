import SwiftUI
import CoreData
import CoreLocation

/// Manual status broadcast — tap a preset or type custom text, hit Send,
/// every family member gets a local push notification.
///
/// Mechanism: creates a TaskItem with category = "statusping". That
/// record syncs via CloudKit. Each device's foreground sync runs
/// `NotificationsManager.detectAndNotifyStatusPings` which fires a local
/// push for any new ping not from this device. The ping record itself
/// is ephemeral — filtered out of every task list, and auto-purged
/// after 24h via the existing Trash mechanism.
struct StatusPingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var moc
    @AppStorage("userName") private var userName: String = ""
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: true)],
                  predicate: NSPredicate(format: "deletedAt == nil"))
    private var households: FetchedResults<Household>

    @State private var customText: String = ""
    @State private var locationError: String? = nil
    @StateObject private var locator = OneShotLocator()

    /// Flip to `true` to re-enable the one-shot "Share my location" row.
    /// Hidden for now — the live-share (Settings → Privacy → Share my
    /// location) covers the same "where is everyone" need without
    /// requiring a fresh GPS fix every time. Tap-to-Maps from the push
    /// also wasn't auto-opening reliably; deferred for a future pass.
    /// Helpers (`OneShotLocator`, `StatusPing.encodeLocationPing` /
    /// `parseLocationPing`) remain in code so flipping this back on is
    /// a one-line change.
    private let shareLocationEnabled: Bool = false

    private let presets: [(emoji: String, text: String)] = [
        ("🚗", "On my way home"),
        ("🛒", "At the store"),
        ("⏰", "Running late"),
        ("🍽️", "Dinner's ready"),
        ("🆘", "I need help"),
        ("👋", "Just checking in")
    ]

    var body: some View {
        NavigationStack {
            Form {
                if shareLocationEnabled {
                    Section("Share your location") {
                        Button {
                            sendLocation()
                        } label: {
                            HStack {
                                Text("📍").font(.system(size: 22))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Share my location").font(.system(size: 16, weight: .semibold))
                                    Text("Captures your spot once and sends a tap-to-map ping.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if locator.isWorking {
                                    ProgressView()
                                } else {
                                    Image(systemName: "paperplane.fill").foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(locator.isWorking)
                        if let err = locationError {
                            Text(err).font(.caption).foregroundStyle(.red)
                        }
                    }
                }
                Section("Quick send") {
                    ForEach(presets, id: \.text) { p in
                        Button {
                            send(message: "\(p.emoji) \(p.text)")
                        } label: {
                            HStack {
                                Text(p.emoji).font(.system(size: 22))
                                Text(p.text).font(.system(size: 16, weight: .semibold))
                                Spacer()
                                Image(systemName: "paperplane.fill").foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Section("Custom") {
                    TextField("Type a message…", text: $customText, axis: .vertical)
                        .lineLimit(2...4)
                    Button {
                        let trimmed = customText.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        send(message: trimmed)
                    } label: {
                        Label("Send", systemImage: "paperplane.fill")
                    }
                    .disabled(customText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Section {
                    Label("Sends a notification to everyone in your household.",
                          systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ping family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func send(message: String) {
        let trimmedUser = userName.trimmingCharacters(in: .whitespaces)
        let ping = TaskItem(
            context: moc,
            task: message,
            category: StatusPing.category,
            points: 0,
            createdBy: trimmedUser
        )
        if let h = households.preferredTarget {
            moc.assign(ping, toStoreOf: h)
            ping.household = h
        }
        try? moc.save()
        dismiss()
    }

    private func sendLocation() {
        locationError = nil
        locator.fetchOnce { result in
            switch result {
            case .success(let coord):
                let body = StatusPing.encodeLocationPing(coordinate: coord)
                send(message: body)
            case .failure(let err):
                locationError = err.localizedDescription
            }
        }
    }
}

/// Sentinel + helpers for the status-ping subsystem.
enum StatusPing {
    /// Category value stored on TaskItem for ping records. Filtered out
    /// of every other task view by predicate.
    static let category = "statusping"

    /// Predicate fragment to filter pings out of task fetches. Append
    /// to existing predicates that aren't specifically looking for pings.
    static let excludePredicate = NSPredicate(format: "category != %@", category)

    /// Suffix attached to ping text when the sender shared a one-shot
    /// location. Format: "📍 At a location <<lat,lng>>". Receivers strip
    /// the suffix for display and tap to open Apple Maps.
    static let locationOpener = " <<"
    static let locationCloser = ">>"

    /// Pack a coordinate into a ping message.
    static func encodeLocationPing(coordinate: CLLocationCoordinate2D) -> String {
        let lat = String(format: "%.6f", coordinate.latitude)
        let lng = String(format: "%.6f", coordinate.longitude)
        return "📍 Here I am\(locationOpener)\(lat),\(lng)\(locationCloser)"
    }

    /// Pull a coordinate out of a ping message, if present. Returns
    /// (displayText, coordinate?). When no location suffix, returns
    /// the message unchanged and a nil coordinate.
    static func parseLocationPing(_ msg: String) -> (display: String, coordinate: CLLocationCoordinate2D?) {
        guard let open = msg.range(of: locationOpener),
              let close = msg.range(of: locationCloser, range: open.upperBound..<msg.endIndex) else {
            return (msg, nil)
        }
        let coordStr = String(msg[open.upperBound..<close.lowerBound])
        let parts = coordStr.split(separator: ",")
        guard parts.count == 2,
              let lat = Double(parts[0]),
              let lng = Double(parts[1]) else { return (msg, nil) }
        let display = String(msg[msg.startIndex..<open.lowerBound])
        return (display, CLLocationCoordinate2D(latitude: lat, longitude: lng))
    }
}

// MARK: – One-shot locator

import Combine

/// Fetches a single high-accuracy location fix and stops. Wraps
/// CLLocationManager.requestLocation() which is exactly that — Apple's
/// documented one-shot fetch.
@MainActor
final class OneShotLocator: NSObject, ObservableObject {
    @Published var isWorking: Bool = false

    private let manager = CLLocationManager()
    private var completion: ((Result<CLLocationCoordinate2D, Error>) -> Void)?

    enum LocatorError: LocalizedError {
        case notAuthorized
        case timedOut
        var errorDescription: String? {
            switch self {
            case .notAuthorized: return "Location access denied. Enable it in iOS Settings → Privacy → Location."
            case .timedOut:      return "Couldn't get a location fix in time."
            }
        }
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func fetchOnce(_ completion: @escaping (Result<CLLocationCoordinate2D, Error>) -> Void) {
        self.completion = completion
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
            // Wait for delegate to call back with the answer.
            return
        }
        if status == .denied || status == .restricted {
            completion(.failure(LocatorError.notAuthorized))
            self.completion = nil
            return
        }
        isWorking = true
        manager.requestLocation()
    }
}

extension OneShotLocator: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                if self.completion != nil {
                    self.isWorking = true
                    manager.requestLocation()
                }
            } else if status == .denied || status == .restricted {
                self.completion?(.failure(LocatorError.notAuthorized))
                self.completion = nil
                self.isWorking = false
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.completion?(.success(loc.coordinate))
            self.completion = nil
            self.isWorking = false
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.completion?(.failure(error))
            self.completion = nil
            self.isWorking = false
        }
    }
}
