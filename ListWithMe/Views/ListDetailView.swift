import SwiftUI

struct ListDetailView: View {
    let listId: UUID
    let userId: String
    let onSendList: (ShoppingList) -> Void

    @State private var listService: ListService
    @State private var collaborationService: CollaborationService
    @State private var newItemText = ""
    @State private var showActivitySheet = false
    @State private var sortOption: SortOption = .manual
    @State private var editingItemCategory: ListItem? = nil
    @State private var editingItemDetails: ListItem? = nil
    @State private var suggestionService = SuggestionService()
    @State private var searchText = ""
    @FocusState private var isAddingItem: Bool

    init(
        listId: UUID,
        userId: String,
        listService: ListService = ListService(),
        collaborationService: CollaborationService = CollaborationService(),
        onSendList: @escaping (ShoppingList) -> Void
    ) {
        self.listId = listId
        self.userId = userId
        self._listService = State(initialValue: listService)
        self._collaborationService = State(initialValue: collaborationService)
        self.onSendList = onSendList
    }

    private var list: ShoppingList? {
        listService.lists.first { $0.id == listId }
    }

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

    private var currentSuggestions: [String] {
        suggestionService.suggestions(for: newItemText)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let list = list {
                // Header
                headerView(for: list)

                // Items List
                List {
                    ForEach(filteredGroupedItems, id: \.0) { category, items in
                        Section {
                            ForEach(items) { item in
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
                                            listService.deleteItem(item, from: listId)
                                        }
                                    }
                                )
                                .contextMenu {
                                    Button {
                                        editingItemDetails = item
                                    } label: {
                                        Label("Edit Details", systemImage: "pencil.and.list.clipboard")
                                    }
                                    Button {
                                        editingItemCategory = item
                                    } label: {
                                        Label("Set Category", systemImage: "folder")
                                    }
                                }
                            }
                            .onMove { source, destination in
                                if sortOption == .manual {
                                    listService.reorderItems(in: listId, from: source, to: destination)
                                }
                            }
                        } header: {
                            if sortOption == .byCategory {
                                Text(category ?? "Uncategorized")
                                    .font(.headline)
                            }
                        }
                    }

                    if !newItemText.isEmpty && !currentSuggestions.isEmpty {
                        SuggestionsView(suggestions: currentSuggestions) { selected in
                            newItemText = selected
                            addItem()
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                    }

                    // Add item row
                    addItemRow
                }
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: "Search items")
                .environment(\.editMode, sortOption == .manual ? .constant(.active) : .constant(.inactive))

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
        .sheet(isPresented: $showActivitySheet) {
            ActivityFeedView(activities: listService.getActivities(for: listId))
        }
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
                        editingItemCategory = nil
                    }
                ),
                existingCategories: Array(Set(list?.items.compactMap { $0.category } ?? []).sorted())
            )
            .presentationDetents([.medium])
        }
        .sheet(item: $editingItemDetails) { item in
            ItemDetailView(
                item: item,
                existingCategories: Array(Set(list?.items.compactMap { $0.category } ?? []).sorted()),
                onSave: { updatedItem in
                    var finalItem = updatedItem
                    finalItem.modifiedBy = userId
                    finalItem.modifiedAt = Date()
                    listService.updateItem(finalItem, in: listId)
                    editingItemDetails = nil
                }
            )
            .presentationDetents([.large])
        }
        .onAppear {
            collaborationService.startPresenceUpdates(for: listId)
        }
        .onDisappear {
            collaborationService.stopPresenceUpdates(for: listId)
        }
    }

    private func headerView(for list: ShoppingList) -> some View {
        HStack {
            Text(list.name)
                .font(.headline)

            Spacer()

            ParticipantsView(participants: collaborationService.getParticipants(for: listId))

            Text("\(list.items.filter { $0.isComplete }.count)/\(list.items.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            SortMenuView(selectedOption: $sortOption)

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

            Button {
                showActivitySheet = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title3)
            }
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
        suggestionService.loadRecentItems()
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
