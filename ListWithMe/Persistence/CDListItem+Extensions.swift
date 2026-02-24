import CoreData

extension CDListItem {
    func toListItem() -> ListItem {
        var item = ListItem(
            id: id ?? UUID(),
            text: text ?? "",
            isComplete: isComplete,
            createdBy: createdBy ?? "",
            category: category,
            quantity: Int(quantity),
            note: note,
            dueDate: dueDate,
            priority: Priority(rawValue: Int(priority)) ?? .none
        )
        item.completedAt = completedAt
        item.completedBy = completedBy
        item.createdAt = createdAt ?? Date()
        item.modifiedBy = modifiedBy ?? ""
        item.modifiedAt = modifiedAt ?? Date()
        item.sortOrder = Int(sortOrder)
        return item
    }

    func update(from item: ListItem) {
        self.text = item.text
        self.isComplete = item.isComplete
        self.completedAt = item.completedAt
        self.completedBy = item.completedBy
        self.modifiedBy = item.modifiedBy
        self.modifiedAt = item.modifiedAt
        self.sortOrder = Int32(item.sortOrder)
        self.category = item.category
        self.quantity = Int32(item.quantity)
        self.note = item.note
        self.dueDate = item.dueDate
        self.priority = Int16(item.priority.rawValue)
    }

    static func create(from item: ListItem, list: CDList, context: NSManagedObjectContext) -> CDListItem {
        let cdItem = CDListItem(context: context)
        cdItem.id = item.id
        cdItem.text = item.text
        cdItem.isComplete = item.isComplete
        cdItem.completedAt = item.completedAt
        cdItem.completedBy = item.completedBy
        cdItem.createdBy = item.createdBy
        cdItem.createdAt = item.createdAt
        cdItem.modifiedBy = item.modifiedBy
        cdItem.modifiedAt = item.modifiedAt
        cdItem.sortOrder = Int32(item.sortOrder)
        cdItem.category = item.category
        cdItem.quantity = Int32(item.quantity)
        cdItem.note = item.note
        cdItem.dueDate = item.dueDate
        cdItem.priority = Int16(item.priority.rawValue)
        cdItem.list = list
        return cdItem
    }

    static func fetch(id: UUID, context: NSManagedObjectContext) -> CDListItem? {
        let request: NSFetchRequest<CDListItem> = CDListItem.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
