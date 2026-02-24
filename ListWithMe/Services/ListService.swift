import Foundation
import CoreData
import Observation

@Observable
final class ListService {
    private let persistence: PersistenceController
    private(set) var lists: [ShoppingList] = []

    var currentUserId: String = ""
    var currentUserName: String = ""

    var context: NSManagedObjectContext {
        persistence.viewContext
    }

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
        fetchLists()
    }

    // MARK: - List Operations

    func fetchLists() {
        let request: NSFetchRequest<CDList> = CDList.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDList.createdAt, ascending: false)]

        do {
            let cdLists = try context.fetch(request)
            lists = cdLists.map { $0.toShoppingList() }
        } catch {
            print("Failed to fetch lists: \(error)")
        }
    }

    func createList(name: String, createdBy: String) -> ShoppingList {
        let list = ShoppingList(name: name, createdBy: createdBy)
        let cdList = CDList.create(from: list, context: context)
        saveContext()
        fetchLists()
        return cdList.toShoppingList()
    }

    func updateList(_ list: ShoppingList) {
        guard let cdList = CDList.fetch(id: list.id, context: context) else { return }
        cdList.update(from: list, context: context)
        saveContext()
        fetchLists()
    }

    func deleteList(_ list: ShoppingList) {
        guard let cdList = CDList.fetch(id: list.id, context: context) else { return }
        context.delete(cdList)
        saveContext()
        fetchLists()
    }

    func getList(id: UUID) -> ShoppingList? {
        guard let cdList = CDList.fetch(id: id, context: context) else { return nil }
        return cdList.toShoppingList()
    }

    // MARK: - Item Operations

    func addItem(to listId: UUID, text: String, createdBy: String) {
        guard let cdList = CDList.fetch(id: listId, context: context) else { return }

        let item = ListItem(text: text, createdBy: createdBy)
        _ = CDListItem.create(from: item, list: cdList, context: context)
        saveContext()
        fetchLists()
        recordActivity(for: listId, action: .added, itemText: text)
    }

    func updateItem(_ item: ListItem, in listId: UUID) {
        guard let cdItem = CDListItem.fetch(id: item.id, context: context) else { return }
        cdItem.update(from: item)
        saveContext()
        fetchLists()
    }

    func deleteItem(_ item: ListItem, from listId: UUID) {
        recordActivity(for: listId, action: .deleted, itemText: item.text)
        guard let cdItem = CDListItem.fetch(id: item.id, context: context) else { return }
        context.delete(cdItem)
        saveContext()
        fetchLists()
    }

    func toggleItemComplete(_ item: ListItem, in listId: UUID, by userId: String) {
        var updatedItem = item
        if item.isComplete {
            updatedItem.markIncomplete(by: userId)
            recordActivity(for: listId, action: .uncompleted, itemText: item.text)
        } else {
            updatedItem.markComplete(by: userId)
            recordActivity(for: listId, action: .completed, itemText: item.text)
        }
        updateItem(updatedItem, in: listId)
    }

    // MARK: - Activity Operations

    func recordActivity(for listId: UUID, action: ActivityAction, itemText: String? = nil) {
        guard let cdList = CDList.fetch(id: listId, context: context) else { return }

        let activity = Activity(
            userId: currentUserId,
            userName: currentUserName,
            action: action,
            itemText: itemText
        )
        _ = CDActivity.create(from: activity, list: cdList, context: context)
        saveContext()
    }

    func getActivities(for listId: UUID) -> [Activity] {
        return CDActivity.fetchAll(for: listId, context: context).compactMap { $0.toActivity() }
    }

    // MARK: - Helpers

    private func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
}
