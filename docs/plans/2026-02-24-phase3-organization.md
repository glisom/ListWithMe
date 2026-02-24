# Phase 3: Organization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add categories/sections, sorting options, and persistent drag-to-reorder to help users organize their shopping lists.

**Architecture:** Add category attribute to Core Data model and Swift models, create SortOption enum and sorting logic in ListService, implement drag-to-reorder with onMove modifier and sortOrder persistence.

**Tech Stack:** SwiftUI (List, ForEach with onMove), Core Data

---

## Task 1: Add Category to Core Data Model

**Files:**
- Modify: `ListWithMe/ListWithMe.xcdatamodeld/ListWithMe.xcdatamodel/contents`

**Step 1: Add category attribute to CDListItem**

Open the Core Data model in Xcode and add a new attribute to CDListItem:
- Name: `category`
- Type: `String`
- Optional: `YES`

The XML should include:
```xml
<attribute name="category" optional="YES" attributeType="String"/>
```

**Step 2: Build to verify**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ListWithMe/ListWithMe.xcdatamodeld
git commit -m "feat: add category attribute to CDListItem Core Data model"
```

---

## Task 2: Update ListItem Model with Category

**Files:**
- Modify: `ListWithMe/Models/ListModels.swift`

**Step 1: Add category property to ListItem**

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
    var category: String?  // NEW

    init(
        id: UUID = UUID(),
        text: String = "",
        isComplete: Bool = false,
        createdBy: String = "",
        category: String? = nil  // NEW
    ) {
        self.id = id
        self.text = text
        self.isComplete = isComplete
        self.createdBy = createdBy
        self.createdAt = Date()
        self.modifiedBy = createdBy
        self.modifiedAt = Date()
        self.sortOrder = 0
        self.category = category  // NEW
    }
    // ... existing methods
}
```

**Step 2: Build to verify**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ListWithMe/Models/ListModels.swift
git commit -m "feat: add category property to ListItem model"
```

---

## Task 3: Update CDListItem Extensions for Category

**Files:**
- Modify: `ListWithMe/Persistence/CDListItem+Extensions.swift`

**Step 1: Read current file and update toListItem and create methods**

Update `toListItem()` to include category:
```swift
func toListItem() -> ListItem {
    var item = ListItem(
        id: id ?? UUID(),
        text: text ?? "",
        isComplete: isComplete,
        createdBy: createdBy ?? "",
        category: category  // NEW
    )
    // ... existing property assignments
    return item
}
```

Update `create(from:list:context:)` to set category:
```swift
static func create(from item: ListItem, list: CDList, context: NSManagedObjectContext) -> CDListItem {
    let cdItem = CDListItem(context: context)
    // ... existing assignments
    cdItem.category = item.category  // NEW
    return cdItem
}
```

Update `update(from:)` to include category:
```swift
func update(from item: ListItem) {
    // ... existing assignments
    category = item.category  // NEW
}
```

**Step 2: Build to verify**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ListWithMe/Persistence/CDListItem+Extensions.swift
git commit -m "feat: update CDListItem extensions for category support"
```

---

## Task 4: Create SortOption Enum and Add to ListModels

**Files:**
- Modify: `ListWithMe/Models/ListModels.swift`

**Step 1: Add SortOption enum**

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
git commit -m "feat: add SortOption enum for list sorting"
```

---

## Task 5: Add Sorting Methods to ListService

**Files:**
- Modify: `ListWithMe/Services/ListService.swift`

**Step 1: Add sorting method**

```swift
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
    }
}
```

**Step 2: Build to verify**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ListWithMe/Services/ListService.swift
git commit -m "feat: add sorting methods to ListService"
```

---

## Task 6: Add Reorder Method to ListService

**Files:**
- Modify: `ListWithMe/Services/ListService.swift`

**Step 1: Add reorder method**

```swift
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
```

