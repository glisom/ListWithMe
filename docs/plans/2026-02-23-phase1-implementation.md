# ListWithMe Phase 1: Foundation & Core Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rewrite ListWithMe as a SwiftUI app with CloudKit sync, delivering a modern collaborative list experience in iMessage.

**Architecture:** MVVM with @Observable ViewModels. Core Data with NSPersistentCloudKitContainer for automatic CloudKit sync. SwiftUI views hosted in Messages extension via UIHostingController.

**Tech Stack:** SwiftUI, Core Data, CloudKit, Messages framework, iOS 17+

---

## Task 1: Update Project Settings

**Files:**
- Modify: `ListWithMe.xcodeproj/project.pbxproj`

**Step 1: Open Xcode and update deployment target**

Open the project in Xcode:
```bash
open /Users/grantisom/Documents/Github/ListWithMe/ListWithMe.xcodeproj
```

In Xcode:
1. Select the project in the navigator
2. Select the "ListWithMe" target
3. Under "General" → "Minimum Deployments", set iOS to 17.0
4. Repeat for "ListWithMe MessagesExtension" target
5. Under "Build Settings" → search "Swift Language Version" → set to "Swift 5" for both targets

**Step 2: Add CloudKit capability**

1. Select "ListWithMe" target → "Signing & Capabilities"
2. Click "+ Capability" → add "iCloud"
3. Check "CloudKit" checkbox
4. Add container: "iCloud.com.isom.ListWithMe"
5. Click "+ Capability" → add "Background Modes"
6. Check "Remote notifications"
7. Repeat CloudKit setup for MessagesExtension target (use same container)

**Step 3: Add App Groups capability**

1. Select "ListWithMe" target → "Signing & Capabilities"
2. Click "+ Capability" → add "App Groups"
3. Add group: "group.com.isom.ListWithMe"
4. Repeat for MessagesExtension target (same group)

**Step 4: Commit**

```bash
git add -A && git commit -m "chore: update project for iOS 17, add CloudKit and App Groups capabilities"
```

---

## Task 2: Create Core Data Model

**Files:**
- Create: `ListWithMe/ListWithMe.xcdatamodeld`

**Step 1: Create the data model in Xcode**

1. In Xcode, right-click "ListWithMe" folder → New File
2. Choose "Data Model" → name it "ListWithMe"
3. Add entity "CDList" with attributes:
   - `id`: UUID
   - `name`: String
   - `createdAt`: Date
   - `createdBy`: String
   - `sortOrder`: Integer 32
4. Add entity "CDListItem" with attributes:
   - `id`: UUID
   - `text`: String
   - `isComplete`: Boolean
   - `completedAt`: Date (optional)
   - `completedBy`: String (optional)
   - `createdBy`: String
   - `createdAt`: Date
   - `modifiedBy`: String
   - `modifiedAt`: Date
   - `sortOrder`: Integer 32
5. Add entity "CDActivity" with attributes:
   - `id`: UUID
   - `userId`: String
   - `userName`: String
   - `action`: String
   - `itemText`: String (optional)
   - `timestamp`: Date
6. Create relationships:
   - CDList: `items` → CDListItem (to-many, cascade delete)
   - CDList: `activities` → CDActivity (to-many, cascade delete)
   - CDListItem: `list` → CDList (to-one, nullify)
   - CDActivity: `list` → CDList (to-one, nullify)

**Step 2: Commit**

```bash
git add -A && git commit -m "feat: add Core Data model for lists, items, and activities"
```

---

## Task 3: Create Persistence Controller

**Files:**
- Create: `ListWithMe/Persistence/PersistenceController.swift`

**Step 1: Create the Persistence directory**

```bash
mkdir -p "/Users/grantisom/Documents/Github/ListWithMe/ListWithMe/Persistence"
```

**Step 2: Write PersistenceController**

Create file `ListWithMe/Persistence/PersistenceController.swift`:

```swift
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
```

**Step 3: Add file to Xcode project**

In Xcode, drag `PersistenceController.swift` into the ListWithMe group. Ensure it's added to both targets (ListWithMe and MessagesExtension).

**Step 4: Commit**

```bash
git add -A && git commit -m "feat: add PersistenceController with CloudKit sync"
```

---

## Task 4: Create Swift Domain Models

**Files:**
- Create: `ListWithMe/Models/ListModels.swift`

**Step 1: Create Models directory**

