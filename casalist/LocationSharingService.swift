import Foundation
import CoreLocation
import CoreData
import Combine
import UIKit

/// Manages live-location sharing for the current user.
///
/// Design choices (per Apple's location guidelines):
/// - **Significant location changes** instead of continuous updates.
///   Apple's recommended low-power mode — fires when the device moves
///   ~500m. Doesn't drain the battery the way `startUpdatingLocation()`
///   does.
/// - **When-in-use** permission is the minimum. We ask for **Always**
///   only when the user explicitly toggles sharing on, so iOS shows the
///   correct purpose string at the right moment.
/// - **Writes are gated on `FamilyMember.isSharingLocation`** so the
///   stored record never has stale coordinates after the user opted out.
@MainActor
final class LocationSharingService: NSObject, ObservableObject {
    static let shared = LocationSharingService()

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var lastError: String?

    private let manager: CLLocationManager
    private var isStarted: Bool = false
    /// Last position written to Core Data — used to throttle CloudKit
    /// writes. We only persist when the device has moved more than
    /// `minWriteDistanceMeters` OR `minWriteInterval` has elapsed.
    private var lastWritten: CLLocation?
    private let minWriteDistanceMeters: CLLocationDistance = 10
    private let minWriteInterval: TimeInterval = 30

    override private init() {
        self.manager = CLLocationManager()
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        // Best accuracy → sub-10m typical. If the user has disabled
        // "Precise Location" in iOS Settings → Privacy → Location, iOS
        // downgrades to ~1-3km regardless of what we ask for. The user's
        // accuracyAuthorization will reflect that.
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = minWriteDistanceMeters
        manager.pausesLocationUpdatesAutomatically = true
        manager.activityType = .other
    }

    /// Start sharing. Requests authorization if needed, flips the
    /// FamilyMember flag, kicks off significant-change monitoring.
    func start() {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
            // The actual start happens in `locationManagerDidChangeAuthorization`
            // when we hear back from the user.
            return
        }
        if status == .denied || status == .restricted {
            lastError = "Location access denied. Enable it in iOS Settings → Privacy → Location."
            setSharingFlag(false)
            return
        }
        // We have when-in-use. For background updates we need "always" —
        // request the upgrade once we know the user wants to share.
        if status == .authorizedWhenInUse {
            manager.requestAlwaysAuthorization()
        }
        // Continuous high-accuracy updates. Throttled in
        // `didUpdateLocations` so we only write to Core Data on real
        // movement (≥10m) or after 30s have elapsed since the last
        // write. Combined with `distanceFilter = 10m` on the manager,
        // this keeps battery + sync overhead reasonable while still
        // being precise enough to tell "in the house" from "outside."
        // Apple also enables background updates only when the
        // entitlement is set + the app is foreground at start. We
        // explicitly allow background updates so location keeps
        // flowing while Casalist isn't in front.
        manager.allowsBackgroundLocationUpdates = (status == .authorizedAlways)
        manager.showsBackgroundLocationIndicator = false
        manager.startUpdatingLocation()
        isStarted = true
        setSharingFlag(true)
    }

    /// Stop sharing. Clears the FamilyMember flag and zeros the coords
    /// so other devices see "off" rather than stale data.
    func stop() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        isStarted = false
        lastWritten = nil
        clearStoredCoordinates()
    }

    /// Reflect whatever's currently in storage. Call on app launch — if
    /// the user had sharing on at last quit, resume the monitor.
    func resumeIfPreviouslySharing() {
        let stack = CasaCoreDataStack.shared
        Task { @MainActor in
            guard let me = await FamilyIdentity.findSelf(in: stack.context),
                  me.isSharingLocation else { return }
            // Authorization may have been revoked while the app wasn't
            // running. If so, mirror that into storage.
            let status = manager.authorizationStatus
            if status == .denied || status == .restricted || status == .notDetermined {
                setSharingFlag(false)
                return
            }
            manager.allowsBackgroundLocationUpdates = (status == .authorizedAlways)
            manager.showsBackgroundLocationIndicator = false
            manager.startUpdatingLocation()
            isStarted = true
        }
    }

    // MARK: – Private

    private func setSharingFlag(_ on: Bool) {
        let stack = CasaCoreDataStack.shared
        Task { @MainActor in
            guard let me = await FamilyIdentity.findSelf(in: stack.context) else { return }
            me.isSharingLocation = on
            if !on {
                me.latitude = 0
                me.longitude = 0
                me.locationUpdatedAt = nil
            }
            try? stack.context.save()
        }
    }

    private func clearStoredCoordinates() {
        setSharingFlag(false)
    }

    private func writeLocation(_ loc: CLLocation) {
        let stack = CasaCoreDataStack.shared
        Task { @MainActor in
            guard let me = await FamilyIdentity.findSelf(in: stack.context),
                  me.isSharingLocation else { return }
            me.latitude = loc.coordinate.latitude
            me.longitude = loc.coordinate.longitude
            me.locationUpdatedAt = Date()
            try? stack.context.save()
        }
    }
}

extension LocationSharingService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                // Keep the background flag in sync with whatever level
                // of authorization we now have.
                manager.allowsBackgroundLocationUpdates = (manager.authorizationStatus == .authorizedAlways)
                manager.showsBackgroundLocationIndicator = false
                // First permission grant after start() — kick off
                // updates now that we have authorization.
                if !self.isStarted {
                    manager.startUpdatingLocation()
                    self.isStarted = true
                    self.setSharingFlag(true)
                }
            case .denied, .restricted:
                self.lastError = "Location access denied."
                self.setSharingFlag(false)
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        // Drop garbage: HACK accuracy, fixes older than 10s, or
        // accuracy worse than 100m (likely an early uncalibrated fix).
        guard loc.horizontalAccuracy > 0,
              loc.horizontalAccuracy < 100,
              Date().timeIntervalSince(loc.timestamp) < 10 else { return }
        Task { @MainActor in self.throttledWrite(loc) }
    }

    /// Only persist if the user has actually moved (≥10m) OR enough
    /// time has passed (≥30s). Prevents writing every GPS jitter.
    private func throttledWrite(_ loc: CLLocation) {
        if let last = lastWritten {
            let moved = loc.distance(from: last)
            let elapsed = Date().timeIntervalSince(last.timestamp)
            if moved < minWriteDistanceMeters && elapsed < minWriteInterval { return }
        }
        lastWritten = loc
        writeLocation(loc)
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.lastError = error.localizedDescription }
    }
}
