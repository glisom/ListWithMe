# Phase 4: Item Details Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add quantities, notes, due dates, and priority levels to shopping list items for richer item management.

**Architecture:** Add new attributes to Core Data model and Swift models, create Priority enum, build ItemDetailView for editing all item properties, update ListItemRow to show indicators.

**Tech Stack:** SwiftUI, Core Data, DatePicker

---

## Task 1: Add New Attributes to Core Data Model

**Files:**
- Modify: `ListWithMe/ListWithMe.xcdatamodeld/ListWithMe.xcdatamodel/contents`

**Step 1: Add quantity, note, dueDate, and priority attributes to CDListItem**

Add these attributes to the CDListItem entity:
- `quantity` - Integer 32, optional, default 1
- `note` - String, optional
- `dueDate` - Date, optional
- `priority` - Integer 16, optional, default 0 (0=none, 1=low, 2=medium, 3=high)

**Step 2: Build to verify**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ListWithMe/ListWithMe.xcdatamodeld
git commit -m "feat: add quantity, note, dueDate, priority to Core Data model"
```

---

## Task 2: Create Priority Enum

**Files:**
- Modify: `ListWithMe/Models/ListModels.swift`

**Step 1: Add Priority enum**

```swift
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

    var color: String {
        switch self {
        case .none: return "secondary"
        case .low: return "blue"
        case .medium: return "orange"
        case .high: return "red"
        }
    }
}
```

**Step 2: Build to verify**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ListWithMe/Models/ListModels.swift
git commit -m "feat: add Priority enum for item priority levels"
```

---

## Task 3: Update ListItem Model with New Properties

**Files:**
- Modify: `ListWithMe/Models/ListModels.swift`

**Step 1: Add new properties to ListItem**

```swift
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
    var quantity: Int          // NEW
    var note: String?          // NEW
    var dueDate: Date?         // NEW
    var priority: Priority     // NEW

    init(
        id: UUID = UUID(),
        text: String = "",
        isComplete: Bool = false,
        createdBy: String = "",
        category: String? = nil,
        quantity: Int = 1,         // NEW
        note: String? = nil,       // NEW
        dueDate: Date? = nil,      // NEW
        priority: Priority = .none // NEW
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
        self.quantity = quantity       // NEW
        self.note = note               // NEW
        self.dueDate = dueDate         // NEW
        self.priority = priority       // NEW
    }
    // ... existing methods unchanged
}
```

**Step 2: Build to verify**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ListWithMe/Models/ListModels.swift
git commit -m "feat: add quantity, note, dueDate, priority to ListItem"
```

---

## Task 4: Update CDListItem Extensions

**Files:**
- Modify: `ListWithMe/Persistence/CDListItem+Extensions.swift`

**Step 1: Update toListItem() method**

```swift
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
```

**Step 2: Update update(from:) method**

```swift
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
```

**Step 3: Update create(from:list:context:) method**

```swift
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
```

**Step 4: Build to verify**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add ListWithMe/Persistence/CDListItem+Extensions.swift
git commit -m "feat: update CDListItem extensions for new item properties"
```

---

## Task 5: Add Priority and DueDate Sorting Options

**Files:**
- Modify: `ListWithMe/Models/ListModels.swift`
- Modify: `ListWithMe/Services/ListService.swift`

**Step 1: Add new sort options to SortOption enum**

```swift
enum SortOption: String, CaseIterable, Identifiable {
    case manual = "Manual"
    case alphabetical = "A-Z"
    case alphabeticalReversed = "Z-A"
    case newestFirst = "Newest First"
    case oldestFirst = "Oldest First"
    case incompleteFirst = "Incomplete First"
    case completeFirst = "Complete First"
    case byCategory = "By Category"
    case byPriority = "By Priority"      // NEW
    case byDueDate = "By Due Date"       // NEW

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
        case .byPriority: return "exclamationmark.triangle"  // NEW
        case .byDueDate: return "calendar"                    // NEW
        }
    }
}
```

