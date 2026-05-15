import Foundation
import CoreData

/// Soft-delete helpers. Setting `deletedAt = Date()` flags a record as
/// trashed without removing it; restore by clearing the field. Records
/// older than `retentionDays` are eventually purged for real.
extension NSManagedObject {
    /// Mark a record as soft-deleted (timestamps now). Caller must save.
    func softDelete() {
        setValue(Date(), forKey: "deletedAt")
    }

    /// Clear the soft-delete flag. Caller must save.
    func restore() {
        setValue(nil, forKey: "deletedAt")
    }

    var deletedAtValue: Date? {
        value(forKey: "deletedAt") as? Date
    }
}

enum Trash {
    /// How long soft-deleted records linger before they're purged for good.
    static let retentionDays: Int = 30

    /// Permanently purges soft-deleted records older than `retentionDays`.
    /// Runs on app launch via HouseholdProvisioner.
    static func purgeExpired(in context: NSManagedObjectContext) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        let entityNames = ["FamilyMember", "TaskItem", "FamilyGoal", "FamilyEvent", "Household"]
        var purged = 0
        for name in entityNames {
            let req = NSFetchRequest<NSManagedObject>(entityName: name)
            req.predicate = NSPredicate(format: "deletedAt != nil AND deletedAt < %@", cutoff as NSDate)
            if let results = try? context.fetch(req) {
                for obj in results {
                    context.delete(obj)
                    purged += 1
                }
            }
        }
        if purged > 0 {
            try? context.save()
            NSLog("Casa Trash: purged \(purged) records older than \(retentionDays) days")
        }
    }
}