```bash
mkdir -p "/Users/grantisom/Documents/Github/ListWithMe/ListWithMe/Models"
```

**Step 2: Write domain models**

Create file `ListWithMe/Models/ListModels.swift`:

```swift
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
}
```

**Step 3: Add file to Xcode project**

In Xcode, drag `ListModels.swift` into the ListWithMe/Models group. Add to both targets.

**Step 4: Commit**

```bash
git add -A && git commit -m "feat: add Swift domain models for lists, items, and activities"
```

---

## Task 5: Create Core Data Extensions

**Files:**
- Create: `ListWithMe/Persistence/CDList+Extensions.swift`
- Create: `ListWithMe/Persistence/CDListItem+Extensions.swift`

**Step 1: Write CDList extensions**

Create file `ListWithMe/Persistence/CDList+Extensions.swift`:

```swift
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
```

**Step 2: Write CDListItem extensions**

Create file `ListWithMe/Persistence/CDListItem+Extensions.swift`:

```swift
import CoreData

extension CDListItem {
    func toListItem() -> ListItem {
        var item = ListItem(
            id: id ?? UUID(),
            text: text ?? "",
            isComplete: isComplete,
            createdBy: createdBy ?? ""
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
```

**Step 3: Add files to Xcode project**

In Xcode, drag both files into the ListWithMe/Persistence group. Add to both targets.

**Step 4: Commit**

```bash
git add -A && git commit -m "feat: add Core Data model extensions for conversion"
```

---

## Task 6: Create ListService

**Files:**
- Create: `ListWithMe/Services/ListService.swift`

**Step 1: Create Services directory**

```bash
mkdir -p "/Users/grantisom/Documents/Github/ListWithMe/ListWithMe/Services"
```

**Step 2: Write ListService**

Create file `ListWithMe/Services/ListService.swift`:

```swift
import Foundation
import CoreData
import Observation

@Observable
final class ListService {
    private let persistence: PersistenceController
    private(set) var lists: [ShoppingList] = []

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
    }

    func updateItem(_ item: ListItem, in listId: UUID) {
        guard let cdItem = CDListItem.fetch(id: item.id, context: context) else { return }
        cdItem.update(from: item)
        saveContext()
        fetchLists()
    }

    func deleteItem(_ item: ListItem) {
        guard let cdItem = CDListItem.fetch(id: item.id, context: context) else { return }
        context.delete(cdItem)
        saveContext()
        fetchLists()
    }

    func toggleItemComplete(_ item: ListItem, in listId: UUID, by userId: String) {
        var updatedItem = item
        if item.isComplete {
            updatedItem.markIncomplete(by: userId)
        } else {
            updatedItem.markComplete(by: userId)
        }
        updateItem(updatedItem, in: listId)
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
```

**Step 3: Add file to Xcode project**

In Xcode, drag `ListService.swift` into the ListWithMe/Services group. Add to both targets.

**Step 4: Commit**

```bash
git add -A && git commit -m "feat: add ListService for CRUD operations"
```

---

## Task 7: Create ListItemRow View

**Files:**
- Create: `ListWithMe/Views/ListItemRow.swift`

**Step 1: Create Views directory**

```bash
mkdir -p "/Users/grantisom/Documents/Github/ListWithMe/ListWithMe/Views"
```

**Step 2: Write ListItemRow**

Create file `ListWithMe/Views/ListItemRow.swift`:

```swift
import SwiftUI

struct ListItemRow: View {
    let item: ListItem
    let onToggleComplete: () -> Void
    let onTextChange: (String) -> Void
    let onDelete: () -> Void

    @State private var text: String
    @FocusState private var isFocused: Bool

    init(
        item: ListItem,
        onToggleComplete: @escaping () -> Void,
        onTextChange: @escaping (String) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.item = item
        self.onToggleComplete = onToggleComplete
        self.onTextChange = onTextChange
        self.onDelete = onDelete
        self._text = State(initialValue: item.text)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleComplete) {
                Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isComplete ? .green : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                TextField("Item", text: $text)
                    .strikethrough(item.isComplete)
                    .foregroundStyle(item.isComplete ? .secondary : .primary)
                    .focused($isFocused)
                    .onChange(of: text) { _, newValue in
                        onTextChange(newValue)
                    }
                    .submitLabel(.done)

                if let modifiedBy = item.modifiedBy, !modifiedBy.isEmpty {
                    Text(modifiedByLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: onToggleComplete) {
                Label(
                    item.isComplete ? "Undo" : "Done",
                    systemImage: item.isComplete ? "arrow.uturn.backward" : "checkmark"
                )
            }
            .tint(.green)
        }
    }

    private var modifiedByLabel: String {
        // In a real app, we'd resolve the UUID to a display name
        // For now, show a shortened version
        let shortId = String(item.modifiedBy.prefix(4))
        return "Edited by \(shortId)..."
    }
}

#Preview {
    List {
        ListItemRow(
            item: ListItem(text: "Milk", createdBy: "user1"),
            onToggleComplete: {},
            onTextChange: { _ in },
            onDelete: {}
        )
        ListItemRow(
            item: {
                var item = ListItem(text: "Eggs", createdBy: "user1")
                item.markComplete(by: "user2")
                return item
            }(),
            onToggleComplete: {},
            onTextChange: { _ in },
            onDelete: {}
        )
    }
}
```