**Step 2: Update sortedItems method in ListService**

Add cases for new sort options:

```swift
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
```

**Step 3: Build to verify**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add ListWithMe/Models/ListModels.swift ListWithMe/Services/ListService.swift
git commit -m "feat: add priority and due date sorting options"
```

---

## Task 6: Create ItemDetailView

**Files:**
- Create: `ListWithMe/Views/ItemDetailView.swift`

**Step 1: Create the item detail editing view**

```swift
import SwiftUI

struct ItemDetailView: View {
    @Binding var item: ListItem
    let existingCategories: [String]
    let onSave: (ListItem) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var text: String
    @State private var quantity: Int
    @State private var note: String
    @State private var category: String?
    @State private var dueDate: Date?
    @State private var hasDueDate: Bool
    @State private var priority: Priority

    init(item: Binding<ListItem>, existingCategories: [String], onSave: @escaping (ListItem) -> Void) {
        self._item = item
        self.existingCategories = existingCategories
        self.onSave = onSave
        self._text = State(initialValue: item.wrappedValue.text)
        self._quantity = State(initialValue: item.wrappedValue.quantity)
        self._note = State(initialValue: item.wrappedValue.note ?? "")
        self._category = State(initialValue: item.wrappedValue.category)
        self._dueDate = State(initialValue: item.wrappedValue.dueDate ?? Date())
        self._hasDueDate = State(initialValue: item.wrappedValue.dueDate != nil)
        self._priority = State(initialValue: item.wrappedValue.priority)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name", text: $text)

                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
                }

                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(Priority.allCases) { p in
                            Label(p.label, systemImage: p.icon)
                                .tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Due Date") {
                    Toggle("Set Due Date", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker(
                            "Due",
                            selection: $dueDate,
                            displayedComponents: [.date]
                        )
                    }
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        Text("None").tag(nil as String?)
                        ForEach(existingCategories, id: \.self) { cat in
                            Text(cat).tag(cat as String?)
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $note)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Item Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveItem() }
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveItem() {
        var updated = item
        updated.text = text
        updated.quantity = quantity
        updated.note = note.isEmpty ? nil : note
        updated.category = category
        updated.dueDate = hasDueDate ? dueDate : nil
        updated.priority = priority
        updated.modifiedAt = Date()
        onSave(updated)
        dismiss()
    }
}

#Preview {
    @Previewable @State var item = ListItem(text: "Milk", createdBy: "user1")
    ItemDetailView(
        item: $item,
        existingCategories: ["Dairy", "Produce"],
        onSave: { _ in }
    )
}
```

**Step 2: Add to Xcode project**

Add PBXFileReference, PBXBuildFile, add to Views group, add to Sources build phase.

**Step 3: Build to verify**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add ListWithMe/Views/ItemDetailView.swift ListWithMe.xcodeproj/project.pbxproj
git commit -m "feat: add ItemDetailView for editing item details"
```

---

## Task 7: Update ListItemRow with Indicators

**Files:**
- Modify: `ListWithMe/Views/ListItemRow.swift`

**Step 1: Add quantity badge and priority indicator**

Update the HStack in ListItemRow to show:
- Quantity badge (if > 1)
- Priority indicator (colored exclamation marks)
- Due date indicator (if set, show calendar icon with date or "overdue" styling)

Add before the category badge:

```swift
// Quantity badge
if item.quantity > 1 {
    Text("×\(item.quantity)")
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.blue.opacity(0.2))
        .clipShape(Capsule())
}

// Priority indicator
if item.priority != .none {
    Image(systemName: item.priority.icon)
        .font(.caption)
        .foregroundStyle(priorityColor)
}

// Due date indicator
if let dueDate = item.dueDate {
    HStack(spacing: 2) {
        Image(systemName: "calendar")
        Text(dueDate, style: .date)
    }
    .font(.caption2)
    .foregroundStyle(dueDate < Date() ? .red : .secondary)
}
```

