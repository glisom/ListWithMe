# Phase 5: Convenience Features Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add convenience features that make daily shopping list management faster and more efficient.

**Architecture:** Add suggestion service for autocomplete, batch selection mode for bulk operations, smart input parsing for quantity detection, and utility actions for common tasks.

**Tech Stack:** SwiftUI, Core Data, @Observable pattern

---

## Task 1: Create SuggestionService for Item Autocomplete

**Files:**
- Create: `ListWithMe/Services/SuggestionService.swift`

**Step 1: Create SuggestionService**

```swift
import Foundation
import CoreData
import Observation

@Observable
final class SuggestionService {
    private let persistence: PersistenceController
    private(set) var recentItems: [String] = []

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
        loadRecentItems()
    }

    func loadRecentItems() {
        let request: NSFetchRequest<CDListItem> = CDListItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDListItem.createdAt, ascending: false)]
        request.fetchLimit = 100

        do {
            let items = try persistence.viewContext.fetch(request)
            let texts = items.compactMap { $0.text?.trimmingCharacters(in: .whitespaces) }
            // Unique items preserving order
            var seen = Set<String>()
            recentItems = texts.filter { item in
                let lowercased = item.lowercased()
                if seen.contains(lowercased) { return false }
                seen.insert(lowercased)
                return true
            }
        } catch {
            print("Failed to load recent items: \(error)")
        }
    }

    func suggestions(for query: String) -> [String] {
        guard !query.isEmpty else { return [] }
        let lowercasedQuery = query.lowercased()
        return recentItems
            .filter { $0.lowercased().contains(lowercasedQuery) }
            .prefix(5)
            .map { $0 }
    }
}
```

**Step 2: Build to verify**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme ListWithMe -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 3: Add file to Xcode project if needed**

Check project.pbxproj and add file reference if not auto-detected.

**Step 4: Commit**

```bash
git add -A && git commit -m "feat: add SuggestionService for item autocomplete"
```

---

## Task 2: Create SuggestionsView Component

**Files:**
- Create: `ListWithMe/Views/SuggestionsView.swift`

**Step 1: Create SuggestionsView**

```swift
import SwiftUI

struct SuggestionsView: View {
    let suggestions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        if !suggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            onSelect(suggestion)
                        } label: {
                            Text(suggestion)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 44)
        }
    }
}

#Preview {
    SuggestionsView(
        suggestions: ["Milk", "Bread", "Eggs", "Butter", "Cheese"],
        onSelect: { print($0) }
    )
}
```

**Step 2: Build to verify**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme ListWithMe -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add -A && git commit -m "feat: add SuggestionsView component"
```

---

## Task 3: Integrate Suggestions into ListDetailView

**Files:**
- Modify: `ListWithMe/Views/ListDetailView.swift`

**Step 1: Add SuggestionService state**

Add after other @State properties:
```swift
@State private var suggestionService = SuggestionService()
```

**Step 2: Add computed property for filtered suggestions**

```swift
private var currentSuggestions: [String] {
    suggestionService.suggestions(for: newItemText)
}
```

**Step 3: Add SuggestionsView above addItemRow**

In the List, before `addItemRow`, add:
```swift
if !newItemText.isEmpty && !currentSuggestions.isEmpty {
    SuggestionsView(suggestions: currentSuggestions) { selected in
        newItemText = selected
        addItem()
    }
    .listRowInsets(EdgeInsets())
    .listRowSeparator(.hidden)
}
```

**Step 4: Refresh suggestions when item added**

In `addItem()` function, after adding item:
```swift
suggestionService.loadRecentItems()
```

**Step 5: Build and test**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme ListWithMe -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add -A && git commit -m "feat: integrate autocomplete suggestions in list view"
```

---

## Task 4: Add Smart Input Parsing for Quantities

**Files:**
- Modify: `ListWithMe/Services/ListService.swift`

**Step 1: Add parseItemInput helper**

