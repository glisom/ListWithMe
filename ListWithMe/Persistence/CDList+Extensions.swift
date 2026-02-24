import CoreData

extension CDList {
    var itemsArray: [CDListItem] {
        let set = items as? Set<CDListItem> ?? []
        return set.sorted { $0.sortOrder < $1.sortOrder }
    }

    func toShoppingList() -> ShoppingList {
        ShoppingList(
            id: id ?? UUID(),
            name: name ?? "Untitled",
            createdBy: createdBy ?? "",
            items: itemsArray.map { $0.toListItem() }
        )
    }

    func update(from list: ShoppingList, context: NSManagedObjectContext) {
        self.name = list.name
        self.sortOrder = Int32(list.sortOrder)
    }

    static func create(from list: ShoppingList, context: NSManagedObjectContext) -> CDList {
        let cdList = CDList(context: context)
        cdList.id = list.id
        cdList.name = list.name
        cdList.createdAt = list.createdAt
        cdList.createdBy = list.createdBy
        cdList.sortOrder = Int32(list.sortOrder)
        return cdList
    }

    static func fetch(id: UUID, context: NSManagedObjectContext) -> CDList? {
        let request: NSFetchRequest<CDList> = CDList.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