**Step 3: Add file to Xcode project**

In Xcode, drag `ListItemRow.swift` into the ListWithMe/Views group. Add to both targets.

**Step 4: Commit**

```bash
git add -A && git commit -m "feat: add ListItemRow SwiftUI view with animations"
```

---

## Task 8: Create ListDetailView

**Files:**
- Create: `ListWithMe/Views/ListDetailView.swift`

**Step 1: Write ListDetailView**

Create file `ListWithMe/Views/ListDetailView.swift`:

```swift
import SwiftUI

struct ListDetailView: View {
    let listId: UUID
    let userId: String
    let onSendList: (ShoppingList) -> Void

    @State private var listService: ListService
    @State private var newItemText = ""
    @FocusState private var isAddingItem: Bool

    init(
        listId: UUID,
        userId: String,
        listService: ListService = ListService(),
        onSendList: @escaping (ShoppingList) -> Void
    ) {
        self.listId = listId
        self.userId = userId
        self._listService = State(initialValue: listService)
        self.onSendList = onSendList
    }

    private var list: ShoppingList? {
        listService.lists.first { $0.id == listId }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let list = list {
                // Header
                headerView(for: list)

                // Items List
                List {
                    ForEach(list.items) { item in
                        ListItemRow(
                            item: item,
                            onToggleComplete: {
                                withAnimation(.spring(response: 0.3)) {
                                    listService.toggleItemComplete(item, in: listId, by: userId)
                                }
                            },
                            onTextChange: { newText in
                                var updated = item
                                updated.text = newText
                                updated.modifiedBy = userId
                                updated.modifiedAt = Date()
                                listService.updateItem(updated, in: listId)
                            },
                            onDelete: {
                                withAnimation {
                                    listService.deleteItem(item)
                                }
                            }
                        )
                    }

                    // Add item row
                    addItemRow
                }
                .listStyle(.plain)

                // Send button
                sendButton(for: list)
            } else {
                ContentUnavailableView(
                    "List Not Found",
                    systemImage: "list.bullet",
                    description: Text("This list may have been deleted.")
                )
            }
        }
    }

    private func headerView(for list: ShoppingList) -> some View {
        HStack {
            Text(list.name)
                .font(.headline)

            Spacer()

            Text("\(list.items.filter { $0.isComplete }.count)/\(list.items.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var addItemRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)

            TextField("Add item...", text: $newItemText)
                .focused($isAddingItem)
                .submitLabel(.done)
                .onSubmit(addItem)
        }
        .padding(.vertical, 4)
    }

    private func sendButton(for list: ShoppingList) -> some View {
        Button(action: { onSendList(list) }) {
            Label("Send List", systemImage: "paperplane.fill")
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.borderedProminent)
        .padding()
    }

    private func addItem() {
        guard !newItemText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        withAnimation {
            listService.addItem(to: listId, text: newItemText, createdBy: userId)
        }
        newItemText = ""
        isAddingItem = true
    }
}

#Preview {
    let service = ListService(persistence: .preview)
    let previewList = service.lists.first!

    return ListDetailView(
        listId: previewList.id,
        userId: "preview-user",
        listService: service,
        onSendList: { _ in }
    )
}
```

**Step 2: Add file to Xcode project**

In Xcode, drag `ListDetailView.swift` into the ListWithMe/Views group. Add to both targets.

**Step 3: Commit**

```bash
git add -A && git commit -m "feat: add ListDetailView with item management"
```

---

## Task 9: Create ListsView (Grid of Lists)

