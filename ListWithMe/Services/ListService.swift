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

    func duplicateList(_ list: ShoppingList, createdBy: String) -> ShoppingList {
        let newList = ShoppingList(name: "\(list.name) (Copy)", createdBy: createdBy)
        let cdList = CDList.create(from: newList, context: context)

        // Copy all items (without completion status)
        for item in list.items {
            var newItem = ListItem(
                text: item.text,
                createdBy: createdBy,
                category: item.category,
                quantity: item.quantity,
                note: item.note,
                dueDate: item.dueDate,
                priority: item.priority
            )
            newItem.sortOrder = item.sortOrder
            _ = CDListItem.create(from: newItem, list: cdList, context: context)
        }

        saveContext()
        fetchLists()
        return cdList.toShoppingList()
    }

    func getList(id: UUID) -> ShoppingList? {
        guard let cdList = CDList.fetch(id: id, context: context) else { return nil }
        return cdList.toShoppingList()
    }

    // MARK: - Item Operations

    func addItem(to listId: UUID, text: String, createdBy: String) {
        guard let cdList = CDList.fetch(id: listId, context: context) else { return }

        let parsed = parseItemInput(text)
        let item = ListItem(text: parsed.text, createdBy: createdBy, quantity: parsed.quantity)
        _ = CDListItem.create(from: item, list: cdList, context: context)
        saveContext()
        fetchLists()
        recordActivity(for: listId, action: .added, itemText: parsed.text)
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

    func clearCompleted(from listId: UUID) {
        guard let cdList = CDList.fetch(id: listId, context: context) else { return }

        let completedItems = (cdList.items as? Set<CDListItem> ?? [])
            .filter { $0.isComplete }

        let count = completedItems.count
        for item in completedItems {
            context.delete(item)
        }

        saveContext()
        fetchLists()
        if count > 0 {
            recordActivity(for: listId, action: .deleted, itemText: "\(count) completed items")
        }
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

    func reorderItems(in listId: UUID, from source: IndexSet, to destination: Int) {
        guard let cdList = CDList.fetch(id: listId, context: context) else { return }

        // Get current items sorted by sortOrder
        var items = (cdList.items as? Set<CDListItem> ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }

        // Perform the move
        items.move(fromOffsets: source, toOffset: destination)

        // Update sortOrder for all items
        for (index, item) in items.enumerated() {
            item.sortOrder = Int32(index)
        }

        saveContext()
        fetchLists()
    }

    func deleteItems(_ itemIds: Set<UUID>, from listId: UUID) {
        for itemId in itemIds {
            if let cdItem = CDListItem.fetch(id: itemId, context: context) {
                context.delete(cdItem)
            }
        }
        saveContext()
        fetchLists()
        recordActivity(for: listId, action: .deleted, itemText: "\(itemIds.count) items")
    }

    func completeItems(_ itemIds: Set<UUID>, in listId: UUID, by userId: String) {
        for itemId in itemIds {
            if let cdItem = CDListItem.fetch(id: itemId, context: context) {
                cdItem.isComplete = true
                cdItem.completedAt = Date()
                cdItem.completedBy = userId
                cdItem.modifiedBy = userId
                cdItem.modifiedAt = Date()
            }
        }
        saveContext()
        fetchLists()
        recordActivity(for: listId, action: .completed, itemText: "\(itemIds.count) items")
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

    // MARK: - Sorting

    func sortedItems(_ items: [ListItem], by option: SortOption) -> [ListItem] {
        switch option {
        case .manual:
            return items.sorted { $0.sortOrder < $1.sortOrder }
        case .alphabetical:
            return items.sorted { $0.text.localizedCaseInsensitiveCompare($1.text) == .orderedAscending }
        case .alphabeticalReversed:
            return items.sorted { $0.text.localizedCaseInsensitiveCompare($1.text) == .orderedDescending }
        case .newestFirst:
            return items.sorted { $0.createdAt > $1.createdAt }
        case .oldestFirst:
            return items.sorted { $0.createdAt < $1.createdAt }
        case .incompleteFirst:
            return items.sorted { !$0.isComplete && $1.isComplete }
        case .completeFirst:
            return items.sorted { $0.isComplete && !$1.isComplete }
        case .byCategory:
            return items.sorted {
                let cat0 = $0.category ?? ""
                let cat1 = $1.category ?? ""
                if cat0 == cat1 {
                    return $0.sortOrder < $1.sortOrder
                }
                return cat0 < cat1
            }
        case .byPriority:
            return items.sorted { $0.priority.rawValue > $1.priority.rawValue }
        case .byDueDate:
            return items.sorted {
                switch ($0.dueDate, $1.dueDate) {
                case (nil, nil): return $0.sortOrder < $1.sortOrder
                case (nil, _): return false
                case (_, nil): return true
                case (let d0?, let d1?): return d0 < d1
                }
            }
        }
    }

    // MARK: - Input Parsing

    struct ParsedItem {
        let text: String
        let quantity: Int
    }

    func parseItemInput(_ input: String) -> ParsedItem {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        // Pattern: "3 apples" or "3x apples" or "3× apples"
        let patterns = [
            "^(\\d+)\\s*[x×]?\\s+(.+)$",  // "3 apples" or "3x apples"
            "^(.+)\\s+[x×](\\d+)$"         // "apples x3"
        ]

        for (index, pattern) in patterns.enumerated() {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {

                if index == 0 {
                    // First pattern: quantity first
                    if let qtyRange = Range(match.range(at: 1), in: trimmed),
                       let textRange = Range(match.range(at: 2), in: trimmed),
                       let qty = Int(trimmed[qtyRange]) {
                        return ParsedItem(text: String(trimmed[textRange]), quantity: min(qty, 99))
                    }
                } else {
                    // Second pattern: quantity last
                    if let textRange = Range(match.range(at: 1), in: trimmed),
                       let qtyRange = Range(match.range(at: 2), in: trimmed),
                       let qty = Int(trimmed[qtyRange]) {
                        return ParsedItem(text: String(trimmed[textRange]).trimmingCharacters(in: .whitespaces), quantity: min(qty, 99))
                    }
                }
            }
        }

        return ParsedItem(text: trimmed, quantity: 1)
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
