import Foundation
import CoreData

@objc(TaskItem)
public final class TaskItem: NSManagedObject {
    @NSManaged public var uid: String
    @NSManaged public var task: String
    @NSManaged public var assignee: String?
    @NSManaged public var dueDate: Date?
    @NSManaged public var category: String
    @NSManaged public var isCompleted: Bool
    @NSManaged public var points: Int64
    @NSManaged public var createdAt: Date
    @NSManaged public var createdBy: String
    @NSManaged public var repeatHours: Int64
    @NSManaged public var repeatKind: String
    @NSManaged public var completionCount: Int64
    @NSManaged public var parentUid: String
    @NSManaged public var deletedAt: Date?
    @NSManaged public var completedAt: Date?
    @NSManaged public var repeatEndMinutes: Int64
    // Location-based reminders. See CasaCoreData attribute comments for
    // the semantics. radius == 0 means no location trigger.
    @NSManaged public var locationLat: Double
    @NSManaged public var locationLng: Double
    @NSManaged public var locationRadius: Double
    @NSManaged public var locationOnArrive: Bool
    @NSManaged public var locationName: String
    @NSManaged public var household: Household?

    var hasLocationTrigger: Bool { locationRadius > 0 }

    var isLive: Bool { deletedAt == nil }

    /// Family outings and grocery trips are stamped with `points = -1`
    /// at creation (`AddFamilyTripView`, `AddGroceryTripView`). This
    /// makes them recognizable as containers even when no date was
    /// scheduled — otherwise a dateless outing/trip would fall into
    /// the loose-items bucket and couldn't host nested children.
    /// Backward-compat: pre-existing outings created before this flag
    /// (points = 0, dueDate set) are still treated as containers via
    /// the explicit `dueDate != nil` clause in the trip filters.
    var isContainer: Bool { points == -1 && parentUid.isEmpty }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID().uuidString, forKey: "uid")
        setPrimitiveValue(Date(), forKey: "createdAt")
    }

    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<TaskItem> {
        NSFetchRequest<TaskItem>(entityName: "TaskItem")
    }

    var effectiveRepeatKind: String {
        if !repeatKind.isEmpty { return repeatKind }
        switch repeatHours {
        case 1: return "hourly"
        case 2: return "every2h"
        case 4: return "every4h"
        case 8: return "every8h"
        case 12: return "every12h"
        case 24: return "daily"
        case 168: return "weekly"
        default: return ""
        }
    }

    @discardableResult
    convenience init(
        context: NSManagedObjectContext,
        task: String,
        assignee: String? = nil,
        dueDate: Date? = nil,
        category: String = "",
        isCompleted: Bool = false,
        points: Int = 0,
        createdBy: String = "",
        repeatHours: Int = 0,
        repeatKind: String = "",
        completionCount: Int = 0,
        uid: String = "",
        parentUid: String = ""
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "TaskItem", in: context)!
        self.init(entity: entity, insertInto: context)
        self.task = task
        self.assignee = assignee
        self.dueDate = dueDate
        self.category = category
        self.isCompleted = isCompleted
        self.points = Int64(points)
        self.createdBy = createdBy
        self.repeatHours = Int64(repeatHours)
        self.repeatKind = repeatKind
        self.completionCount = Int64(completionCount)
        if !uid.isEmpty { self.uid = uid }
        self.parentUid = parentUid
    }
}
