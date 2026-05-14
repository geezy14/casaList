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
        privateDesc.configuration = "Private"
        privateDesc.shouldMigrateStoreAutomatically = true
        privateDesc.shouldInferMappingModelAutomatically = true
        let privateOpts = NSPersistentCloudKitContainerOptions(containerIdentifier: casalistCloudKitContainerID)
        privateOpts.databaseScope = .private
        privateDesc.cloudKitContainerOptions = privateOpts
        privateDesc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        privateDesc.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        let sharedURL = base.appendingPathComponent("Casalist-Shared.sqlite")
        let sharedDesc = NSPersistentStoreDescription(url: sharedURL)
        sharedDesc.configuration = "Shared"
        sharedDesc.shouldMigrateStoreAutomatically = true
        sharedDesc.shouldInferMappingModelAutomatically = true
        let sharedOpts = NSPersistentCloudKitContainerOptions(containerIdentifier: casalistCloudKitContainerID)
        sharedOpts.databaseScope = .shared
        sharedDesc.cloudKitContainerOptions = sharedOpts
        sharedDesc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        sharedDesc.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.persistentStoreDescriptions = [privateDesc, sharedDesc]

        container.loadPersistentStores { [weak self] desc, error in
            if let error {
                NSLog("Casa Core Data load error: \(error)")
                return
            }
            guard let store = self?.container.persistentStoreCoordinator.persistentStore(for: desc.url!) else { return }
            if desc.cloudKitContainerOptions?.databaseScope == .private {
                self?.privateStore = store
            } else if desc.cloudKitContainerOptions?.databaseScope == .shared {
                self?.sharedStore = store
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    var context: NSManagedObjectContext { container.viewContext }

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
            attr("uid", .UUIDAttributeType, optional: false),
            attr("name", .stringAttributeType, def: "My Household"),
            attr("createdAt", .dateAttributeType, def: Date()),
        ]

        // ------- FamilyMember attributes -------
        familyMember.properties = [
            attr("uid", .UUIDAttributeType, optional: false),
            attr("name", .stringAttributeType, def: ""),
            attr("role", .stringAttributeType, def: ""),
            attr("colorHex", .integer64AttributeType, def: 0xC97357),
            attr("points", .integer64AttributeType, def: 0),
            attr("createdAt", .dateAttributeType, def: Date()),
            attr("roleLevel", .stringAttributeType, def: "standard"),
            attr("photoData", .binaryDataAttributeType, externalStorage: true),
        ]

        // ------- TaskItem attributes -------
        taskItem.properties = [
            attr("uid", .stringAttributeType, optional: false, def: ""),
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
        ]

        // ------- FamilyGoal attributes -------
        familyGoal.properties = [
            attr("uid", .UUIDAttributeType, optional: false),
            attr("ownerName", .stringAttributeType, def: ""),
            attr("label", .stringAttributeType, def: ""),
            attr("targetPoints", .integer64AttributeType, def: 100),
            attr("createdAt", .dateAttributeType, def: Date()),
        ]

        // ------- ChoreTemplate attributes -------
        choreTemplate.properties = [
            attr("uid", .UUIDAttributeType, optional: false),
            attr("label", .stringAttributeType, def: ""),
            attr("points", .integer64AttributeType, def: 10),
            attr("symbol", .stringAttributeType, def: "checkmark.circle"),
            attr("createdAt", .dateAttributeType, def: Date()),
        ]

        // ------- FamilyEvent attributes -------
        familyEvent.properties = [
            attr("uid", .UUIDAttributeType, optional: false),
            attr("title", .stringAttributeType, def: ""),
            attr("startDate", .dateAttributeType, def: Date()),
            attr("isAllDay", .booleanAttributeType, def: false),
            attr("location", .stringAttributeType, def: ""),
            attr("attendees", .stringAttributeType, def: ""),
            attr("notes", .stringAttributeType, def: ""),
            attr("repeatKind", .stringAttributeType, def: ""),
            attr("createdAt", .dateAttributeType, def: Date()),
            attr("createdBy", .stringAttributeType, def: ""),
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

        // Each store gets one configuration name; both share the same entities.
        model.setEntities(model.entities, forConfigurationName: "Private")
        model.setEntities(model.entities, forConfigurationName: "Shared")

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
}

extension NSManagedObject: @retroactive Identifiable {
    public var id: NSManagedObjectID { objectID }
}
