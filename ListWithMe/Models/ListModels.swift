import Foundation

struct ShoppingList: Identifiable, Hashable {
    let id: UUID
    var name: String
    var createdAt: Date
    var createdBy: String
    var sortOrder: Int
    var items: [ListItem]

    init(id: UUID = UUID(), name: String = "New List", createdBy: String = "", items: [ListItem] = []) {
        self.id = id
        self.name = name
        self.createdAt = Date()
        self.createdBy = createdBy
        self.sortOrder = 0
        self.items = items
    }
}

struct ListItem: Identifiable, Hashable {
    let id: UUID
    var text: String
    var isComplete: Bool
    var completedAt: Date?
    var completedBy: String?
    var createdBy: String
    var createdAt: Date
    var modifiedBy: String
    var modifiedAt: Date
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        text: String = "",
        isComplete: Bool = false,
        createdBy: String = ""
    ) {
        self.id = id
        self.text = text
        self.isComplete = isComplete
        self.createdBy = createdBy
        self.createdAt = Date()
        self.modifiedBy = createdBy
        self.modifiedAt = Date()
        self.sortOrder = 0
    }

    mutating func markComplete(by userId: String) {
        isComplete = true
        completedAt = Date()
        completedBy = userId
        modifiedBy = userId
        modifiedAt = Date()
    }

    mutating func markIncomplete(by userId: String) {
        isComplete = false
        completedAt = nil
        completedBy = nil
        modifiedBy = userId
        modifiedAt = Date()
    }
}

enum ActivityAction: String, Codable {
    case added
    case completed
    case uncompleted
    case edited
    case deleted
    case joined
}

struct Activity: Identifiable {
    let id: UUID
    let userId: String
    let userName: String
    let action: ActivityAction
    let itemText: String?
    let timestamp: Date

    init(userId: String, userName: String, action: ActivityAction, itemText: String? = nil) {
        self.id = UUID()
        self.userId = userId
        self.userName = userName
        self.action = action
        self.itemText = itemText
        self.timestamp = Date()
    }

    init(id: UUID, userId: String, userName: String, action: ActivityAction, itemText: String?, timestamp: Date) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.action = action
        self.itemText = itemText
        self.timestamp = timestamp
    }
}

struct Participant: Identifiable, Hashable {
    let id: String  // CloudKit user ID
    var displayName: String
    var isActive: Bool
    var lastSeen: Date

    init(id: String, displayName: String, isActive: Bool = false, lastSeen: Date = Date()) {
        self.id = id
        self.displayName = displayName
        self.isActive = isActive
        self.lastSeen = lastSeen
    }

    var initials: String {
        let components = displayName.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }
}
