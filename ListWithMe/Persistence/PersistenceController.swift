import CoreData
import CloudKit

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "ListWithMe")

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("No persistent store description found")
        }

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Use App Group for shared container between app and extension
            let storeURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: "group.com.isom.ListWithMe")!
                .appendingPathComponent("ListWithMe.sqlite")
            description.url = storeURL
        }

        // CloudKit configuration
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.isom.ListWithMe"
        )

        // Enable remote change notifications
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Persistent store error: \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Preview Helper

    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.viewContext

        // Create sample data
        let list = CDList(context: context)
        list.id = UUID()
        list.name = "Groceries"
        list.createdAt = Date()
        list.createdBy = "preview-user"
        list.sortOrder = 0

        let items = ["Milk", "Eggs", "Bread"]
        for (index, text) in items.enumerated() {
            let item = CDListItem(context: context)
            item.id = UUID()
            item.text = text
            item.isComplete = index == 0
            item.createdBy = "preview-user"
            item.createdAt = Date()
            item.modifiedBy = "preview-user"
            item.modifiedAt = Date()
            item.sortOrder = Int32(index)
            item.list = list
        }

        try? context.save()
        return controller
    }()
}