**Files:**
- Create: `ListWithMe/Views/ListsView.swift`

**Step 1: Write ListsView**

Create file `ListWithMe/Views/ListsView.swift`:

```swift
import SwiftUI

struct ListsView: View {
    let userId: String
    let onSelectList: (ShoppingList) -> Void
    let onCreateList: () -> Void

    @State private var listService: ListService

    init(
        userId: String,
        listService: ListService = ListService(),
        onSelectList: @escaping (ShoppingList) -> Void,
        onCreateList: @escaping () -> Void
    ) {
        self.userId = userId
        self._listService = State(initialValue: listService)
        self.onSelectList = onSelectList
        self.onCreateList = onCreateList
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Your Lists")
                    .font(.headline)

                Spacer()

                Button(action: onCreateList) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
            .padding()
            .background(.ultraThinMaterial)

            if listService.lists.isEmpty {
                ContentUnavailableView(
                    "No Lists Yet",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Tap + to create your first list")
                )
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ],
                        spacing: 12
                    ) {
                        ForEach(listService.lists) { list in
                            ListCard(list: list)
                                .onTapGesture {
                                    onSelectList(list)
                                }
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

struct ListCard: View {
    let list: ShoppingList

    private var completionRatio: Double {
        guard !list.items.isEmpty else { return 0 }
        return Double(list.items.filter(\.isComplete).count) / Double(list.items.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(list.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text("\(list.items.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Preview of items
            VStack(alignment: .leading, spacing: 2) {
                ForEach(list.items.prefix(3)) { item in
                    HStack(spacing: 4) {
                        Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                            .font(.caption2)
                            .foregroundStyle(item.isComplete ? .green : .secondary)

                        Text(item.text)
                            .font(.caption)
                            .lineLimit(1)
                            .strikethrough(item.isComplete)
                            .foregroundStyle(item.isComplete ? .secondary : .primary)
                    }
                }

                if list.items.count > 3 {
                    Text("+\(list.items.count - 3) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.secondary.opacity(0.2))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(.green)
                        .frame(width: geo.size.width * completionRatio)
                }
            }
            .frame(height: 4)
        }
        .padding()
        .frame(height: 140)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ListsView(
        userId: "preview-user",
        listService: ListService(persistence: .preview),
        onSelectList: { _ in },
        onCreateList: {}
    )
}
```

**Step 2: Add file to Xcode project**

In Xcode, drag `ListsView.swift` into the ListWithMe/Views group. Add to both targets.

**Step 3: Commit**

```bash
git add -A && git commit -m "feat: add ListsView with grid layout"
```

---

## Task 10: Create New List Sheet

**Files:**
- Create: `ListWithMe/Views/NewListSheet.swift`

**Step 1: Write NewListSheet**

Create file `ListWithMe/Views/NewListSheet.swift`:

```swift
import SwiftUI

struct NewListSheet: View {
    @Environment(\.dismiss) private var dismiss

    let userId: String
    let onCreate: (ShoppingList) -> Void

    @State private var listService: ListService
    @State private var listName = ""
    @FocusState private var isNameFocused: Bool

    init(
        userId: String,
        listService: ListService = ListService(),
        onCreate: @escaping (ShoppingList) -> Void
    ) {
        self.userId = userId
        self._listService = State(initialValue: listService)
        self.onCreate = onCreate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("List Name", text: $listName)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                        .onSubmit(createList)
                } header: {
                    Text("Name your list")
                }
            }
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createList()
                    }
                    .disabled(listName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
        .presentationDetents([.height(200)])
    }

    private func createList() {
        let trimmedName = listName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let newList = listService.createList(name: trimmedName, createdBy: userId)
        onCreate(newList)
        dismiss()
    }
}

#Preview {
    NewListSheet(
        userId: "preview-user",
        listService: ListService(persistence: .preview),
        onCreate: { _ in }
    )
}
```

**Step 2: Add file to Xcode project**

In Xcode, drag `NewListSheet.swift` into the ListWithMe/Views group. Add to both targets.

**Step 3: Commit**

```bash
git add -A && git commit -m "feat: add NewListSheet for creating lists"
```

---

## Task 11: Create SwiftUI Messages Extension View

**Files:**
- Create: `ListWithMe MessagesExtension/MessagesView.swift`

**Step 1: Write MessagesView**

Create file `ListWithMe MessagesExtension/MessagesView.swift`:

