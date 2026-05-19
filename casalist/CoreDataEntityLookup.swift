import CoreData
import Foundation

/// Centralized, force-unwrap-free entity lookup. The convenience
/// initializers on TaskItem / FamilyMember / FamilyGoal / FamilyEvent /
/// ChoreTemplate were all doing
///
///     NSEntityDescription.entity(forEntityName: "X", in: context)!
///
/// which crashes with a useless "unexpectedly found nil" message if the
/// model ever loses an entity (rename, schema corruption, broken merged
/// model, etc.). Resolving the entity is still mandatory — these inits
/// cannot return nil — but a precondition gives a clear diagnostic and
/// logs to share-log.txt so we can see it post-mortem on a real device.
enum CasaEntity {
    static func resolve(_ name: String, in context: NSManagedObjectContext) -> NSEntityDescription {
        if let entity = NSEntityDescription.entity(forEntityName: name, in: context) {
            return entity
        }
        let msg = "Casa: missing Core Data entity \"\(name)\" — model out of sync"
        NSLog(msg)
        CasaShareLog.append(msg)
        preconditionFailure(msg)
    }
}
