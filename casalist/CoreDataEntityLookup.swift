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
        // Mirror to share-log.txt so the field-side log captures it.
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
           let data = "[\(ISO8601DateFormatter().string(from: Date()))] \(msg)\n".data(using: .utf8) {
            let url = docs.appendingPathComponent("share-log.txt")
            if FileManager.default.fileExists(atPath: url.path),
               let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
        preconditionFailure(msg)
    }
}