```swift
import SwiftUI
import Messages

struct MessagesView: View {
    let conversation: MSConversation?
    let presentationStyle: MSMessagesAppPresentationStyle
    let onSendMessage: (MSMessage) -> Void
    let onRequestExpanded: () -> Void

    @State private var listService = ListService()
    @State private var selectedList: ShoppingList?
    @State private var showNewListSheet = false

    private var userId: String {
        conversation?.localParticipantIdentifier.uuidString ?? "unknown"
    }

    var body: some View {
        Group {
            if presentationStyle == .compact {
                compactView
            } else {
                expandedView
            }
        }
        .sheet(isPresented: $showNewListSheet) {
            NewListSheet(
                userId: userId,
                listService: listService
            ) { newList in
                selectedList = newList
            }
        }
    }

    private var compactView: some View {
        ListsView(
            userId: userId,
            listService: listService,
            onSelectList: { list in
                selectedList = list
                onRequestExpanded()
            },
            onCreateList: {
                showNewListSheet = true
                onRequestExpanded()
            }
        )
    }

    private var expandedView: some View {
        Group {
            if let list = selectedList {
                ListDetailView(
                    listId: list.id,
                    userId: userId,
                    listService: listService,
                    onSendList: { list in
                        let message = composeMessage(for: list)
                        onSendMessage(message)
                    }
                )
            } else {
                ListsView(
                    userId: userId,
                    listService: listService,
                    onSelectList: { list in
                        selectedList = list
                    },
                    onCreateList: {
                        showNewListSheet = true
                    }
                )
            }
        }
    }

    private func composeMessage(for list: ShoppingList) -> MSMessage {
        let message = MSMessage(session: conversation?.selectedMessage?.session ?? MSSession())

        let layout = MSMessageTemplateLayout()
        layout.caption = list.name
        layout.subcaption = "\(list.items.count) items"
        layout.trailingSubcaption = "\(list.items.filter(\.isComplete).count) done"

        // Store list ID in URL for retrieval
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "listId", value: list.id.uuidString)
        ]

        message.url = components.url
        message.layout = layout

        return message
    }
}

#Preview {
    MessagesView(
        conversation: nil,
        presentationStyle: .expanded,
        onSendMessage: { _ in },
        onRequestExpanded: {}
    )
}
```

**Step 2: Add file to Xcode project**

In Xcode, drag `MessagesView.swift` into the "ListWithMe MessagesExtension" group.

**Step 3: Commit**

```bash
git add -A && git commit -m "feat: add SwiftUI MessagesView for extension"
```

---

## Task 12: Update MessagesViewController for SwiftUI

**Files:**
- Modify: `ListWithMe MessagesExtension/MessagesViewController.swift`

**Step 1: Rewrite MessagesViewController**

Replace entire contents of `ListWithMe MessagesExtension/MessagesViewController.swift`:

```swift
import UIKit
import SwiftUI
import Messages

class MessagesViewController: MSMessagesAppViewController {

    private var hostingController: UIHostingController<MessagesView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupHostingController()
    }

    private func setupHostingController() {
        let messagesView = MessagesView(
            conversation: activeConversation,
            presentationStyle: presentationStyle,
            onSendMessage: { [weak self] message in
                self?.sendMessage(message)
            },
            onRequestExpanded: { [weak self] in
                self?.requestPresentationStyle(.expanded)
            }
        )

        let hostingController = UIHostingController(rootView: messagesView)
        addChild(hostingController)
        view.addSubview(hostingController.view)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        hostingController.didMove(toParent: self)
        self.hostingController = hostingController
    }

    private func updateHostingController() {
        hostingController?.rootView = MessagesView(
            conversation: activeConversation,
            presentationStyle: presentationStyle,
            onSendMessage: { [weak self] message in
                self?.sendMessage(message)
            },
            onRequestExpanded: { [weak self] in
                self?.requestPresentationStyle(.expanded)
            }
        )
    }

    private func sendMessage(_ message: MSMessage) {
        activeConversation?.insert(message) { error in
            if let error = error {
                print("Failed to send message: \(error)")
            }
        }
        requestPresentationStyle(.compact)
    }

    // MARK: - Conversation Handling

    override func willBecomeActive(with conversation: MSConversation) {
        updateHostingController()
    }

    override func didBecomeActive(with conversation: MSConversation) {
        // Handle incoming message if present
        if let message = conversation.selectedMessage,
           let url = message.url,
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let listIdString = components.queryItems?.first(where: { $0.name == "listId" })?.value,
           let listId = UUID(uuidString: listIdString) {
            // List ID is now stored in CloudKit, the SwiftUI view will fetch it
            print("Opening list: \(listId)")
        }
        updateHostingController()
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        updateHostingController()
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        updateHostingController()
    }
}
```

