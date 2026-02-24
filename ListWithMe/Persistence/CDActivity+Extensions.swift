import CoreData

extension CDActivity {
    func toActivity() -> Activity? {
        guard let actionString = action,
              let activityAction = ActivityAction(rawValue: actionString) else {
            return nil
        }

        return Activity(
            id: id ?? UUID(),
            userId: userId ?? "",
            userName: userName ?? "",
            action: activityAction,
            itemText: itemText,
            timestamp: timestamp ?? Date()
        )
    }

    @discardableResult
    static func create(from activity: Activity, list: CDList, context: NSManagedObjectContext) -> CDActivity {
        let cdActivity = CDActivity(context: context)
        cdActivity.id = activity.id
        cdActivity.userId = activity.userId
        cdActivity.userName = activity.userName
        cdActivity.action = activity.action.rawValue
        cdActivity.itemText = activity.itemText
        cdActivity.timestamp = activity.timestamp
        cdActivity.list = list
        return cdActivity
    }

    static func fetchAll(for listId: UUID, context: NSManagedObjectContext) -> [CDActivity] {
        let request: NSFetchRequest<CDActivity> = CDActivity.fetchRequest()
        request.predicate = NSPredicate(format: "list.id == %@", listId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDActivity.timestamp, ascending: false)]
        return (try? context.fetch(request)) ?? []
    }
}