Add computed property for priority color:

```swift
private var priorityColor: Color {
    switch item.priority {
    case .none: return .secondary
    case .low: return .blue
    case .medium: return .orange
    case .high: return .red
    }
}
```

**Step 2: Build to verify**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ListWithMe/Views/ListItemRow.swift
git commit -m "feat: add quantity, priority, and due date indicators to ListItemRow"
```

---

## Task 8: Add Item Detail Editing to ListDetailView

**Files:**
- Modify: `ListWithMe/Views/ListDetailView.swift`

**Step 1: Add state for editing item details**

```swift
@State private var editingItemDetails: ListItem? = nil
```

**Step 2: Add "Edit Details" to context menu**

```swift
.contextMenu {
    Button {
        editingItemCategory = item
    } label: {
        Label("Set Category", systemImage: "folder")
    }

    Button {
        editingItemDetails = item  // NEW
    } label: {
        Label("Edit Details", systemImage: "pencil.circle")
    }
}
```

**Step 3: Add sheet for ItemDetailView**

```swift
.sheet(item: $editingItemDetails) { item in
    ItemDetailView(
        item: Binding(
            get: { item },
            set: { _ in }
        ),
        existingCategories: Array(Set(list?.items.compactMap { $0.category } ?? []).sorted()),
        onSave: { updated in
            var item = updated
            item.modifiedBy = userId
            listService.updateItem(item, in: listId)
            editingItemDetails = nil
        }
    )
}
```

**Step 4: Build to verify**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add ListWithMe/Views/ListDetailView.swift
git commit -m "feat: add item detail editing via context menu"
```

---

## Task 9: Update Preview Data

**Files:**
- Modify: `ListWithMe/Views/ListItemRow.swift`

**Step 1: Update preview to show items with new properties**

```swift
#Preview {
    List {
        ListItemRow(
            item: ListItem(text: "Milk", createdBy: "user1", category: "Dairy", quantity: 2, priority: .high),
            onToggleComplete: {},
            onTextChange: { _ in },
            onDelete: {}
        )
        ListItemRow(
            item: {
                var item = ListItem(text: "Eggs", createdBy: "user1", quantity: 12, dueDate: Date().addingTimeInterval(86400))
                item.markComplete(by: "user2")
                return item
            }(),
            onToggleComplete: {},
            onTextChange: { _ in },
            onDelete: {}
        )
        ListItemRow(
            item: ListItem(text: "Bread", createdBy: "user1", note: "Whole wheat", priority: .medium),
            onToggleComplete: {},
            onTextChange: { _ in },
            onDelete: {}
        )
    }
}
```

**Step 2: Build to verify**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ListWithMe/Views/ListItemRow.swift
git commit -m "feat: update ListItemRow preview with new item properties"
```

---

## Task 10: Final Build and Integration Test

**Step 1: Clean build**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' clean build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 2: Verify all Phase 4 features**

Check that:
- Core Data model has quantity, note, dueDate, priority attributes
- ListItem has all new properties with defaults
- Priority enum exists with all cases
- CDListItem extensions handle all new properties
- SortOption has byPriority and byDueDate options
- ItemDetailView allows editing all properties
- ListItemRow shows quantity badge, priority indicator, due date
- Context menu has "Edit Details" option

**Step 3: Final commit if needed**

```bash
git add -A
git commit -m "feat: complete Phase 4 item details features"
```

---

## Summary

Phase 4 adds:
1. **Quantities** - Items can have quantity > 1, displayed as "×N" badge
2. **Notes** - Free-text notes per item, edited in detail view
3. **Due Dates** - Optional due date with calendar picker, overdue styling
4. **Priority Levels** - None/Low/Medium/High with colored indicators
5. **ItemDetailView** - Full editing form for all item properties
6. **New Sort Options** - Sort by priority (high first) or due date (soonest first)