**Step 2: Commit**

```bash
git add -A && git commit -m "refactor: update MessagesViewController to host SwiftUI views"
```

---

## Task 13: Remove Old UIKit Files

**Files:**
- Delete: `ListWithMe MessagesExtension/ListItem.swift`
- Delete: `ListWithMe MessagesExtension/ListItemCell.swift`
- Delete: `ListWithMe MessagesExtension/Base.lproj/MainInterface.storyboard`

**Step 1: Remove old files in Xcode**

1. In Xcode, select `ListItem.swift` in the MessagesExtension group
2. Press Delete → Move to Trash
3. Repeat for `ListItemCell.swift`
4. Repeat for `MainInterface.storyboard`

**Step 2: Update Info.plist to remove storyboard reference**

Edit `ListWithMe MessagesExtension/Info.plist`:

Change:
```xml
<key>NSExtensionMainStoryboard</key>
<string>MainInterface</string>
```

To:
```xml
<key>NSExtensionPrincipalClass</key>
<string>$(PRODUCT_MODULE_NAME).MessagesViewController</string>
```

**Step 3: Commit**

```bash
git add -A && git commit -m "chore: remove legacy UIKit files and storyboard"
```

---

## Task 14: Create Container App Entry Point

**Files:**
- Create: `ListWithMe/ListWithMeApp.swift`
- Create: `ListWithMe/ContentView.swift`

**Step 1: Write app entry point**

Create file `ListWithMe/ListWithMeApp.swift`:

```swift
import SwiftUI

@main
struct ListWithMeApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**Step 2: Write ContentView**

Create file `ListWithMe/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    @State private var listService = ListService()
    @State private var selectedList: ShoppingList?
    @State private var showNewListSheet = false

    private let userId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"

    var body: some View {
        NavigationStack {
            ListsView(
                userId: userId,
                listService: listService,
                onSelectList: { list in
                    selectedList = list
                },
                onCreateList: {
                    showNewListSheet = true
                }
            )
            .navigationTitle("ListWithMe")
            .navigationDestination(item: $selectedList) { list in
                ListDetailView(
                    listId: list.id,
                    userId: userId,
                    listService: listService,
                    onSendList: { _ in
                        // In standalone app, could share via share sheet
                    }
                )
                .navigationTitle(list.name)
            }
            .sheet(isPresented: $showNewListSheet) {
                NewListSheet(
                    userId: userId,
                    listService: listService
                ) { newList in
                    selectedList = newList
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
```

**Step 3: Add files to Xcode project**

In Xcode, drag both files into the ListWithMe group. Only add to the ListWithMe target (not MessagesExtension).

**Step 4: Remove old AppDelegate/SceneDelegate if present**

Check for and remove any `AppDelegate.swift` or `SceneDelegate.swift` files. Update Info.plist to remove UIMainStoryboardFile and UISceneConfigurations if present.

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: add SwiftUI app entry point for container app"
```

---

## Task 15: Build and Test

**Step 1: Build the project**

In Xcode:
1. Select a simulator (iPhone 15 Pro or similar)
2. Press Cmd+B to build
3. Fix any compilation errors

**Step 2: Run the container app**

1. Select the "ListWithMe" scheme
2. Press Cmd+R to run
3. Verify the lists view appears
4. Create a new list
5. Add items
6. Toggle completion

**Step 3: Run the Messages extension**

1. Select the "ListWithMe MessagesExtension" scheme
2. Press Cmd+R to run
3. Choose Messages as the host app
4. Open a conversation
5. Tap the Apps button, find ListWithMe
6. Create and send a list

**Step 4: Commit final state**

```bash
git add -A && git commit -m "feat: complete Phase 1 foundation implementation"
```

---

## Summary

Phase 1 delivers:
- [x] SwiftUI app structure with Messages extension
- [x] Core Data + CloudKit setup
- [x] Basic list CRUD
- [x] Item management (add, edit, complete, delete)
- [x] Messages integration (send/receive)
- [x] Who edited indicators on items

**Next Phase:** Add CloudKit sharing for true real-time collaboration, activity feed, and presence indicators.