Add this method to ListService:
```swift
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
                    return ParsedItem(text: String(trimmed[textRange]), quantity: qty)
                }
            } else {
                // Second pattern: quantity last
                if let textRange = Range(match.range(at: 1), in: trimmed),
                   let qtyRange = Range(match.range(at: 2), in: trimmed),
                   let qty = Int(trimmed[qtyRange]) {
                    return ParsedItem(text: String(trimmed[textRange]), quantity: qty)
                }
            }
        }
    }

    return ParsedItem(text: trimmed, quantity: 1)
}
```

**Step 2: Update addItem method signature**

Change the `addItem` method to use parsing:
```swift
func addItem(to listId: UUID, text: String, createdBy: String) {
    guard let cdList = CDList.fetch(id: listId, context: context) else { return }

    let parsed = parseItemInput(text)
    var item = ListItem(text: parsed.text, createdBy: createdBy, quantity: parsed.quantity)
    _ = CDListItem.create(from: item, list: cdList, context: context)
    saveContext()
    fetchLists()
    recordActivity(for: listId, action: .added, itemText: parsed.text)
}
```

**Step 3: Build and test**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme ListWithMe -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add -A && git commit -m "feat: add smart input parsing for quantities"
```

---

## Task 5: Add Clear Completed Action

**Files:**
- Modify: `ListWithMe/Services/ListService.swift`
- Modify: `ListWithMe/Views/ListDetailView.swift`

**Step 1: Add clearCompleted method to ListService**

```swift
func clearCompleted(from listId: UUID) {
    guard let cdList = CDList.fetch(id: listId, context: context) else { return }

    let completedItems = (cdList.items as? Set<CDListItem> ?? [])
        .filter { $0.isComplete }

    for item in completedItems {
        context.delete(item)
    }

    saveContext()
    fetchLists()
    recordActivity(for: listId, action: .deleted, itemText: "\(completedItems.count) completed items")
}
```

**Step 2: Add Clear Completed button to header in ListDetailView**

In `headerView`, add a menu button before the activity button:
```swift
Menu {
    Button(role: .destructive) {
        withAnimation {
            listService.clearCompleted(from: listId)
        }
    } label: {
        Label("Clear Completed", systemImage: "checkmark.circle.badge.xmark")
    }
    .disabled(list.items.filter { $0.isComplete }.isEmpty)
} label: {
    Image(systemName: "ellipsis.circle")
        .font(.title3)
}
```

**Step 3: Build and test**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme ListWithMe -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add -A && git commit -m "feat: add clear completed items action"
```

---

## Task 6: Add Duplicate List Feature

**Files:**
- Modify: `ListWithMe/Services/ListService.swift`
- Modify: `ListWithMe/Views/ListsView.swift`

**Step 1: Add duplicateList method to ListService**

```swift
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
```

**Step 2: Add duplicate action to ListsView context menu**

Find the existing context menu in ListsView and add:
```swift
Button {
    _ = listService.duplicateList(list, createdBy: userId)
} label: {
    Label("Duplicate", systemImage: "doc.on.doc")
}
```

**Step 3: Build and test**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme ListWithMe -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add -A && git commit -m "feat: add duplicate list feature"
```

---

## Task 7: Add Search/Filter for Items

**Files:**
- Modify: `ListWithMe/Views/ListDetailView.swift`

**Step 1: Add search state**

Add to ListDetailView state properties:
```swift
@State private var searchText = ""
```

**Step 2: Add filtered items computed property**

```swift
private var filteredGroupedItems: [(String?, [ListItem])] {
    if searchText.isEmpty {
        return groupedItems
    }
    let lowercasedSearch = searchText.lowercased()
    return groupedItems.compactMap { category, items in
        let filtered = items.filter { $0.text.lowercased().contains(lowercasedSearch) }
        return filtered.isEmpty ? nil : (category, filtered)
    }
}
```

**Step 3: Add searchable modifier**

Add `.searchable(text: $searchText, prompt: "Search items")` to the List.

**Step 4: Update ForEach to use filteredGroupedItems**

Change `ForEach(groupedItems, ...)` to `ForEach(filteredGroupedItems, ...)`

**Step 5: Build and test**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme ListWithMe -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add -A && git commit -m "feat: add search/filter for list items"
```

