import Foundation
import CoreData
import CloudKit

/// CloudKit container identifier shared across the app.
let casalistCloudKitContainerID = "iCloud.com.gbrown10.casalist"

/// NSPersistentCloudKitContainer with one private store (this user's data, syncs
/// across their own devices) and one shared store (data other family members
/// have shared with this user via CKShare).
///
/// The private store is where the user's owning household lives. When they share
/// the household, Core Data moves its records into a shareable CKShare zone on
/// the private database. Recipients accept the share and the records appear in
/// their **shared** store. Both stores back the same entity definitions so views
/// can query across both.
final class CasaCoreDataStack {
    static let shared = CasaCoreDataStack()

    let container: NSPersistentCloudKitContainer

    private(set) var privateStore: NSPersistentStore?
    private(set) var sharedStore: NSPersistentStore?

    private init() {
        let model = CasaCoreDataStack.makeModel()
        container = NSPersistentCloudKitContainer(name: "Casalist", managedObjectModel: model)

        let base = NSPersistentContainer.defaultDirectoryURL()
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        let privateURL = base.appendingPathComponent("Casalist-Private.sqlite")
        let privateDesc = NSPersistentStoreDescription(url: privateURL)
        privateDesc.shouldMigrateStoreAutomatically = true
        privateDesc.shouldInferMappingModelAutomatically = true
        let privateOpts = NSPersistentCloudKitContainerOptions(containerIdentifier: casalistCloudKitContainerID)
        privateOpts.databaseScope = .private
        privateDesc.cloudKitContainerOptions = privateOpts
        privateDesc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        privateDesc.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        let sharedURL = base.appendingPathComponent("Casalist-Shared.sqlite")
        let sharedDesc = NSPersistentStoreDescription(url: sharedURL)
        sharedDesc.shouldMigrateStoreAutomatically = true
        sharedDesc.shouldInferMappingModelAutomatically = true
        let sharedOpts = NSPersistentCloudKitContainerOptions(containerIdentifier: casalistCloudKitContainerID)
        sharedOpts.databaseScope = .shared
        sharedDesc.cloudKitContainerOptions = sharedOpts
        sharedDesc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        sharedDesc.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.persistentStoreDescriptions = [privateDesc, sharedDesc]

        var loadFailed = false
        let group = DispatchGroup()
        for _ in 0..<2 { group.enter() }
        container.loadPersistentStores { [weak self] desc, error in
            defer { group.leave() }
            if let error {
                NSLog("Casa Core Data load error (\(desc.cloudKitContainerOptions?.databaseScope.rawValue ?? -1)): \(error)")
                loadFailed = true
                return
            }
            NSLog("Casa Core Data store loaded: \(desc.url?.lastPathComponent ?? "?")")
            guard let store = self?.container.persistentStoreCoordinator.persistentStore(for: desc.url!) else { return }
            if desc.cloudKitContainerOptions?.databaseScope == .private {
                self?.privateStore = store
            } else if desc.cloudKitContainerOptions?.databaseScope == .shared {
                self?.sharedStore = store
            }
        }
        group.wait()
        if loadFailed {
            NSLog("Casa: CloudKit-backed stores failed; falling back to local-only store")
            // Remove any partially-loaded CloudKit stores and reload with a local-only store.
            for s in container.persistentStoreCoordinator.persistentStores {
                try? container.persistentStoreCoordinator.remove(s)
            }
            let localURL = base.appendingPathComponent("Casalist-Local.sqlite")
            let local = NSPersistentStoreDescription(url: localURL)
            container.persistentStoreDescriptions = [local]
            container.loadPersistentStores { desc, error in
                if let error { NSLog("Casa Core Data local fallback also failed: \(error)") }
                else { NSLog("Casa Core Data local fallback loaded") }
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Log every NSPersistentCloudKitContainer sync event so we can see
        // whether exports are happening (and if they fail). Lands in
        // share-log.txt alongside CKShare accept events.
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: container,
            queue: nil
        ) { note in
            guard let evt = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else { return }
            let type: String
            switch evt.type {
            case .setup:  type = "setup"
            case .import: type = "import"
            case .export: type = "export"
            @unknown default: type = "?"
            }
            let phase: String
            if evt.endDate == nil {
                phase = "started"
            } else if evt.succeeded {
                phase = "ok"
            } else {
                phase = "FAILED"
            }
            let store = String(evt.storeIdentifier.prefix(8))
            var msg = "CK.\(type) [\(store)] \(phase)"
            if let err = evt.error as NSError? {
                func walk(_ e: NSError, depth: Int) -> String {
                    let indent = String(repeating: "  ", count: depth)
                    var s = "\(indent)\(e.domain)/\(e.code) \(e.localizedDescription)"
                    if let perItem = e.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
                        for (id, sub) in perItem {
                            s += "\n\(indent)  · \(id): \(walk(sub as NSError, depth: depth + 2))"
                        }
                    }
                    let keys = e.userInfo.keys.filter { ($0 != CKPartialErrorsByItemIDKey) && ($0 != "NSUnderlyingError") }
                    for k in keys {
                        if let v = e.userInfo[k] {
                            s += "\n\(indent)  \(k): \(v)"
                        }
                    }
                    if let underlying = e.userInfo["NSUnderlyingError"] as? NSError {
                        s += "\n\(indent)  underlying:\n\(walk(underlying, depth: depth + 2))"
                    }
                    return s
                }
                msg += "\n" + walk(err, depth: 1)
            }
            NSLog("Casa CK: \(msg)")
            // Mirror to share-log.txt so we can pull it via devicectl.
            let stamp = ISO8601DateFormatter().string(from: Date())
            let line = "[\(stamp)] \(msg)\n"
            if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let url = docs.appendingPathComponent("share-log.txt")
                if let data = line.data(using: .utf8) {
                    if FileManager.default.fileExists(atPath: url.path),
                       let handle = try? FileHandle(forWritingTo: url) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        try? handle.close()
                    } else {
                        try? data.write(to: url)
                    }
                }
            }
        }
    }

    var context: NSManagedObjectContext { container.viewContext }

    /// Pushes the complete schema (including all CloudKit-sharing system fields
    /// like CD_moveReceipt) into the **Development** CloudKit container. Call
    /// this once after a model change while the app is pointed at Dev. After it
    /// completes, go to the CloudKit Dashboard and Deploy to Production.
    ///
    /// Apple specifically calls this out as the way to materialise the
    /// schema fields that sharing needs — without it, the fields don't exist
    /// until the first time share() runs, which fails on Production.
    func initializeCloudKitSchemaForDevelopment() throws {
        try container.initializeCloudKitSchema(options: [])
    }

    func save() {
        let ctx = container.viewContext
        guard ctx.hasChanges else { return }
        do { try ctx.save() } catch {
            NSLog("Casa Core Data save error: \(error)")
            ctx.rollback()
        }
    }

    // MARK: Model

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // ------- Entities -------
        let household = NSEntityDescription()
        household.name = "Household"
        household.managedObjectClassName = "Household"

        let familyMember = NSEntityDescription()
        familyMember.name = "FamilyMember"
        familyMember.managedObjectClassName = "FamilyMember"

        let taskItem = NSEntityDescription()
        taskItem.name = "TaskItem"
        taskItem.managedObjectClassName = "TaskItem"

        let familyGoal = NSEntityDescription()
        familyGoal.name = "FamilyGoal"
        familyGoal.managedObjectClassName = "FamilyGoal"

        let choreTemplate = NSEntityDescription()
        choreTemplate.name = "ChoreTemplate"
        choreTemplate.managedObjectClassName = "ChoreTemplate"

        let familyEvent = NSEntityDescription()
        familyEvent.name = "FamilyEvent"
        familyEvent.managedObjectClassName = "FamilyEvent"

        // ------- Attributes helpers -------
        func attr(_ name: String, _ type: NSAttributeType, optional: Bool = true, def: Any? = nil, externalStorage: Bool = false) -> NSAttributeDescription {
            let a = NSAttributeDescription()
            a.name = name
            a.attributeType = type
            a.isOptional = optional
            a.defaultValue = def
            if externalStorage { a.allowsExternalBinaryDataStorage = true }
            return a
        }

        // ------- Household attributes -------
        household.properties = [
            attr("uid", .UUIDAttributeType),
            attr("name", .stringAttributeType, def: "My Household"),
            attr("createdAt", .dateAttributeType, def: Date()),
            attr("deletedAt", .dateAttributeType),
            // JSON-encoded [ChoreRoutineTemplate]. Stored on Household so the
            // template list syncs across family members through the shared
            // store. Schema redeploy required before this field syncs in
            // Production CloudKit — see ChoreRoutines.swift.
            attr("routinesJSON", .stringAttributeType, def: ""),
        ]

        // ------- FamilyMember attributes -------
        familyMember.properties = [
            attr("uid", .UUIDAttributeType),
            attr("name", .stringAttributeType, def: ""),
            attr("role", .stringAttributeType, def: ""),
            attr("colorHex", .integer64AttributeType, def: 0xC97357),
            attr("points", .integer64AttributeType, def: 0),
            attr("createdAt", .dateAttributeType, def: Date()),
            attr("roleLevel", .stringAttributeType, def: "standard"),
            // Inline binary (no external storage / CKAsset) — NSPersistentCloudKitContainer
            // syncs inline BYTES fields reliably in shared zones, where the
            // CKAsset path is flaky. 1024px JPEG at ~80% quality stays well
            // under CloudKit's 1MB per-record limit.
            attr("photoBlob", .binaryDataAttributeType, externalStorage: false),
            attr("deletedAt", .dateAttributeType),
        ]

        // ------- TaskItem attributes -------
        taskItem.properties = [
            attr("uid", .stringAttributeType, def: ""),
            attr("task", .stringAttributeType, def: ""),
            attr("assignee", .stringAttributeType),
            attr("dueDate", .dateAttributeType),
            attr("category", .stringAttributeType, def: ""),
            attr("isCompleted", .booleanAttributeType, def: false),
            attr("points", .integer64AttributeType, def: 0),
            attr("createdAt", .dateAttributeType, def: Date()),
            attr("createdBy", .stringAttributeType, def: ""),
            attr("repeatHours", .integer64AttributeType, def: 0),
            attr("repeatKind", .stringAttributeType, def: ""),
            attr("completionCount", .integer64AttributeType, def: 0),
            attr("parentUid", .stringAttributeType, def: ""),
            attr("deletedAt", .dateAttributeType),
            // Stamped by FamilyPoints.toggle when a task transitions
            // false → true (cleared on un-complete). Drives WHAT'S NEW
            // ordering and Kid view's "My Wins" log so completions sort by
            // when they actually happened, not when the task was created.
            attr("completedAt", .dateAttributeType),
            // Stop-time-of-day for cadence reminders (hourly / every2h /
            // every4h / every8h / every12h). Stored as minutes-since-
            // midnight. 0 = no stop time (default); 1-1439 = stop at this
            // minute-of-day. Schema redeploy required before this syncs in
            // Production.
            attr("repeatEndMinutes", .integer64AttributeType, def: 0),
        ]

        // ------- FamilyGoal attributes -------
        familyGoal.properties = [
            attr("uid", .UUIDAttributeType),
            attr("ownerName", .stringAttributeType, def: ""),
            attr("label", .stringAttributeType, def: ""),
            attr("targetPoints", .integer64AttributeType, def: 100),
            attr("createdAt", .dateAttributeType, def: Date()),
            attr("isRedeemed", .booleanAttributeType, optional: false, def: false),
            attr("redeemedAt", .dateAttributeType),
            attr("deletedAt", .dateAttributeType),
            // Optional context written by the requester (kid or non-admin)
            // explaining what they want and why. Shown to the admin in the
            // approval flow. Empty string for parent-created goals.
            attr("note", .stringAttributeType, def: ""),
        ]

        // ------- ChoreTemplate attributes -------
        choreTemplate.properties = [
            attr("uid", .UUIDAttributeType),
            attr("label", .stringAttributeType, def: ""),
            attr("points", .integer64AttributeType, def: 10),
            attr("symbol", .stringAttributeType, def: "checkmark.circle"),
            attr("createdAt", .dateAttributeType, def: Date()),
        ]

        // ------- FamilyEvent attributes -------
        familyEvent.properties = [
            attr("uid", .UUIDAttributeType),
            attr("title", .stringAttributeType, def: ""),
            attr("startDate", .dateAttributeType, def: Date()),
            attr("isAllDay", .booleanAttributeType, def: false),
            attr("location", .stringAttributeType, def: ""),
            attr("latitude", .doubleAttributeType, optional: false, def: 0.0),
            attr("longitude", .doubleAttributeType, optional: false, def: 0.0),
            attr("attendees", .stringAttributeType, def: ""),
            attr("notes", .stringAttributeType, def: ""),
            attr("repeatKind", .stringAttributeType, def: ""),
            attr("createdAt", .dateAttributeType, def: Date()),
            attr("createdBy", .stringAttributeType, def: ""),
            attr("deletedAt", .dateAttributeType),
        ]

        // ------- Relationships (Household is the share root) -------
        func relate(parent: NSEntityDescription, parentName: String, child: NSEntityDescription, childName: String) {
            let toMany = NSRelationshipDescription()
            toMany.name = childName
            toMany.destinationEntity = child
            toMany.minCount = 0
            toMany.maxCount = 0 // unbounded
            toMany.deleteRule = .cascadeDeleteRule
            toMany.isOptional = true

            let toOne = NSRelationshipDescription()
            toOne.name = parentName
            toOne.destinationEntity = parent
            toOne.minCount = 0
            toOne.maxCount = 1
            toOne.deleteRule = .nullifyDeleteRule
            toOne.isOptional = true

            toMany.inverseRelationship = toOne
            toOne.inverseRelationship = toMany

            parent.properties.append(toMany)
            child.properties.append(toOne)
        }

        relate(parent: household, parentName: "household", child: familyMember, childName: "members")
        relate(parent: household, parentName: "household", child: taskItem, childName: "tasks")
        relate(parent: household, parentName: "household", child: familyGoal, childName: "goals")
        relate(parent: household, parentName: "household", child: choreTemplate, childName: "chores")
        relate(parent: household, parentName: "household", child: familyEvent, childName: "events")

        model.entities = [household, familyMember, taskItem, familyGoal, choreTemplate, familyEvent]
        return model
    }
}

