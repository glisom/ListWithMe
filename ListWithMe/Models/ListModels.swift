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
    var category: String?
    var quantity: Int
    var note: String?
    var dueDate: Date?
    var priority: Priority

    init(
        id: UUID = UUID(),
        text: String = "",
        isComplete: Bool = false,
        createdBy: String = "",
        category: String? = nil,
        quantity: Int = 1,
        note: String? = nil,
        dueDate: Date? = nil,
        priority: Priority = .none
    ) {
        self.id = id
        self.text = text
        self.isComplete = isComplete
        self.createdBy = createdBy
        self.createdAt = Date()
        self.modifiedBy = createdBy
        self.modifiedAt = Date()
        self.sortOrder = 0
        self.category = category
        self.quantity = quantity
        self.note = note
        self.dueDate = dueDate
        self.priority = priority
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

enum Priority: Int, CaseIterable, Identifiable, Codable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var icon: String {
        switch self {
        case .none: return "minus"
        case .low: return "exclamationmark"
        case .medium: return "exclamationmark.2"
        case .high: return "exclamationmark.3"
        }
    }
}

enum SortOption: String, CaseIterable, Identifiable {
    case manual = "Manual"
    case alphabetical = "A-Z"
    case alphabeticalReversed = "Z-A"
    case newestFirst = "Newest First"
    case oldestFirst = "Oldest First"
    case incompleteFirst = "Incomplete First"
    case completeFirst = "Complete First"
    case byCategory = "By Category"
    case byPriority = "By Priority"
    case byDueDate = "By Due Date"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .manual: return "hand.draw"
        case .alphabetical: return "textformat.abc"
        case .alphabeticalReversed: return "textformat.abc"
        case .newestFirst: return "clock"
        case .oldestFirst: return "clock.arrow.circlepath"
        case .incompleteFirst: return "circle"
        case .completeFirst: return "checkmark.circle"
        case .byCategory: return "folder"
        case .byPriority: return "exclamationmark.triangle"
        case .byDueDate: return "calendar"
        }
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