---

## Task 8: Add Batch Selection Mode

**Files:**
- Modify: `ListWithMe/Views/ListDetailView.swift`
- Modify: `ListWithMe/Services/ListService.swift`

**Step 1: Add selection state to ListDetailView**

```swift
@State private var isSelectionMode = false
@State private var selectedItems: Set<UUID> = []
```

**Step 2: Add batch delete method to ListService**

```swift
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
```

**Step 3: Add Select mode toggle to header menu**

In the Menu in headerView:
```swift
Button {
    isSelectionMode.toggle()
    if !isSelectionMode { selectedItems.removeAll() }
} label: {
    Label(isSelectionMode ? "Done Selecting" : "Select Items", systemImage: "checkmark.circle")
}
```

**Step 4: Add selection UI to ListItemRow area**

Wrap ListItemRow in HStack when in selection mode:
```swift
HStack {
    if isSelectionMode {
        Image(systemName: selectedItems.contains(item.id) ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(selectedItems.contains(item.id) ? .blue : .secondary)
            .onTapGesture {
                if selectedItems.contains(item.id) {
                    selectedItems.remove(item.id)
                } else {
                    selectedItems.insert(item.id)
                }
            }
    }
    ListItemRow(...)
}
```

**Step 5: Add batch action toolbar**

Add toolbar when items selected:
```swift
.toolbar {
    if isSelectionMode && !selectedItems.isEmpty {
        ToolbarItemGroup(placement: .bottomBar) {
            Button {
                listService.completeItems(selectedItems, in: listId, by: userId)
                selectedItems.removeAll()
            } label: {
                Label("Complete", systemImage: "checkmark")
            }
            Spacer()
            Button(role: .destructive) {
                listService.deleteItems(selectedItems, from: listId)
                selectedItems.removeAll()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
```

**Step 6: Build and test**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme ListWithMe -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 7: Commit**

```bash
git add -A && git commit -m "feat: add batch selection mode for items"
```

---

## Task 9: Add Quick Add from Clipboard

**Files:**
- Modify: `ListWithMe/Views/ListDetailView.swift`

**Step 1: Add clipboard check function**

```swift
private var clipboardHasText: Bool {
    UIPasteboard.general.hasStrings
}

private func addFromClipboard() {
    guard let text = UIPasteboard.general.string else { return }
    let lines = text.components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }

    for line in lines {
        listService.addItem(to: listId, text: line, createdBy: userId)
    }
    suggestionService.loadRecentItems()
}
```

**Step 2: Add paste button to header menu**

```swift
if clipboardHasText {
    Button {
        addFromClipboard()
    } label: {
        Label("Paste Items", systemImage: "doc.on.clipboard")
    }
}
```

**Step 3: Build and test**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme ListWithMe -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add -A && git commit -m "feat: add paste items from clipboard"
```

---

## Task 10: Final Build and Integration Test

**Step 1: Clean build**

Run: `xcodebuild clean -project ListWithMe.xcodeproj -scheme ListWithMe`

**Step 2: Full build**

Run: `xcodebuild -project ListWithMe.xcodeproj -scheme ListWithMe -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -30`
Expected: BUILD SUCCEEDED

**Step 3: Verify all files added to project**

Check that all new files are in the Xcode project.

**Step 4: Final commit**

```bash
git add -A && git commit -m "feat: complete Phase 5 convenience features"
```

---

## Summary

Phase 5 adds these convenience features:

1. **Autocomplete Suggestions** - Shows recent items as you type
2. **Smart Input Parsing** - "3 apples" becomes quantity 3 + "apples"
3. **Clear Completed** - One-tap removal of checked items
4. **Duplicate List** - Copy a list as a template
5. **Search/Filter** - Find items in large lists
6. **Batch Selection** - Select multiple items for bulk actions
7. **Paste from Clipboard** - Add multiple items from copied text