extension NSManagedObjectContext {
    /// Returns the persistent store the given object lives in (private or
    /// shared). Useful for choosing which scope a new record should be inserted
    /// into.
    func storeFor(_ object: NSManagedObject) -> NSPersistentStore? {
        object.objectID.persistentStore
    }

    /// Assigns a brand-new (not yet saved) record to live in the same persistent
    /// store as `parent`. Required for CloudKit-shared data: a record attached
    /// to a household in the shared store must also live in the shared store,
    /// otherwise Core Data drops the cross-store relationship and the new
    /// record is invisible to other share participants.
    func assign(_ child: NSManagedObject, toStoreOf parent: NSManagedObject) {
        guard let store = parent.objectID.persistentStore else { return }
        assign(child, to: store)
    }
}

extension Sequence where Element == Household {
    /// Household to attach a newly created record to. Joiners must write into
    /// the *shared* household so the owner sees the record; owners only have a
    /// private household so the fallback covers them.
    var preferredTarget: Household? {
        let stack = CasaCoreDataStack.shared
        if let shared = first(where: { $0.objectID.persistentStore == stack.sharedStore }) {
            return shared
        }
        if let priv = first(where: { $0.objectID.persistentStore == stack.privateStore }) {
            return priv
        }
        return first(where: { _ in true })
    }
}

extension Household: Identifiable {}
extension FamilyMember: Identifiable {}
extension TaskItem: Identifiable {}
extension FamilyGoal: Identifiable {}
extension ChoreTemplate: Identifiable {}
extension FamilyEvent: Identifiable {}