**Step 2: Build to verify**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ListWithMe/Services/ListService.swift
git commit -m "feat: add reorderItems method for drag-to-reorder"
```

---

## Task 7: Create SortMenuView Component

**Files:**
- Create: `ListWithMe/Views/SortMenuView.swift`

**Step 1: Create sort menu view**

```swift
import SwiftUI

struct SortMenuView: View {
    @Binding var selectedOption: SortOption

    var body: some View {
        Menu {
            ForEach(SortOption.allCases) { option in
                Button {
                    selectedOption = option
                } label: {
                    Label(option.rawValue, systemImage: option.icon)
                    if option == selectedOption {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
                .labelStyle(.iconOnly)
        }
    }
}

#Preview {
    @Previewable @State var option: SortOption = .manual
    SortMenuView(selectedOption: $option)
}
```

**Step 2: Add to Xcode project**

Add PBXFileReference, PBXBuildFile, add to Views group, add to Sources build phase.

**Step 3: Build to verify**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add ListWithMe/Views/SortMenuView.swift ListWithMe.xcodeproj/project.pbxproj
git commit -m "feat: add SortMenuView component for sorting options"
```

---

## Task 8: Create CategoryPickerView Component

**Files:**
- Create: `ListWithMe/Views/CategoryPickerView.swift`

**Step 1: Create category picker**

```swift
import SwiftUI

struct CategoryPickerView: View {
    @Binding var selectedCategory: String?
    let existingCategories: [String]
    @State private var newCategory = ""
    @State private var isAddingNew = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectedCategory = nil
                        dismiss()
                    } label: {
                        HStack {
                            Text("No Category")
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedCategory == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }

                if !existingCategories.isEmpty {
                    Section("Existing Categories") {
                        ForEach(existingCategories, id: \.self) { category in
                            Button {
                                selectedCategory = category
                                dismiss()
                            } label: {
                                HStack {
                                    Text(category)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedCategory == category {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }

                Section {
                    if isAddingNew {
                        HStack {
                            TextField("New category", text: $newCategory)
                            Button("Add") {
                                if !newCategory.isEmpty {
                                    selectedCategory = newCategory
                                    dismiss()
                                }
                            }
                            .disabled(newCategory.isEmpty)
                        }
                    } else {
                        Button {
                            isAddingNew = true
                        } label: {
                            Label("Add New Category", systemImage: "plus.circle")
                        }
                    }
                }
            }
            .navigationTitle("Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var category: String? = "Dairy"
    CategoryPickerView(
        selectedCategory: $category,
        existingCategories: ["Dairy", "Produce", "Meat", "Bakery"]
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
git add ListWithMe/Views/CategoryPickerView.swift ListWithMe.xcodeproj/project.pbxproj
git commit -m "feat: add CategoryPickerView for item categorization"
```

---

## Task 9: Update ListItemRow with Category Display

**Files:**
- Modify: `ListWithMe/Views/ListItemRow.swift`

**Step 1: Read current file and add category badge**

Add a category badge to display when item has a category:

```swift
// Add after the item text in the row
if let category = item.category, !category.isEmpty {
    Text(category)
        .font(.caption2)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.2))
        .clipShape(Capsule())
}
```

**Step 2: Build to verify**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ListWithMe/Views/ListItemRow.swift
git commit -m "feat: display category badge in ListItemRow"
```

---

## Task 10: Update ListDetailView with Sorting and Reorder

**Files:**
- Modify: `ListWithMe/Views/ListDetailView.swift`

**Step 1: Add sort option state**

```swift
@State private var sortOption: SortOption = .manual
```

**Step 2: Add sort menu to header**

Add SortMenuView next to the activity button in headerView:

```swift
SortMenuView(selectedOption: $sortOption)
```

**Step 3: Update items display with sorting**

Replace:
```swift
ForEach(list.items) { item in
```

With:
```swift
ForEach(listService.sortedItems(list.items, by: sortOption)) { item in
```

**Step 4: Add onMove for drag-to-reorder (only when sortOption is .manual)**

```swift
.onMove { source, destination in
    if sortOption == .manual {
        listService.reorderItems(in: listId, from: source, to: destination)
    }
}
```

**Step 5: Build to verify**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add ListWithMe/Views/ListDetailView.swift
git commit -m "feat: add sorting and drag-to-reorder to ListDetailView"
```

---

## Task 11: Add Category Editing to Item Context Menu

**Files:**
- Modify: `ListWithMe/Views/ListDetailView.swift`

**Step 1: Add category sheet state**

```swift
@State private var editingItemCategory: ListItem? = nil
```

**Step 2: Add context menu to ListItemRow**

Wrap ListItemRow with contextMenu for category editing:

```swift
ListItemRow(...)
    .contextMenu {
        Button {
            editingItemCategory = item
        } label: {
            Label("Set Category", systemImage: "folder")
        }
    }
```

**Step 3: Add category picker sheet**

```swift
.sheet(item: $editingItemCategory) { item in
    CategoryPickerView(
        selectedCategory: Binding(
            get: { item.category },
            set: { newCategory in
                var updated = item
                updated.category = newCategory
                updated.modifiedBy = userId
                updated.modifiedAt = Date()
                listService.updateItem(updated, in: listId)
            }
        ),
        existingCategories: Array(Set(list?.items.compactMap { $0.category } ?? []))
    )
    .presentationDetents([.medium])
}
```

**Step 4: Build to verify**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add ListWithMe/Views/ListDetailView.swift
git commit -m "feat: add category editing via context menu"
```

---

## Task 12: Add Section Headers for Category Grouping

**Files:**
- Modify: `ListWithMe/Views/ListDetailView.swift`

**Step 1: Create grouped items computed property**

```swift
private var groupedItems: [(String?, [ListItem])] {
    guard let list = list else { return [] }
    let items = listService.sortedItems(list.items, by: sortOption)

    if sortOption == .byCategory {
        let grouped = Dictionary(grouping: items) { $0.category }
        return grouped.sorted { ($0.key ?? "") < ($1.key ?? "") }
    } else {
        return [(nil, items)]
    }
}
```

**Step 2: Update List to use sections when sorting by category**

Replace the simple ForEach with sectioned content:

```swift
List {
    ForEach(groupedItems, id: \.0) { category, items in
        Section(header: category.map { Text($0) }) {
            ForEach(items) { item in
                // existing ListItemRow code
            }
            .onMove { source, destination in
                if sortOption == .manual {
                    listService.reorderItems(in: listId, from: source, to: destination)
                }
            }
        }
    }

    // Add item row
    addItemRow
}
```

**Step 3: Build to verify**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add ListWithMe/Views/ListDetailView.swift
git commit -m "feat: add section headers for category grouping"
```

---

## Task 13: Final Build and Integration Test

**Step 1: Clean build**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme "ListWithMe MessagesExtension" -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' clean build 2>&1 | grep -E "(error:|warning:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 2: Verify all Phase 3 features**

Check that:
- Category attribute is in Core Data model
- ListItem has category property
- SortOption enum exists with all options
- ListService has sortedItems and reorderItems methods
- SortMenuView and CategoryPickerView components work
- ListDetailView has sorting dropdown and drag-to-reorder
- Category badges display on items
- Context menu allows setting categories
- Section headers appear when sorting by category

**Step 3: Final commit if needed**

```bash
git add -A
git commit -m "feat: complete Phase 3 organization features"
```

---

## Summary

Phase 3 adds:
1. **Categories** - Items can be assigned to categories, displayed as badges
2. **Sorting Options** - 8 sort modes including manual, alphabetical, by date, by status, by category
3. **Drag-to-Reorder** - Manual reordering with persistent sortOrder
4. **Category Grouping** - Section headers when sorting by category
5. **Category Picker** - Easy UI to assign/create categories via context menu
