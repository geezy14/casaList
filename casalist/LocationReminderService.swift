import Foundation
import CoreLocation
import CoreData
import Combine
import UserNotifications

/// Region-monitoring driver for location-based reminders.
///
/// Each active reminder with `locationRadius > 0` gets a
/// `CLCircularRegion` registered with iOS. When the user enters or
/// exits that region the system delivers a delegate callback even if
/// Casalist isn't running, and we fire a local notification.
///
/// Notes on the Apple constraints:
/// - iOS limits us to **20 simultaneously monitored regions per app**.
///   We honor that by capping at 20 most-recent reminders (more than
///   enough for a household reminder app).
/// - Region monitoring needs **Always** authorization to fire when the
///   app is suspended. `LocationSharingService` already prompts for
///   Always when the user enables location sharing; if they haven't,
///   we prompt the first time they add a location-based reminder.
/// - Distinct from `LocationSharingService` deliberately — that one
///   publishes the user's coordinates to CloudKit; this one watches
///   geofences and fires notifications. They're separate concerns and
///   shouldn't share state.
@MainActor
final class LocationReminderService: NSObject, ObservableObject {
    static let shared = LocationReminderService()

    private let manager: CLLocationManager
    private let maxRegions: Int = 20

    override private init() {
        self.manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.allowsBackgroundLocationUpdates = false
        manager.pausesLocationUpdatesAutomatically = true
    }

    /// Ask for Always authorization. Required for region monitoring to
    /// fire when the app is in the background. Caller should explain
    /// the prompt before invoking.
    func requestAuthorization() {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse {
            // Promote to Always so monitoring fires when suspended.
            manager.requestAlwaysAuthorization()
        }
    }

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }

    var canMonitor: Bool {
        CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) &&
        (manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse)
    }

    /// Resync monitored regions to match what's in Core Data. Call
    /// from app launch, after any reminder add/edit/delete, and after
    /// the auth status changes.
    func resyncMonitoredRegions(in ctx: NSManagedObjectContext) {
        // Tear down anything previously monitored that we registered.
        for r in manager.monitoredRegions where r.identifier.hasPrefix("rem-") {
            manager.stopMonitoring(for: r)
        }
        guard canMonitor else { return }
        let req: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        req.predicate = NSPredicate(
            format: "deletedAt == nil AND category ==[c] %@ AND locationRadius > 0 AND isCompleted == NO",
            "reminders"
        )
        req.sortDescriptors = [NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: false)]
        req.fetchLimit = maxRegions
        let tasks = (try? ctx.fetch(req)) ?? []
        for t in tasks {
            let region = makeRegion(for: t)
            manager.startMonitoring(for: region)
        }
    }

    private func makeRegion(for t: TaskItem) -> CLCircularRegion {
        let coord = CLLocationCoordinate2D(latitude: t.locationLat, longitude: t.locationLng)
        let region = CLCircularRegion(
            center: coord,
            radius: max(50, min(t.locationRadius, 10_000)),
            identifier: "rem-\(t.uid)"
        )
        // Fire either direction; we filter inside the delegate so the
        // user can change their mind without re-monitoring.
        region.notifyOnEntry = true
        region.notifyOnExit = true
        return region
    }

    // MARK: – Firing

    fileprivate func fire(identifier: String, didEnter: Bool) {
        guard identifier.hasPrefix("rem-") else { return }
        let uid = String(identifier.dropFirst("rem-".count))
        let ctx = CasaCoreDataStack.shared.context
        let req: NSFetchRequest<TaskItem> = TaskItem.fetchRequest()
        req.predicate = NSPredicate(format: "uid == %@", uid)
        req.fetchLimit = 1
        guard let t = (try? ctx.fetch(req))?.first else { return }
        // Respect the user's "arrive" vs "leave" choice.
        if didEnter && !t.locationOnArrive { return }
        if !didEnter && t.locationOnArrive { return }

        let content = UNMutableNotificationContent()
        content.title = t.task
        let where_ = t.locationName.isEmpty ? "location" : t.locationName
        content.body = didEnter ? "Arriving at \(where_)" : "Leaving \(where_)"
        content.sound = .default
        content.categoryIdentifier = "REMINDER_FIRE"
        content.userInfo = ["taskUid": t.uid]
        let request = UNNotificationRequest(
            identifier: "rem-loc-\(t.uid)-\(didEnter ? "in" : "out")",
            content: content,
            trigger: nil   // fire immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}

extension LocationReminderService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        let id = region.identifier
        Task { @MainActor in self.fire(identifier: id, didEnter: true) }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        let id = region.identifier
        Task { @MainActor in self.fire(identifier: id, didEnter: false) }
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Auth granted now? Re-register so reminders added before
        // authorization start monitoring.
        Task { @MainActor in
            let ctx = CasaCoreDataStack.shared.context
            self.resyncMonitoredRegions(in: ctx)
        }
    }
}
